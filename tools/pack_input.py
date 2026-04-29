from __future__ import annotations

import math
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


ALIASES = {
    "plane-x": "x-plane",
    "plane-y": "y-plane",
    "plane-z": "z-plane",
    "cylinder-x": "x-cylinder",
    "cylinder-y": "y-cylinder",
    "cylinder-z": "z-cylinder",
    "reflective": "reflect",
    "out": "vacuum",
    "cross": "transmission",
}


def text_of(node: ET.Element | None, default: str = "") -> str:
    if node is None or node.text is None:
        return default
    return " ".join(node.text.split())


def attr_or_text(node: ET.Element, name: str, default: str = "") -> str:
    if name in node.attrib:
      return " ".join(node.attrib[name].split())
    child = node.find(name)
    return text_of(child, default)


def floats_from_text(text: str) -> list[float]:
    if not text:
        return []
    return [float(item) for item in text.replace(",", " ").split()]


def ints_from_text(text: str) -> list[int]:
    if not text:
        return []
    return [int(item) for item in text.replace(",", " ").split()]


def normalize_surface_type(value: str) -> str:
    value = value.strip().lower()
    return ALIASES.get(value, value)


def normalize_boundary(value: str) -> str:
    value = (value or "transmission").strip().lower()
    return ALIASES.get(value, value)


def tokenize_zone(expr: str) -> list[str]:
    tokens: list[str] = []
    current = []
    special = {"(", ")", "|", "~"}
    for char in expr:
        if char in special:
            if current:
                tokens.append("".join(current))
                current = []
            tokens.append(char)
        elif char.isspace():
            if current:
                tokens.append("".join(current))
                current = []
        else:
            current.append(char)
    if current:
        tokens.append("".join(current))

    expanded: list[str] = []
    prev: str | None = None
    for token in tokens:
        if prev is not None:
            left_is_value = prev not in {"|", "(", "~"}
            right_is_value = token not in {"|", ")"} and token != "~"
            left_can_close = prev == ")" or left_is_value
            right_can_open = token == "(" or token == "~" or right_is_value
            if left_can_close and right_can_open:
                expanded.append("AND")
        if token == "|":
            expanded.append("OR")
        elif token == "~":
            expanded.append("NOT")
        else:
            expanded.append(token)
        prev = token
    return expanded


def zone_to_rpn(expr: str, surfaces: dict[str, int]) -> list[str]:
    precedence = {"NOT": 3, "AND": 2, "OR": 1}
    output: list[str] = []
    stack: list[str] = []
    for token in tokenize_zone(expr):
        if token == "(":
            stack.append(token)
        elif token == ")":
            while stack and stack[-1] != "(":
                output.append(stack.pop())
            if not stack:
                raise ValueError(f"unbalanced zone expression: {expr}")
            stack.pop()
        elif token in precedence:
            while stack and stack[-1] in precedence and precedence[stack[-1]] >= precedence[token]:
                output.append(stack.pop())
            stack.append(token)
        else:
            signed = token if token[0] in "+-" else f"+{token}"
            name = signed[1:]
            if name not in surfaces:
                raise KeyError(f"unknown surface '{name}' in zone '{expr}'")
            output.append(signed)
    while stack:
        top = stack.pop()
        if top == "(":
            raise ValueError(f"unbalanced zone expression: {expr}")
        output.append(top)
    return output


def read_library(library_path: Path) -> tuple[int, dict[str, dict[str, list[float]]]]:
    tree = ET.parse(library_path)
    root = tree.getroot()
    if root.tag.lower() != "mgxs":
        raise ValueError("MGXS library root must be <mgxs>")
    groups = int(root.attrib["groups"])
    materials: dict[str, dict[str, list[float]]] = {}
    for material in root.findall("material"):
        mid = material.attrib["id"].strip()
        total = floats_from_text(text_of(material.find("total")))
        nu_sigma_f = floats_from_text(text_of(material.find("nu_sigma_f")))
        chi = floats_from_text(text_of(material.find("chi")))
        scatter_rows = []
        for row in material.findall("scatter/row"):
            scatter_rows.append(floats_from_text(text_of(row)))
        if len(total) != groups or len(nu_sigma_f) != groups or len(chi) != groups:
            raise ValueError(f"MGXS vector size mismatch for material {mid}")
        if len(scatter_rows) != groups or any(len(row) != groups for row in scatter_rows):
            raise ValueError(f"MGXS scatter size mismatch for material {mid}")
        materials[mid] = {
            "total": total,
            "nu_sigma_f": nu_sigma_f,
            "chi": chi,
            "scatter": scatter_rows,
        }
    return groups, materials


