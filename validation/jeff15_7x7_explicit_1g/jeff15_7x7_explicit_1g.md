# jeff15_7x7_explicit_1g

## 题目目的

作为 `pin + lattice + universe` 功能开发前的显式 `7 x 7` 阵列 CSG 基线。

## 参考来源

- OECD/NEA, JEFF Report 15: *Light Water Reactor (LWR) Pin Cell Benchmark Intercomparisons*

## 几何说明

- `7 x 7` pin 阵列
- pin pitch：`1.26 cm`
- 大多数 pin 使用 `fuel30`
- 中心 pin 使用 `fuel07`
- 所有 pin 的燃料半径和包壳外半径分别为 `0.41 cm` 和 `0.475 cm`
- 外边界与轴向边界均为反射
- 建模方式：显式 `surface + cell`

## 当前版本的物理简化

- 这里只借鉴 benchmark 的几何结构
- 截面仍然使用自定义 1 群宏观截面库，用于程序功能回归

## 当前验证结果

- 当前自动回归结果：`keff = 0.833326`
- 该值作为 `7 x 7` 显式几何基线，被层级几何版本直接对照

## 这个算例主要验证什么

- 多 pin 显式 CSG 建模
- 较大规则阵列中的随机射线主线
- 后续 `pin + lattice + universe` 版本的基线对照

## 文件

- 输入：[jeff15_7x7_explicit_1g.xml](/d:/Strack/validation/jeff15_7x7_explicit_1g/jeff15_7x7_explicit_1g.xml)
- 截面：[jeff15_lwr_1g_mgxs.xml](/d:/Strack/validation/jeff15_7x7_explicit_1g/jeff15_lwr_1g_mgxs.xml)
