from __future__ import annotations

import math
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
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

ROOT_UNIVERSE = "__root__"


@dataclass
class SurfaceDef:
    id: str
    surface_type: str
    boundary: str
    coeffs: list[float]


@dataclass
class SourceRegionsDef:
    dims: list[int]
    lower_left: list[float]
    upper_right: list[float]


@dataclass
class CellDef:
    id: str
    universe: str
    zone: str
    material_id: str | None
    fill: str | None
    translation: tuple[float, float, float]
    source_regions: SourceRegionsDef | None


@dataclass
class PinDef:
    id: str
    materials: list[str]
    radii: list[float]
    axis: str


@dataclass
class LatticeDef:
    id: str
    lattice_type: str
    pitch: list[float]
    dims: list[int]
    lower_left: list[float]
    universes: list[str]


@dataclass
class FlatCellDef:
    id: str
    material_id: str
    zone: str
    source_regions: SourceRegionsDef | None


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


def parse_int(text: str, context: str) -> int:
    try:
        return int(text)
    except ValueError as exc:
        raise ValueError(f"{context} must be an integer, got '{text}'") from exc


def parse_float(text: str, context: str) -> float:
    try:
        return float(text)
    except ValueError as exc:
        raise ValueError(f"{context} must be a real number, got '{text}'") from exc


def parse_int_list(text: str, context: str) -> list[int]:
    if not text:
        return []
    return [parse_int(item, context) for item in text.replace(",", " ").split()]


def parse_float_list(text: str, context: str) -> list[float]:
    if not text:
        return []
    return [parse_float(item, context) for item in text.replace(",", " ").split()]


def normalize_surface_type(value: str) -> str:
    value = value.strip().lower()
    return ALIASES.get(value, value)


def normalize_boundary(value: str) -> str:
    value = (value or "transmission").strip().lower()
    return ALIASES.get(value, value)


def normalize_ray_launch_mode(value: str) -> str:
    mode = (value or "auto").strip().lower()
    aliases = {
        "auto": "auto",
        "volume": "volume",
        "internal": "volume",
        "body": "volume",
        "body-internal": "volume",
        "body_internal": "volume",
        "vacuum-surface": "vacuum-surface",
        "vacuum_surface": "vacuum-surface",
        "vacuumsurface": "vacuum-surface",
        "surface": "vacuum-surface",
        "vacuum-face": "vacuum-surface",
        "vacuum_face": "vacuum-surface",
    }
    if mode not in aliases:
        raise ValueError("option <ray_launch_mode> must be auto, volume, or vacuum-surface")
    return aliases[mode]


def require_attr(node: ET.Element, name: str, context: str) -> str:
    value = node.attrib.get(name)
    if value is None or not value.strip():
        raise ValueError(f"{context} is missing required attribute '{name}'")
    return value.strip()


def ensure_supported_boundary(boundary: str, context: str) -> str:
    if boundary not in {"reflect", "vacuum", "transmission"}:
        raise ValueError(f"{context} uses unsupported boundary '{boundary}'")
    return boundary


def echo_error(message: str, echo_out: Path | None) -> None:
    print(message, file=sys.stderr)
    if echo_out is not None:
        echo_out.parent.mkdir(parents=True, exist_ok=True)
        with echo_out.open("a", encoding="utf-8") as handle:
            handle.write(message + "\n")


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


def lex_zone(expr: str) -> list[str]:
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
    return tokens


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
    groups = parse_int(root.attrib["groups"], "mgxs attribute 'groups'")
    materials: dict[str, dict[str, list[float]]] = {}
    for material in root.findall("material"):
        mid = material.attrib["id"].strip()
        total = floats_from_text(text_of(material.find("total")))
        nu_sigma_f = floats_from_text(text_of(material.find("nu_sigma_f")))
        chi = floats_from_text(text_of(material.find("chi")))
        scatter_rows = [floats_from_text(text_of(row)) for row in material.findall("scatter/row")]
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