def pack(input_xml: Path, output_path: Path) -> None:
    tree = ET.parse(input_xml)
    root = tree.getroot()
    geometry = root.find("geometry")
    materials_node = root.find("materials")
    options = root.find("options")
    sources_node = root.find("sources")
    if geometry is None or materials_node is None or options is None:
        raise ValueError("input XML must contain geometry, materials, and options")

    surface_nodes = geometry.findall("surface")
    surfaces_by_name = {node.attrib["id"].strip(): idx + 1 for idx, node in enumerate(surface_nodes)}

    library_node = materials_node.find("library")
    if library_node is None:
        raise ValueError("materials block must define a <library>")
    library_type = library_node.attrib.get("type", "").strip().lower()
    if library_type not in {"strack-mg", "strack-mgxs"}:
        raise ValueError("only strack-mg libraries are supported in the first milestone")
    library_path = (input_xml.parent / library_node.attrib["path"]).resolve()
    ngroups, library = read_library(library_path)

    run_mode = text_of(options.find("run_mode"), "criticality").lower()
    cycle = int(text_of(options.find("cycle"), "50"))
    inactive = int(text_of(options.find("inactive"), "10"))
    particles = int(text_of(options.find("particles"), "1000"))
    distance_inactive = float(text_of(options.find("distance_inactive"), "10.0"))
    distance_active = float(text_of(options.find("distance_active"), "80.0"))
    seed = int(text_of(options.find("seed"), "13579"))
    if seed % 2 == 0:
        seed += 1

    ray_source = options.find("ray_source")
    if ray_source is None:
        raise ValueError("options must define a <ray_source> block")
    lower_left = floats_from_text(attr_or_text(ray_source, "lower_left"))
    upper_right = floats_from_text(attr_or_text(ray_source, "upper_right"))
    if len(lower_left) != 3 or len(upper_right) != 3:
        raise ValueError("ray_source lower_left and upper_right must each have 3 values")

    material_map: list[tuple[str, str]] = []
    for material in materials_node.findall("material"):
        mid = material.attrib["id"].strip()
        xs_id = material.attrib.get("xs", mid).strip()
        if mid.lower() != "void":
            if xs_id not in library:
                raise KeyError(f"material '{mid}' maps to unknown library xs '{xs_id}'")
            material_map.append((mid, xs_id))

    surfaces_out = []
    for node in surface_nodes:
        coeffs = floats_from_text(node.attrib.get("coeffs", ""))
        surfaces_out.append(
            (
                node.attrib["id"].strip(),
                normalize_surface_type(node.attrib["type"]),
                normalize_boundary(node.attrib.get("boundary", "transmission")),
                coeffs,
            )
        )

    cells_out = []
    cell_lookup: dict[str, int] = {}
    for idx, cell in enumerate(geometry.findall("cell"), start=1):
        cid = cell.attrib["id"].strip()
        material_id = cell.attrib.get("material", "void").strip()
        zone_expr = cell.attrib["zone"].strip()
        tokens = zone_to_rpn(zone_expr, surfaces_by_name)
        source_regions = cell.find("source_regions")
        if source_regions is not None:
            dims = ints_from_text(
                source_regions.attrib.get("dimension", source_regions.attrib.get("dimensions", ""))
            )
            if len(dims) == 2:
                dims = [dims[0], dims[1], 1]
            if len(dims) != 3:
                raise ValueError(f"cell '{cid}' subdivision must define 3 dimensions")
            ll = floats_from_text(attr_or_text(source_regions, "lower_left"))
            ur = floats_from_text(attr_or_text(source_regions, "upper_right"))
            if len(ll) != 3 or len(ur) != 3:
                raise ValueError(f"cell '{cid}' subdivision must define lower_left and upper_right")
            subdivision = (dims, ll, ur)
        else:
            subdivision = None
        cell_lookup[cid] = idx
        cells_out.append((cid, material_id, tokens, subdivision))

    fixed_sources = []
    if sources_node is not None:
        for source in sources_node.findall("source"):
            cell_id = source.attrib["cell"].strip()
            spectrum = floats_from_text(source.attrib.get("spectrum", ""))
            strength = float(source.attrib.get("strength", "1.0"))
            if len(spectrum) != ngroups:
                raise ValueError(f"fixed source on cell '{cell_id}' needs {ngroups} spectrum values")
            fixed_sources.append((cell_lookup[cell_id], strength, spectrum))

    with output_path.open("w", encoding="utf-8") as handle:
        handle.write("STRACK_INPUT_V1\n")
        handle.write(f"CASE {input_xml.stem}\n")
        handle.write(f"RUN_MODE {run_mode}\n")
        handle.write(f"ENERGY_GROUPS {ngroups}\n")
        handle.write(f"CYCLE {cycle}\n")
        handle.write(f"INACTIVE {inactive}\n")
        handle.write(f"PARTICLES {particles}\n")
        handle.write(f"DISTANCE_INACTIVE {distance_inactive:.16e}\n")
        handle.write(f"DISTANCE_ACTIVE {distance_active:.16e}\n")
        handle.write(f"SEED {seed}\n")
        handle.write(
            "RAY_BOX "
            + " ".join(f"{value:.16e}" for value in (*lower_left, *upper_right))
            + "\n"
        )
        handle.write(f"MATERIAL_COUNT {len(material_map)}\n")
        for mid, xs_id in material_map:
            handle.write(f"MATERIAL {mid} {xs_id}\n")
        handle.write(f"XS_COUNT {len(library)}\n")
        for xs_id, xs_data in library.items():
            handle.write(f"XS {xs_id}\n")
            handle.write("TOTAL " + " ".join(f"{value:.16e}" for value in xs_data["total"]) + "\n")
            handle.write("NU_SIGMA_F " + " ".join(f"{value:.16e}" for value in xs_data["nu_sigma_f"]) + "\n")
            handle.write("CHI " + " ".join(f"{value:.16e}" for value in xs_data["chi"]) + "\n")
            for row_index, row in enumerate(xs_data["scatter"], start=1):
                handle.write(
                    f"SCATTER_ROW {row_index} " + " ".join(f"{value:.16e}" for value in row) + "\n"
                )
            handle.write("END_XS\n")
        handle.write(f"SURFACE_COUNT {len(surfaces_out)}\n")
        for sid, stype, boundary, coeffs in surfaces_out:
            coeff_text = " ".join(f"{value:.16e}" for value in coeffs)
            handle.write(f"SURFACE {sid} {stype} {boundary} {len(coeffs)} {coeff_text}\n")
        handle.write(f"CELL_COUNT {len(cells_out)}\n")
        for cid, material_id, tokens, subdivision in cells_out:
            handle.write(f"CELL {cid} {material_id} {1 if subdivision else 0} {len(tokens)}\n")
            handle.write("TOKENS " + " ".join(tokens) + "\n")
            if subdivision:
                dims, ll, ur = subdivision
                handle.write(
                    "SUBDIVISION "
                    + " ".join(str(value) for value in dims)
                    + " "
                    + " ".join(f"{value:.16e}" for value in (*ll, *ur))
                    + "\n"
                )
            handle.write("END_CELL\n")
        handle.write(f"FIXED_SOURCE_COUNT {len(fixed_sources)}\n")
        for cell_index, strength, spectrum in fixed_sources:
            handle.write(
                f"FIXED_SOURCE {cell_index} {strength:.16e} "
                + " ".join(f"{value:.16e}" for value in spectrum)
                + "\n"
            )
        handle.write("END_INPUT\n")


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: py tools/pack_input.py <input.xml> <output.stracki>", file=sys.stderr)
        return 1
    input_xml = Path(argv[1]).resolve()
    output_path = Path(argv[2]).resolve()
    pack(input_xml, output_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
