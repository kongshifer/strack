from __future__ import annotations

from pathlib import Path


REPO = Path(__file__).resolve().parent.parent
CASES = REPO / "validation" / "cases"
MGXS = REPO / "validation" / "mgxs"

PITCH = 1.26
HALF_PITCH = 0.63
Z_HALF = 50.0
FUEL_R = 0.41
CLAD_R = 0.475
PATTERN = [
    ["u30", "u30", "u30", "u30", "u30", "u30", "u30"],
    ["u30", "u30", "u30", "u30", "u30", "u30", "u30"],
    ["u30", "u30", "u30", "u30", "u30", "u30", "u30"],
    ["u30", "u30", "u30", "u07", "u30", "u30", "u30"],
    ["u30", "u30", "u30", "u30", "u30", "u30", "u30"],
    ["u30", "u30", "u30", "u30", "u30", "u30", "u30"],
    ["u30", "u30", "u30", "u30", "u30", "u30", "u30"],
]

PIN_TYPES = {
    "u30": ("fuel30_pin", ["fuel30", "clad", "water"], [FUEL_R, CLAD_R]),
    "u07": ("fuel07_pin", ["fuel07", "clad", "water"], [FUEL_R, CLAD_R]),
}


def write_text(path: Path, text: str) -> None:
    path.write_text(text.strip() + "\n", encoding="utf-8")


def mgxs_xml() -> str:
    return """
<mgxs groups="1">
  <material id="fuel30">
    <total>0.78</total>
    <nu_sigma_f>0.22</nu_sigma_f>
    <chi>1.0</chi>
    <scatter>
      <row>0.58</row>
    </scatter>
  </material>
  <material id="fuel07">
    <total>0.78</total>
    <nu_sigma_f>0.18</nu_sigma_f>
    <chi>1.0</chi>
    <scatter>
      <row>0.58</row>
    </scatter>
  </material>
  <material id="clad">
    <total>0.55</total>
    <nu_sigma_f>0.0</nu_sigma_f>
    <chi>1.0</chi>
    <scatter>
      <row>0.50</row>
    </scatter>
  </material>
  <material id="water">
    <total>1.20</total>
    <nu_sigma_f>0.0</nu_sigma_f>
    <chi>1.0</chi>
    <scatter>
      <row>1.14</row>
    </scatter>
  </material>
</mgxs>
"""


def options_xml(cycle: int, particles: int, x_half: float, y_half: float) -> str:
    return f"""
  <options>
    <run_mode>criticality</run_mode>
    <cycle>{cycle}</cycle>
    <inactive>4</inactive>
    <particles>{particles}</particles>
    <distance_inactive>8.0</distance_inactive>
    <distance_active>80.0</distance_active>
    <seed>13579</seed>
    <ray_source>
      <lower_left>{-x_half:.8f} {-y_half:.8f} {-Z_HALF:.8f}</lower_left>
      <upper_right>{x_half:.8f} {y_half:.8f} {Z_HALF:.8f}</upper_right>
    </ray_source>
  </options>
"""


def materials_xml() -> str:
    return """
  <materials>
    <library type="strack-mg" path="../mgxs/jeff15_lwr_1g.xml" />
    <material id="fuel30" xs="fuel30" />
    <material id="fuel07" xs="fuel07" />
    <material id="clad" xs="clad" />
    <material id="water" xs="water" />
  </materials>
"""


