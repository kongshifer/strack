# Validation 算例中文总览

这份文档用中文说明 `validation/` 里每个算例“做了什么”以及“主要拿来验证什么”。如果你想看每个算例的输入细节、参考值和结果文件，可以继续点进各自子目录里的同名 Markdown。

## 怎么看这些算例

- 有些算例偏“物理基准”，主要检查 `keff` 和通量行为是不是合理。
- 有些算例偏“功能回归”，主要检查几何展开、层级建模和路径追踪有没有跑偏。
- 有些算例同时兼顾了 `cell` 内 `source region` 细分功能。

## 算例说明

### [homogeneous_cube_1g](/d:/Strack/validation/homogeneous_cube_1g/homogeneous_cube_1g.md)

- 做了什么：一个三维、单群、全反射的均匀立方体。
- 主要验证：最基础的 `keff` 主线、3D 平面 CSG、三维随机射线追踪，以及 `cell` 内 `6 x 6 x 6` 的 `source region` 细分。
- 适合用来检查：程序改动后最基本的临界计算有没有被破坏。

### [homogeneous_square_2g](/d:/Strack/validation/homogeneous_square_2g/homogeneous_square_2g.md)

- 做了什么：一个二维等效、双群、全反射的均匀正方形。
- 主要验证：`2D` 模式、多群散射与裂变耦合、二维平面几何，以及 `8 x 8 x 1` 的 `source region` 细分。
- 适合用来检查：二维问题和双群源迭代是否正常。

### [reflective_sphere_1g](/d:/Strack/validation/reflective_sphere_1g/reflective_sphere_1g.md)

- 做了什么：一个单群、全反射的球体。
- 主要验证：球面 `sphere` 几何、曲面反射边界、三维曲面射线追踪，以及 `6 x 6 x 6` 的 `source region` 细分。
- 适合用来检查：程序对曲面 CSG 的支持有没有出问题。

### [slab_1d_1g](/d:/Strack/validation/slab_1d_1g/slab_1d_1g.md)

- 做了什么：把一维真空平板题写成 `x` 向真空、`y/z` 向反射的三维等效模型。
- 主要验证：真空边界起射策略、细长几何中的射线推进，以及 `80 x 1 x 1` 的一维风格 `source region` 细分。
- 适合用来检查：程序在近似一维问题上的行为，尤其是边界处理和细分后的稳定性。

### [unstructured_circle_square_2g](/d:/Strack/validation/unstructured_circle_square_2g/unstructured_circle_square_2g.md)

- 做了什么：二维两区题，中心是燃料圆，外面是慢化剂正方形。
- 主要验证：二维异质问题、平面与圆柱曲面混合 CSG、多群材料切换，以及程序结果与参考 `keff` 的对比。
- 适合用来检查：异质几何下的物理结果是否还在合理范围内。
- 说明：这题当前主要不是拿来测 `source region` 细分，而是拿来测二维异质几何和基准 `keff`。

### [jeff15_pincell_explicit_1g](/d:/Strack/validation/jeff15_pincell_explicit_1g/jeff15_pincell_explicit_1g.md)

- 做了什么：参考 JEFF Report 15 风格的单棒 pin-cell，但用显式 `surface + cell` CSG 建模。
- 主要验证：显式 CSG 的 pin-cell 基线结果。
- 适合用来检查：后续层级几何版本有没有和显式基线对齐。

### [jeff15_pincell_hierarchical_1g](/d:/Strack/validation/jeff15_pincell_hierarchical_1g/jeff15_pincell_hierarchical_1g.md)

- 做了什么：和上一个 pin-cell 物理上是同一题，但几何写法改成 `pin + universe`。
- 主要验证：层级几何展开后，是否能和显式 CSG 基线给出一致结果。
- 适合用来检查：`pin` 和 `universe` 功能是否正确。

### [jeff15_7x7_explicit_1g](/d:/Strack/validation/jeff15_7x7_explicit_1g/jeff15_7x7_explicit_1g.md)

- 做了什么：参考 JEFF Report 15 风格的 `7 x 7` pin 阵列，采用显式 CSG 建模。
- 主要验证：较大规则阵列在显式几何下的基线结果。
- 适合用来检查：多棒元、较大几何规模下的显式建模与输运主线。

### [jeff15_7x7_hierarchical_1g](/d:/Strack/validation/jeff15_7x7_hierarchical_1g/jeff15_7x7_hierarchical_1g.md)

- 做了什么：和上一个 `7 x 7` 阵列物理上同题，但几何写法改成 `pin + lattice + universe`。
- 主要验证：`lattice` 和更完整的层级几何展开是否与显式 CSG 基线一致。
- 适合用来检查：`pin / lattice / universe` 联合使用时的几何展开正确性。

## 建议用法

- 想看最基础的主线是否还正常：先跑 `homogeneous_cube_1g`
- 想看二维与多群：跑 `homogeneous_square_2g` 和 `unstructured_circle_square_2g`
- 想看曲面几何：跑 `reflective_sphere_1g`
- 想看 `source region` 细分：重点看 `homogeneous_cube_1g`、`homogeneous_square_2g`、`reflective_sphere_1g`、`slab_1d_1g`
- 想看层级几何：重点看 `jeff15_*_hierarchical_1g` 和对应 explicit 基线

## 相关文件

- 验证索引见 [README.md](/d:/Strack/validation/README.md)
- 自动回归结果汇总见 [results/README.md](/d:/Strack/validation/results/README.md)