def parse_source_regions(cell: ET.Element) -> SourceRegionsDef | None:
    source_regions = cell.find("source_regions")
    if source_regions is None:
        return None
    dims = parse_int_list(
        source_regions.attrib.get("dimension", source_regions.attrib.get("dimensions", "")),
        f"cell '{cell.attrib['id']}' source_regions dimension",
    )
    if len(dims) == 2:
        dims = [dims[0], dims[1], 1]
    if len(dims) != 3:
        raise ValueError(f"cell '{cell.attrib['id']}' subdivision must define 3 dimensions")
    lower_left = parse_float_list(attr_or_text(source_regions, "lower_left"), f"cell '{cell.attrib['id']}' source_regions lower_left")
    upper_right = parse_float_list(attr_or_text(source_regions, "upper_right"), f"cell '{cell.attrib['id']}' source_regions upper_right")
    if len(lower_left) != 3 or len(upper_right) != 3:
        raise ValueError(f"cell '{cell.attrib['id']}' subdivision must define lower_left and upper_right")
    return SourceRegionsDef(dims=dims, lower_left=lower_left, upper_right=upper_right)


def parse_translation(cell: ET.Element) -> tuple[float, float, float]:
    values = parse_float_list(cell.attrib.get("translation", ""), f"cell '{cell.attrib['id']}' translation")
    if not values:
        return (0.0, 0.0, 0.0)
    if len(values) != 3:
        raise ValueError(f"cell '{cell.attrib['id']}' translation must have 3 values")
    return (values[0], values[1], values[2])


def parse_geometry_defs(geometry: ET.Element) -> tuple[
    dict[str, SurfaceDef],
    dict[str, list[CellDef]],
    dict[str, PinDef],
    dict[str, LatticeDef],
]:
    surfaces: dict[str, SurfaceDef] = {}
    for node in geometry.findall("surface"):
        sid = require_attr(node, "id", "<surface>")
        boundary = ensure_supported_boundary(normalize_boundary(node.attrib.get("boundary", "transmission")), f"surface '{sid}'")
        surfaces[sid] = SurfaceDef(
            id=sid,
            surface_type=normalize_surface_type(require_attr(node, "type", f"surface '{sid}'")),
            boundary=boundary,
            coeffs=floats_from_text(node.attrib.get("coeffs", "")),
        )

    pins: dict[str, PinDef] = {}
    for node in geometry.findall("pin"):
        pid = require_attr(node, "id", "<pin>")
        materials = text_of(node.find("materials")).split()
        radii = parse_float_list(text_of(node.find("radii")), f"pin '{pid}' radii")
        axis = normalize_surface_type(node.attrib.get("axis", "z-cylinder"))
        if axis not in {"x-cylinder", "y-cylinder", "z-cylinder"}:
            raise ValueError(f"pin '{pid}' only supports x/y/z-cylinder axis definitions")
        if len(materials) != len(radii) + 1:
            raise ValueError(f"pin '{pid}' must have len(materials) = len(radii) + 1")
        pins[pid] = PinDef(id=pid, materials=materials, radii=radii, axis=axis)

    lattices: dict[str, LatticeDef] = {}
    for node in geometry.findall("lattice"):
        lid = require_attr(node, "id", "<lattice>")
        lattice_type = node.attrib.get("type", "").strip().lower()
        pitch = parse_float_list(text_of(node.find("pitch")), f"lattice '{lid}' pitch")
        dims = parse_int_list(text_of(node.find("dimensions")), f"lattice '{lid}' dimensions")
        lower_left = parse_float_list(text_of(node.find("lower_left")), f"lattice '{lid}' lower_left")
        universes = text_of(node.find("universes")).split()
        if lattice_type != "rectangular":
            raise ValueError(f"lattice '{lid}' currently only supports rectangular type")
        if len(dims) not in {2, 3}:
            raise ValueError(f"lattice '{lid}' dimensions must have length 2 or 3")
        if len(pitch) != len(dims):
            raise ValueError(f"lattice '{lid}' pitch length must match dimensions length")
        if len(lower_left) != len(dims):
            raise ValueError(f"lattice '{lid}' lower_left length must match dimensions length")
        if len(universes) != math.prod(dims):
            raise ValueError(f"lattice '{lid}' universes count does not match dimensions")
        lattices[lid] = LatticeDef(
            id=lid,
            lattice_type=lattice_type,
            pitch=pitch,
            dims=dims,
            lower_left=lower_left,
            universes=universes,
        )

    cells_by_universe: dict[str, list[CellDef]] = {}
    for node in geometry.findall("cell"):
        cid = require_attr(node, "id", "<cell>")
        universe = node.attrib.get("universe", ROOT_UNIVERSE).strip() or ROOT_UNIVERSE
        material_id = node.attrib.get("material")
        if material_id is not None:
            material_id = material_id.strip()
        fill = node.attrib.get("fill")
        if fill is not None:
            fill = fill.strip()
        if fill and material_id and material_id.lower() != "void":
            raise ValueError(f"cell '{cid}' should not define both material and fill in this version")
        zone = require_attr(node, "zone", f"cell '{cid}'")
        cell = CellDef(
            id=cid,
            universe=universe,
            zone=zone,
            material_id=material_id,
            fill=fill,
            translation=parse_translation(node),
            source_regions=parse_source_regions(node),
        )
        cells_by_universe.setdefault(universe, []).append(cell)

    return surfaces, cells_by_universe, pins, lattices