def hierarchy_pincell_xml() -> str:
    return f"""
<input>
  <geometry>
    <surface id="xmin" type="x-plane" coeffs="{-HALF_PITCH}" boundary="reflect" />
    <surface id="xmax" type="x-plane" coeffs="{HALF_PITCH}" boundary="reflect" />
    <surface id="ymin" type="y-plane" coeffs="{-HALF_PITCH}" boundary="reflect" />
    <surface id="ymax" type="y-plane" coeffs="{HALF_PITCH}" boundary="reflect" />
    <surface id="zmin" type="z-plane" coeffs="{-Z_HALF}" boundary="reflect" />
    <surface id="zmax" type="z-plane" coeffs="{Z_HALF}" boundary="reflect" />
    <surface id="uxmin" type="x-plane" coeffs="{-HALF_PITCH}" />
    <surface id="uxmax" type="x-plane" coeffs="{HALF_PITCH}" />
    <surface id="uymin" type="y-plane" coeffs="{-HALF_PITCH}" />
    <surface id="uymax" type="y-plane" coeffs="{HALF_PITCH}" />
    <surface id="uzmin" type="z-plane" coeffs="{-Z_HALF}" />
    <surface id="uzmax" type="z-plane" coeffs="{Z_HALF}" />
    <pin id="fuel30_pin">
      <materials>fuel30 clad water</materials>
      <radii>{FUEL_R} {CLAD_R}</radii>
    </pin>
    <cell id="pincell_u" universe="pin_u" fill="fuel30_pin" zone="uxmin -uxmax uymin -uymax uzmin -uzmax" />
    <cell id="root" fill="pin_u" zone="xmin -xmax ymin -ymax zmin -zmax" />
    <cell id="outside" material="void" zone="-xmin|xmax|-ymin|ymax|-zmin|zmax" />
  </geometry>
{materials_xml()}
{options_xml(10, 80, HALF_PITCH, HALF_PITCH)}
</input>
"""


def explicit_pincell_xml() -> str:
    return f"""
<input>
  <geometry>
    <surface id="xmin" type="x-plane" coeffs="{-HALF_PITCH}" boundary="reflect" />
    <surface id="xmax" type="x-plane" coeffs="{HALF_PITCH}" boundary="reflect" />
    <surface id="ymin" type="y-plane" coeffs="{-HALF_PITCH}" boundary="reflect" />
    <surface id="ymax" type="y-plane" coeffs="{HALF_PITCH}" boundary="reflect" />
    <surface id="zmin" type="z-plane" coeffs="{-Z_HALF}" boundary="reflect" />
    <surface id="zmax" type="z-plane" coeffs="{Z_HALF}" boundary="reflect" />
    <surface id="rf" type="z-cylinder" coeffs="0.0 0.0 {FUEL_R}" />
    <surface id="rc" type="z-cylinder" coeffs="0.0 0.0 {CLAD_R}" />
    <cell id="fuel" material="fuel30" zone="xmin -xmax ymin -ymax zmin -zmax -rf" />
    <cell id="clad" material="clad" zone="xmin -xmax ymin -ymax zmin -zmax rf -rc" />
    <cell id="water" material="water" zone="xmin -xmax ymin -ymax zmin -zmax rc" />
    <cell id="outside" material="void" zone="-xmin|xmax|-ymin|ymax|-zmin|zmax" />
  </geometry>
{materials_xml()}
{options_xml(10, 80, HALF_PITCH, HALF_PITCH)}
</input>
"""


def hierarchy_lattice_xml() -> str:
    span = 3.5 * PITCH
    rows = ["        " + " ".join(row) for row in PATTERN]
    return f"""
<input>
  <geometry>
    <surface id="xmin" type="x-plane" coeffs="{-span}" boundary="reflect" />
    <surface id="xmax" type="x-plane" coeffs="{span}" boundary="reflect" />
    <surface id="ymin" type="y-plane" coeffs="{-span}" boundary="reflect" />
    <surface id="ymax" type="y-plane" coeffs="{span}" boundary="reflect" />
    <surface id="zmin" type="z-plane" coeffs="{-Z_HALF}" boundary="reflect" />
    <surface id="zmax" type="z-plane" coeffs="{Z_HALF}" boundary="reflect" />
    <surface id="uxmin" type="x-plane" coeffs="{-HALF_PITCH}" />
    <surface id="uxmax" type="x-plane" coeffs="{HALF_PITCH}" />
    <surface id="uymin" type="y-plane" coeffs="{-HALF_PITCH}" />
    <surface id="uymax" type="y-plane" coeffs="{HALF_PITCH}" />
    <surface id="uzmin" type="z-plane" coeffs="{-Z_HALF}" />
    <surface id="uzmax" type="z-plane" coeffs="{Z_HALF}" />
    <pin id="fuel30_pin">
      <materials>fuel30 clad water</materials>
      <radii>{FUEL_R} {CLAD_R}</radii>
    </pin>
    <pin id="fuel07_pin">
      <materials>fuel07 clad water</materials>
      <radii>{FUEL_R} {CLAD_R}</radii>
    </pin>
    <cell id="u30_cell" universe="u30" fill="fuel30_pin" zone="uxmin -uxmax uymin -uymax uzmin -uzmax" />
    <cell id="u07_cell" universe="u07" fill="fuel07_pin" zone="uxmin -uxmax uymin -uymax uzmin -uzmax" />
    <lattice id="lat7" type="rectangular">
      <pitch>{PITCH} {PITCH}</pitch>
      <dimensions>7 7</dimensions>
      <lower_left>{-span} {-span}</lower_left>
      <universes>
{chr(10).join(rows)}
      </universes>
    </lattice>
    <cell id="root" fill="lat7" zone="xmin -xmax ymin -ymax zmin -zmax" />
    <cell id="outside" material="void" zone="-xmin|xmax|-ymin|ymax|-zmin|zmax" />
  </geometry>
{materials_xml()}
{options_xml(8, 50, span, span)}
</input>
"""


