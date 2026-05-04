from __future__ import annotations

import argparse
import shlex
import subprocess
from pathlib import Path


def dominant_keff(groups: int, total: list[float], scatter: list[list[float]], nu_sigma_f: list[float], chi: list[float]) -> float:
    if groups == 1:
        return nu_sigma_f[0] / max(total[0] - scatter[0][0], 1.0e-12)
    if groups == 2:
        a11 = total[0] - scatter[0][0]
        a12 = -scatter[1][0]
        a21 = -scatter[0][1]
        a22 = total[1] - scatter[1][1]
        det = a11 * a22 - a12 * a21
        inv = [[a22 / det, -a12 / det], [-a21 / det, a11 / det]]
        f = [[chi[0] * nu_sigma_f[0], chi[0] * nu_sigma_f[1]], [chi[1] * nu_sigma_f[0], chi[1] * nu_sigma_f[1]]]
        m = [
            [inv[0][0] * f[0][0] + inv[0][1] * f[1][0], inv[0][0] * f[0][1] + inv[0][1] * f[1][1]],
            [inv[1][0] * f[0][0] + inv[1][1] * f[1][0], inv[1][0] * f[0][1] + inv[1][1] * f[1][1]],
        ]
        trace = m[0][0] + m[1][1]
        disc = max(trace * trace - 4.0 * (m[0][0] * m[1][1] - m[0][1] * m[1][0]), 0.0)
        return 0.5 * (trace + disc ** 0.5)
    raise ValueError("validation helper only supports 1 or 2 groups")


def parse_result(py_path: Path) -> dict[str, object]:
    namespace: dict[str, object] = {}
    exec(py_path.read_text(encoding="utf-8"), {}, namespace)
    return namespace


def run_case(exe: Path, case: Path, launcher: list[str]) -> dict[str, object]:
    command = [*launcher, str(exe), str(case)]
    subprocess.run(command, check=True, cwd=case.parent)
    return parse_result(case.with_name(case.stem + "_results.py"))


def case_input(repo: Path, name: str) -> Path:
    return repo / "validation" / name / f"{name}.xml"


def case_doc(name: str) -> str:
    return f"../{name}/{name}.md"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument(
        "--launcher",
        default="",
        help='Optional parallel launcher, for example --launcher "mpirun -np 4" or --launcher "srun -n 4"',
    )
    args = parser.parse_args()

    repo = Path(args.repo)
    launcher = shlex.split(args.launcher)
    cases = [
        {
            "name": "homogeneous_cube_1g",
            "input": case_input(repo, "homogeneous_cube_1g"),
            "doc": case_doc("homogeneous_cube_1g"),
            "description": "Fully reflective 3D homogeneous 1-group cube used to track the kinf limit.",
            "expected": 1.25,
            "tol": 8.0e-2,
        },
        {
            "name": "homogeneous_square_2g",
            "input": case_input(repo, "homogeneous_square_2g"),
            "doc": case_doc("homogeneous_square_2g"),
            "description": "Reflective 2D-equivalent 2-group homogeneous square for scattering/fission coupling.",
            "expected": dominant_keff(
                2,
                [0.22, 0.80],
                [[0.08, 0.09], [0.00, 0.50]],
                [0.14, 0.12],
                [1.0, 0.0],
            ),
            "tol": 1.0e-1,
        },
        {
            "name": "reflective_sphere_1g",
            "input": case_input(repo, "reflective_sphere_1g"),
            "doc": case_doc("reflective_sphere_1g"),
            "description": "Reflective 1-group sphere used to exercise curved-surface tracking.",
            "expected": 1.10,
            "tol": 1.0e-1,
        },
        {
            "name": "slab_1d_1g",
            "input": case_input(repo, "slab_1d_1g"),
            "doc": case_doc("slab_1d_1g"),
            "description": "Literature 1D vacuum slab benchmark represented through the code's multidimensional geometry path.",
            "expected": 0.95348,
            "tol": 1.0e-3,
        },
        {
            "name": "unstructured_circle_square_2g",
            "input": case_input(repo, "unstructured_circle_square_2g"),
            "doc": case_doc("unstructured_circle_square_2g"),
            "description": "Explicit 2D two-region circle-in-square benchmark used to track heterogeneous keff behavior.",
            "expected": 1.174655,
            "tol": 5.0e-3,
        },
        {
            "name": "jeff15_pincell_explicit_1g",
            "input": case_input(repo, "jeff15_pincell_explicit_1g"),
            "doc": case_doc("jeff15_pincell_explicit_1g"),
            "description": "JEFF Report 15 style pin-cell explicit CSG baseline.",
            "expected": 0.8058181237,
            "tol": 1.0e-6,
        },
        {
            "name": "jeff15_pincell_hierarchical_1g",
            "input": case_input(repo, "jeff15_pincell_hierarchical_1g"),
            "doc": case_doc("jeff15_pincell_hierarchical_1g"),
            "description": "Same pin-cell modeled through pin+universe hierarchy and compared with explicit CSG.",
            "expected_from": "jeff15_pincell_explicit_1g",
            "tol": 1.0e-10,
        },
        {
            "name": "jeff15_7x7_explicit_1g",
            "input": case_input(repo, "jeff15_7x7_explicit_1g"),
            "doc": case_doc("jeff15_7x7_explicit_1g"),
            "description": "JEFF Report 15 style 7x7 pin-pattern explicit CSG baseline.",
            "expected": 0.8327631112,
            "tol": 1.0e-6,
        },
        {
            "name": "jeff15_7x7_hierarchical_1g",
            "input": case_input(repo, "jeff15_7x7_hierarchical_1g"),
            "doc": case_doc("jeff15_7x7_hierarchical_1g"),
            "description": "Same 7x7 pin-pattern modeled through pin+lattice+universe hierarchy and compared with explicit CSG.",
            "expected_from": "jeff15_7x7_explicit_1g",
            "tol": 1.0e-10,
        },
    ]

    result_cache: dict[str, dict[str, object]] = {}
    input_cache: dict[Path, dict[str, object]] = {}

    def ensure_result(case: dict[str, object]) -> dict[str, object]:
        name = str(case["name"])
        input_path = Path(case["input"])
        if name in result_cache:
            return result_cache[name]
        if input_path in input_cache:
            result_cache[name] = input_cache[input_path]
            return result_cache[name]
        result = run_case(Path(args.exe), input_path, launcher)
        result_cache[name] = result
        input_cache[input_path] = result
        return result

    lines = [
        "# Validation Results",
        "",
        "| Case | Description | keff | Expected | Abs Error | Tol |",
        "| --- | --- | ---: | ---: | ---: | ---: |",
    ]
    for case in cases:
        result = ensure_result(case)
        expected = float(case["expected"]) if "expected" in case else float(
            ensure_result(next(item for item in cases if item["name"] == case["expected_from"]))["keff"]
        )
        error = abs(float(result["keff"]) - expected)
        if error > float(case["tol"]):
            raise SystemExit(f"validation failed for {Path(case['input']).name}: error={error:.6f}")
        lines.append(
            f"| [{case['name']}]({case['doc']}) | {case['description']} | "
            f"{float(result['keff']):.6f} | {expected:.6f} | {error:.6f} | {float(case['tol']):.6f} |"
        )

    (repo / "validation" / "results" / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