def sanitize_hint(text: str) -> str:
    clean = re.sub(r"[^A-Za-z0-9_]+", "_", text).strip("_")
    return clean or "item"


def intersect_expr(*parts: str) -> str:
    clean = [part.strip() for part in parts if part and part.strip()]
    if not clean:
        return ""
    if len(clean) == 1:
        return clean[0]
    return " ".join(f"({part})" for part in clean)


class GeometryExpander:
    def __init__(
        self,
        surfaces: dict[str, SurfaceDef],
        cells_by_universe: dict[str, list[CellDef]],
        pins: dict[str, PinDef],
        lattices: dict[str, LatticeDef],
    ) -> None:
        self.original_surfaces = surfaces
        self.cells_by_universe = cells_by_universe
        self.pins = pins
        self.lattices = lattices
        self.flat_cells: list[FlatCellDef] = []
        self.generated_surfaces: dict[str, SurfaceDef] = dict(surfaces)
        self.surface_signature_to_id: dict[tuple[object, ...], str] = {}
        for surface in surfaces.values():
            self.surface_signature_to_id[self.surface_signature(surface.surface_type, surface.boundary, surface.coeffs)] = surface.id
        self.surface_counter = 0
        self.cell_counter = 0

    def surface_signature(self, surface_type: str, boundary: str, coeffs: list[float]) -> tuple[object, ...]:
        rounded = tuple(round(value, 12) for value in coeffs)
        return (surface_type, boundary, rounded)

    def make_surface_id(self) -> str:
        self.surface_counter += 1
        return f"g{self.surface_counter:06d}"

    def make_cell_id(self, hint: str) -> str:
        self.cell_counter += 1
        base = sanitize_hint(hint)[:48]
        return f"{base}_{self.cell_counter:04d}"

    def get_or_create_surface(self, surface_type: str, boundary: str, coeffs: list[float]) -> str:
        signature = self.surface_signature(surface_type, boundary, coeffs)
        existing = self.surface_signature_to_id.get(signature)
        if existing is not None:
            return existing
        sid = self.make_surface_id()
        self.generated_surfaces[sid] = SurfaceDef(id=sid, surface_type=surface_type, boundary=boundary, coeffs=list(coeffs))
        self.surface_signature_to_id[signature] = sid
        return sid

    def translate_surface(self, surface: SurfaceDef, shift: tuple[float, float, float]) -> list[float]:
        coeffs = list(surface.coeffs)
        if surface.surface_type == "x-plane":
            coeffs[0] += shift[0]
        elif surface.surface_type == "y-plane":
            coeffs[0] += shift[1]
        elif surface.surface_type == "z-plane":
            coeffs[0] += shift[2]
        elif surface.surface_type == "x-cylinder":
            coeffs[0] += shift[1]
            coeffs[1] += shift[2]
        elif surface.surface_type == "y-cylinder":
            coeffs[0] += shift[0]
            coeffs[1] += shift[2]
        elif surface.surface_type == "z-cylinder":
            coeffs[0] += shift[0]
            coeffs[1] += shift[1]
        elif surface.surface_type == "sphere":
            coeffs[0] += shift[0]
            coeffs[1] += shift[1]
            coeffs[2] += shift[2]
        else:
            raise ValueError(f"unsupported surface type '{surface.surface_type}' for translation")
        return coeffs

    def instantiate_surface(self, local_surface_id: str, shift: tuple[float, float, float]) -> str:
        surface = self.original_surfaces[local_surface_id]
        if shift == (0.0, 0.0, 0.0):
            return surface.id
        coeffs = self.translate_surface(surface, shift)
        return self.get_or_create_surface(surface.surface_type, surface.boundary, coeffs)

    def translate_zone_expr(self, expr: str, shift: tuple[float, float, float]) -> str:
        translated: list[str] = []
        for token in lex_zone(expr):
            if token in {"(", ")", "|", "~"}:
                translated.append(token)
                continue
            signed = token if token[0] in "+-" else f"+{token}"
            sign = signed[0]
            local_name = signed[1:]
            if local_name not in self.original_surfaces:
                raise KeyError(f"unknown surface '{local_name}' in zone '{expr}'")
            global_name = self.instantiate_surface(local_name, shift)
            translated.append(f"{sign}{global_name}" if sign == "-" else global_name)
        return " ".join(translated)

    def shift_source_regions(self, source_regions: SourceRegionsDef | None, shift: tuple[float, float, float]) -> SourceRegionsDef | None:
        if source_regions is None:
            return None
        return SourceRegionsDef(
            dims=list(source_regions.dims),
            lower_left=[source_regions.lower_left[i] + shift[i] for i in range(3)],
            upper_right=[source_regions.upper_right[i] + shift[i] for i in range(3)],
        )

    def emit_leaf(self, material_id: str, zone: str, source_regions: SourceRegionsDef | None, hint: str) -> None:
        self.flat_cells.append(
            FlatCellDef(
                id=self.make_cell_id(hint),
                material_id=material_id,
                zone=zone,
                source_regions=source_regions,
            )
        )

    def dispatch_fill(self, fill_id: str, host_expr: str, shift: tuple[float, float, float], hint: str) -> None:
        if fill_id in self.pins:
            self.expand_pin(fill_id, host_expr, shift, hint)
        elif fill_id in self.lattices:
            self.expand_lattice(fill_id, host_expr, shift, hint)
        elif fill_id in self.cells_by_universe:
            self.expand_universe(fill_id, host_expr, shift, hint)
        else:
            raise KeyError(f"fill '{fill_id}' is not a known pin, lattice, or universe")

    def expand_universe(self, universe_id: str, host_expr: str, shift: tuple[float, float, float], hint: str) -> None:
        if universe_id not in self.cells_by_universe:
            raise KeyError(f"unknown universe '{universe_id}'")
        for cell in self.cells_by_universe[universe_id]:
            local_zone = self.translate_zone_expr(cell.zone, shift)
            combined_zone = intersect_expr(host_expr, local_zone)
            child_shift = (
                shift[0] + cell.translation[0],
                shift[1] + cell.translation[1],
                shift[2] + cell.translation[2],
            )
            child_hint = f"{hint}_{cell.id}"
            if cell.fill is not None:
                if cell.source_regions is not None:
                    raise ValueError(f"cell '{cell.id}' uses source_regions together with fill, which is not supported yet")
                self.dispatch_fill(cell.fill, combined_zone, child_shift, child_hint)
            else:
                if cell.material_id is None:
                    raise ValueError(f"cell '{cell.id}' must define either material or fill")
                self.emit_leaf(cell.material_id, combined_zone, self.shift_source_regions(cell.source_regions, shift), child_hint)

    def expand_pin(self, pin_id: str, host_expr: str, shift: tuple[float, float, float], hint: str) -> None:
        pin = self.pins[pin_id]
        surface_ids: list[str] = []
        for radius in pin.radii:
            coeffs = [0.0, 0.0, radius]
            surface_type = pin.axis
            if pin.axis == "x-cylinder":
                coeffs = [0.0, 0.0, radius]
                coeffs[0] += shift[1]
                coeffs[1] += shift[2]
            elif pin.axis == "y-cylinder":
                coeffs = [0.0, 0.0, radius]
                coeffs[0] += shift[0]
                coeffs[1] += shift[2]
            else:
                coeffs = [shift[0], shift[1], radius]
            if pin.axis == "x-cylinder":
                sid = self.get_or_create_surface(surface_type, "transmission", coeffs)
            elif pin.axis == "y-cylinder":
                sid = self.get_or_create_surface(surface_type, "transmission", coeffs)
            else:
                sid = self.get_or_create_surface(surface_type, "transmission", coeffs)
            surface_ids.append(sid)

        for index, material_id in enumerate(pin.materials):
            if index == 0:
                local_expr = f"-{surface_ids[0]}"
            elif index < len(surface_ids):
                local_expr = f"{surface_ids[index - 1]} -{surface_ids[index]}"
            else:
                local_expr = surface_ids[-1]
            self.emit_leaf(material_id, intersect_expr(host_expr, local_expr), None, f"{hint}_{pin_id}_{index + 1}")

    def tile_box_expr(self, lower: list[float], upper: list[float]) -> str:
        sxmin = self.get_or_create_surface("x-plane", "transmission", [lower[0]])
        sxmax = self.get_or_create_surface("x-plane", "transmission", [upper[0]])
        symin = self.get_or_create_surface("y-plane", "transmission", [lower[1]])
        symax = self.get_or_create_surface("y-plane", "transmission", [upper[1]])
        pieces = [sxmin, f"-{sxmax}", symin, f"-{symax}"]
        if lower[2] < upper[2] - 1.0e-12:
            szmin = self.get_or_create_surface("z-plane", "transmission", [lower[2]])
            szmax = self.get_or_create_surface("z-plane", "transmission", [upper[2]])
            pieces.extend([szmin, f"-{szmax}"])
        return " ".join(pieces)

    def lattice_entries(self, lattice: LatticeDef) -> list[tuple[list[float], list[float], list[float], str]]:
        entries: list[tuple[list[float], list[float], list[float], str]] = []
        if len(lattice.dims) == 2:
            nx, ny = lattice.dims
            px, py = lattice.pitch
            llx, lly = lattice.lower_left
            for row in range(ny):
                iy = ny - 1 - row
                for ix in range(nx):
                    fill_id = lattice.universes[row * nx + ix]
                    lower = [llx + ix * px, lly + iy * py, 0.0]
                    upper = [lower[0] + px, lower[1] + py, 0.0]
                    center = [0.5 * (lower[0] + upper[0]), 0.5 * (lower[1] + upper[1]), 0.0]
                    entries.append((lower, upper, center, fill_id))
        else:
            nx, ny, nz = lattice.dims
            px, py, pz = lattice.pitch
            llx, lly, llz = lattice.lower_left
            layer_size = nx * ny
            for iz in range(nz):
                for row in range(ny):
                    iy = ny - 1 - row
                    for ix in range(nx):
                        index = iz * layer_size + row * nx + ix
                        fill_id = lattice.universes[index]
                        lower = [llx + ix * px, lly + iy * py, llz + iz * pz]
                        upper = [lower[0] + px, lower[1] + py, lower[2] + pz]
                        center = [
                            0.5 * (lower[0] + upper[0]),
                            0.5 * (lower[1] + upper[1]),
                            0.5 * (lower[2] + upper[2]),
                        ]
                        entries.append((lower, upper, center, fill_id))
        return entries

    def expand_lattice(self, lattice_id: str, host_expr: str, shift: tuple[float, float, float], hint: str) -> None:
        lattice = self.lattices[lattice_id]
        for idx, (lower_local, upper_local, center_local, fill_id) in enumerate(self.lattice_entries(lattice), start=1):
            lower = [lower_local[i] + shift[i] for i in range(3)]
            upper = [upper_local[i] + shift[i] for i in range(3)]
            center = [center_local[i] + shift[i] for i in range(3)]
            tile_expr = self.tile_box_expr(lower, upper)
            child_host_expr = intersect_expr(host_expr, tile_expr)
            child_shift = (center[0], center[1], center[2])
            self.dispatch_fill(fill_id, child_host_expr, child_shift, f"{hint}_{lattice_id}_{idx}")

    def expand_root(self) -> tuple[list[SurfaceDef], list[FlatCellDef]]:
        self.expand_universe(ROOT_UNIVERSE, "", (0.0, 0.0, 0.0), "root")
        return list(self.generated_surfaces.values()), self.flat_cells


