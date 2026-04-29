# Validation Results

| Case | Description | keff | Expected | Abs Error | Tol |
| --- | --- | ---: | ---: | ---: | ---: |
| [homogeneous_cube_1g](../cases/homogeneous_cube_1g.md) | 全反射三维一群均匀体系，验证无泄漏极限下的 k_inf。 | 1.249955 | 1.250000 | 0.000045 | 0.080000 |
| [homogeneous_square_2g](../cases/homogeneous_square_2g.md) | 全反射二维等效两群体系，验证多群散射与裂变耦合。 | 1.257143 | 1.257143 | 0.000000 | 0.100000 |
| [reflective_sphere_1g](../cases/reflective_sphere_1g.md) | 全反射球形一群体系，验证曲面追踪与反射边界。 | 1.099876 | 1.100000 | 0.000124 | 0.100000 |
| [slab_1d_1g](../cases/slab_1d_1g.md) | 文献一维真空平板特征值题，采用 3D 等效建模验证泄漏处理。 | 0.950645 | 0.953480 | 0.002835 | 0.010000 |
| [jeff15_pincell_explicit_1g](../cases/jeff15_pincell_explicit_1g.md) | JEFF Report 15 风格单 pin-cell 显式 CSG 基线。 | 0.805463 | 0.805463 | 0.000000 | 0.000001 |
| [jeff15_pincell_hierarchical_1g](../cases/jeff15_pincell_hierarchical_1g.md) | 同一 pin-cell 的 pin+universe 层级几何版本，对照显式 CSG。 | 0.805463 | 0.805463 | 0.000000 | 0.000000 |
| [jeff15_7x7_explicit_1g](../cases/jeff15_7x7_explicit_1g.md) | JEFF Report 15 风格 7x7 pin-pattern 显式 CSG 基线。 | 0.835686 | 0.835686 | 0.000000 | 0.000001 |
| [jeff15_7x7_hierarchical_1g](../cases/jeff15_7x7_hierarchical_1g.md) | 同一 7x7 pin-pattern 的 pin+lattice+universe 层级几何版本，对照显式 CSG。 | 0.835686 | 0.835686 | 0.000000 | 0.000000 |
