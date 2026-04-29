from __future__ import annotations

import argparse
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


def run_case(exe: Path, case: Path) -> dict[str, object]:
    subprocess.run([str(exe), str(case)], check=True, cwd=case.parent)
    return parse_result(case.with_name(case.stem + "_results.py"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--exe", required=True)
    parser.add_argument("--repo", required=True)
    args = parser.parse_args()

    repo = Path(args.repo)
    cases = [
        {
            "name": "homogeneous_cube_1g",
            "input": repo / "validation" / "cases" / "homogeneous_cube_1g.xml",
            "doc": "../cases/homogeneous_cube_1g.md",
            "description": "全反射三维一群均匀体系，验证无泄漏极限下的 k_inf。",
            "expected": 1.25,
            "tol": 8.0e-2,
        },
        {
            "name": "homogeneous_square_2g",
            "input": repo / "validation" / "cases" / "homogeneous_square_2g.xml",
            "doc": "../cases/homogeneous_square_2g.md",
            "description": "全反射二维等效两群体系，验证多群散射与裂变耦合。",
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
            "input": repo / "validation" / "cases" / "reflective_sphere_1g.xml",
            "doc": "../cases/reflective_sphere_1g.md",
            "description": "全反射球形一群体系，验证曲面追踪与反射边界。",
            "expected": 1.10,
            "tol": 1.0e-1,
        },
        {
            "name": "slab_1d_1g",
            "input": repo / "validation" / "cases" / "slab_1d_1g.xml",
            "doc": "../cases/slab_1d_1g.md",
            "description": "文献一维真空平板特征值题，采用 3D 等效建模验证泄漏处理。",
            "expected": 0.95348,
            "tol": 1.0e-2,
        },
        {
            "name": "jeff15_pincell_explicit_1g",
            "input": repo / "validation" / "cases" / "jeff15_pincell_explicit_1g.xml",
            "doc": "../cases/jeff15_pincell_explicit_1g.md",
            "description": "JEFF Report 15 风格单 pin-cell 显式 CSG 基线。",
            "expected": 0.8054626000,
            "tol": 1.0e-6,
        },
        {
            "name": "jeff15_pincell_hierarchical_1g",
            "input": repo / "validation" / "cases" / "jeff15_pincell_hierarchical_1g.xml",
            "doc": "../cases/jeff15_pincell_hierarchical_1g.md",
            "description": "同一 pin-cell 的 pin+universe 层级几何版本，对照显式 CSG。",
            "expected_from": "jeff15_pincell_explicit_1g",
            "tol": 1.0e-10,
        },
        {
            "name": "jeff15_7x7_explicit_1g",
            "input": repo / "validation" / "cases" / "jeff15_7x7_explicit_1g.xml",
            "doc": "../cases/jeff15_7x7_explicit_1g.md",
            "description": "JEFF Report 15 风格 7x7 pin-pattern 显式 CSG 基线。",
            "expected": 0.8356857465,
            "tol": 1.0e-6,
        },
        {
            "name": "jeff15_7x7_hierarchical_1g",
            "input": repo / "validation" / "cases" / "jeff15_7x7_hierarchical_1g.xml",
            "doc": "../cases/jeff15_7x7_hierarchical_1g.md",
            "description": "同一 7x7 pin-pattern 的 pin+lattice+universe 层级几何版本，对照显式 CSG。",
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
        result = run_case(Path(args.exe), input_path)
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
        expected = float(case["expected"]) if "expected" in case else float(ensure_result(next(item for item in cases if item["name"] == case["expected_from"]))["keff"])
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