def pack(input_xml: Path, output_path: Path) -> None:
    tree = ET.parse(input_xml)
    root = tree.getroot()
    geometry = root.find("geometry")
    materials_node = root.find("materials")
    options = root.find("options")
    sources_node = root.find("sources")
    if geometry is None or materials_node is None or options is None:
        raise ValueError("input XML must contain geometry, materials, and options")

    surfaces, cells_by_universe, pins, lattices = parse_geometry_defs(geometry)
    expander = GeometryExpander(surfaces, cells_by_universe, pins, lattices)
    flat_surfaces, flat_cells = expander.expand_root()

    library_node = materials_node.find("library")
    if library_node is None:
        raise ValueError("materials block must define a <library>")
    library_type = library_node.attrib.get("type", "").strip().lower()
    if library_type not in {"strack-mg", "strack-mgxs"}:
        raise ValueError("only strack-mg libraries are supported in the current version")
    library_path = (input_xml.parent / require_attr(library_node, "path", "<library>")).resolve()
    ngroups, library = read_library(library_path)

    run_mode = text_of(options.find("run_mode"), "criticality").lower()
    geometry_search = text_of(options.find("geometry_search"), "global").lower()
    ray_launch_mode = normalize_ray_launch_mode(text_of(options.find("ray_launch_mode"), "auto"))
    spatial_dimension = parse_int(text_of(options.find("spatial_dimension"), "3"), "option <spatial_dimension>")
    cycle = parse_int(text_of(options.find("cycle"), "50"), "option <cycle>")
    inactive = parse_int(text_of(options.find("inactive"), "10"), "option <inactive>")
    particles = parse_int(text_of(options.find("particles"), "1000"), "option <particles>")
    distance_inactive = parse_float(text_of(options.find("distance_inactive"), "10.0"), "option <distance_inactive>")
    distance_active = parse_float(text_of(options.find("distance_active"), "80.0"), "option <distance_active>")
    boundary_epsilon_shift = parse_float(
        text_of(options.find("boundary_epsilon_shift"), "1.0e-8"),
        "option <boundary_epsilon_shift>",
    )
    seed = parse_int(text_of(options.find("seed"), "13579"), "option <seed>")
    if seed % 2 == 0:
        seed += 1
    if spatial_dimension not in {2, 3}:
        raise ValueError("spatial_dimension must be 2 or 3")
    if cycle <= 0:
        raise ValueError("cycle must be positive")
    if inactive < 0 or inactive >= cycle:
        raise ValueError("inactive must satisfy 0 <= inactive < cycle")
    if particles <= 0:
        raise ValueError("particles must be positive")
    if distance_inactive < 0.0 or distance_active < 0.0:
        raise ValueError("distance_inactive and distance_active must be non-negative")
    if boundary_epsilon_shift < 0.0:
        raise ValueError("boundary_epsilon_shift must be non-negative")

    ray_source = options.find("ray_source")
    if ray_source is None:
        raise ValueError("options must define a <ray_source> block")
    lower_left = parse_float_list(attr_or_text(ray_source, "lower_left"), "ray_source lower_left")
    upper_right = parse_float_list(attr_or_text(ray_source, "upper_right"), "ray_source upper_right")
    if len(lower_left) != 3 or len(upper_right) != 3:
        raise ValueError("ray_source lower_left and upper_right must each have 3 values")
    if any(upper_right[i] <= lower_left[i] for i in range(3)):
        raise ValueError("ray_source upper_right must be greater than lower_left in every coordinate")

    material_map: list[tuple[str, str]] = []
    for material in materials_node.findall("material"):
        mid = require_attr(material, "id", "<material>")
        xs_id = material.attrib.get("xs", mid).strip()
        if mid.lower() != "void":
            if xs_id not in library:
                raise KeyError(f"material '{mid}' maps to unknown library xs '{xs_id}'")
            material_map.append((mid, xs_id))

    surfaces_out = [
        (surface.id, surface.surface_type, surface.boundary, surface.coeffs)
        for surface in flat_surfaces
    ]

    surfaces_by_name = {sid: idx + 1 for idx, (sid, _, _, _) in enumerate(surfaces_out)}
    cells_out = []
    cell_lookup: dict[str, int] = {}
    for idx, cell in enumerate(flat_cells, start=1):
        tokens = zone_to_rpn(cell.zone, surfaces_by_name)
        subdivision = None
        if cell.source_regions is not None:
            subdivision = (cell.source_regions.dims, cell.source_regions.lower_left, cell.source_regions.upper_right)
        cell_lookup[cell.id] = idx
        cells_out.append((cell.id, cell.material_id, tokens, subdivision))

    fixed_sources = []
    if sources_node is not None:
        for source in sources_node.findall("source"):
            cell_id = require_attr(source, "cell", "<source>")
            if cell_id not in cell_lookup:
                raise KeyError(
                    f"fixed source references cell '{cell_id}', but only leaf material cells are currently supported"
                )
            spectrum = parse_float_list(source.attrib.get("spectrum", ""), f"fixed source '{cell_id}' spectrum")
            strength = parse_float(source.attrib.get("strength", "1.0"), f"fixed source '{cell_id}' strength")
            if len(spectrum) != ngroups:
                raise ValueError(f"fixed source on cell '{cell_id}' needs {ngroups} spectrum values")
            fixed_sources.append((cell_lookup[cell_id], strength, spectrum))

    with output_path.open("w", encoding="utf-8") as handle:
        handle.write("STRACK_INPUT_V1\n")
        handle.write(f"CASE {input_xml.stem}\n")
        handle.write(f"RUN_MODE {run_mode}\n")
        handle.write(f"GEOMETRY_SEARCH {geometry_search}\n")
        handle.write(f"RAY_LAUNCH_MODE {ray_launch_mode}\n")
        handle.write(f"SPATIAL_DIMENSION {spatial_dimension}\n")
        handle.write(f"ENERGY_GROUPS {ngroups}\n")
        handle.write(f"CYCLE {cycle}\n")
        handle.write(f"INACTIVE {inactive}\n")
        handle.write(f"PARTICLES {particles}\n")
        handle.write(f"DISTANCE_INACTIVE {distance_inactive:.16e}\n")
        handle.write(f"DISTANCE_ACTIVE {distance_active:.16e}\n")
        handle.write(f"BOUNDARY_EPSILON_SHIFT {boundary_epsilon_shift:.16e}\n")
        handle.write(f"SEED {seed}\n")
        handle.write("RAY_BOX " + " ".join(f"{value:.16e}" for value in (*lower_left, *upper_right)) + "\n")
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
                handle.write(f"SCATTER_ROW {row_index} " + " ".join(f"{value:.16e}" for value in row) + "\n")
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
    if len(argv) not in {3, 4}:
        print("usage: py tools/pack_input.py <input.xml> <output.stracki> [echo.out]", file=sys.stderr)
        return 1
    input_xml = Path(argv[1]).resolve()
    output_path = Path(argv[2]).resolve()
    echo_out = Path(argv[3]).resolve() if len(argv) == 4 else None
    try:
        pack(input_xml, output_path)
        return 0
    except ET.ParseError as exc:
        line, column = exc.position
        echo_error(f"XML parse error in '{input_xml}': line {line}, column {column}: {exc}", echo_out)
        return 2
    except Exception as exc:
        echo_error(f"Input error in '{input_xml}': {exc}", echo_out)
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