def explicit_lattice_xml() -> str:
    span = 3.5 * PITCH
    x_values = [(-span + i * PITCH) for i in range(8)]
    y_values = [(-span + i * PITCH) for i in range(8)]

    surface_lines = []
    for i, value in enumerate(x_values):
        boundary = ' boundary="reflect"' if i in {0, 7} else ""
        surface_lines.append(f'    <surface id="x{i}" type="x-plane" coeffs="{value:.8f}"{boundary} />')
    for i, value in enumerate(y_values):
        boundary = ' boundary="reflect"' if i in {0, 7} else ""
        surface_lines.append(f'    <surface id="y{i}" type="y-plane" coeffs="{value:.8f}"{boundary} />')
    surface_lines.append(f'    <surface id="zmin" type="z-plane" coeffs="{-Z_HALF:.8f}" boundary="reflect" />')
    surface_lines.append(f'    <surface id="zmax" type="z-plane" coeffs="{Z_HALF:.8f}" boundary="reflect" />')

    cell_lines = []
    for row_index, row in enumerate(PATTERN):
        iy = 6 - row_index
        for ix, universe_id in enumerate(row):
            pin_name, materials, radii = PIN_TYPES[universe_id]
            center_x = -span + (ix + 0.5) * PITCH
            center_y = -span + (iy + 0.5) * PITCH
            s1 = f"r1_{ix}_{iy}"
            s2 = f"r2_{ix}_{iy}"
            surface_lines.append(f'    <surface id="{s1}" type="z-cylinder" coeffs="{center_x:.8f} {center_y:.8f} {radii[0]:.8f}" />')
            surface_lines.append(f'    <surface id="{s2}" type="z-cylinder" coeffs="{center_x:.8f} {center_y:.8f} {radii[1]:.8f}" />')
            host = f"x{ix} -x{ix + 1} y{iy} -y{iy + 1} zmin -zmax"
            cell_lines.append(f'    <cell id="c_{ix}_{iy}_1" material="{materials[0]}" zone="{host} -{s1}" />')
            cell_lines.append(f'    <cell id="c_{ix}_{iy}_2" material="{materials[1]}" zone="{host} {s1} -{s2}" />')
            cell_lines.append(f'    <cell id="c_{ix}_{iy}_3" material="{materials[2]}" zone="{host} {s2}" />')

    cell_lines.append('    <cell id="outside" material="void" zone="-x0|x7|-y0|y7|-zmin|zmax" />')
    return f"""
<input>
  <geometry>
{chr(10).join(surface_lines)}
{chr(10).join(cell_lines)}
  </geometry>
{materials_xml()}
{options_xml(8, 50, span, span)}
</input>
"""


def main() -> int:
    write_text(MGXS / "jeff15_lwr_1g.xml", mgxs_xml())
    write_text(CASES / "jeff15_pincell_explicit_1g.xml", explicit_pincell_xml())
    write_text(CASES / "jeff15_pincell_hierarchical_1g.xml", hierarchy_pincell_xml())
    write_text(CASES / "jeff15_7x7_explicit_1g.xml", explicit_lattice_xml())
    write_text(CASES / "jeff15_7x7_hierarchical_1g.xml", hierarchy_lattice_xml())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
