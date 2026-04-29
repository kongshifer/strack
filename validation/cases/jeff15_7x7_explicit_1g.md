# jeff15_7x7_explicit_1g

## 题目目的

作为 `lattice + universe` 几何功能的显式 CSG 基线。

## 参考来源

- OECD/NEA, JEFF Report 15: *Light Water Reactor (LWR) Pin Cell Benchmark Intercomparisons*.
- 当前案例借鉴其中 “7x7 array with one central different cell” 这一类问题的结构思路
- 入口页：https://www.oecd-nea.org/jcms/pl_13298/light-water-reactor-lwr-pin-cell-benchmark-intercomparisons?details=true

## 几何说明

- `7 x 7` pin pattern
- pin pitch：`1.26 cm`
- 大多数 pin 为 `fuel30`
- 中心 pin 为 `fuel07`
- 所有 pin 的燃料半径与包壳外半径分别为 `0.41 cm` 和 `0.475 cm`
- 外边界与轴向边界均取反射

## 当前版本的物理简化

- 与单 pin-cell 案例相同，这里只保留 benchmark 风格几何
- 截面使用自定义 1 群宏观截面：[jeff15_lwr_1g.xml](/d:/Strack/validation/mgxs/jeff15_lwr_1g.xml)

## 验证角色

- 这是显式 `surface + cell` 建模基线
- 对应层级版本见 [jeff15_7x7_hierarchical_1g.md](/d:/Strack/validation/cases/jeff15_7x7_hierarchical_1g.md)

## 文件

- 输入：[jeff15_7x7_explicit_1g.xml](/d:/Strack/validation/cases/jeff15_7x7_explicit_1g.xml)
- 截面：[jeff15_lwr_1g.xml](/d:/Strack/validation/mgxs/jeff15_lwr_1g.xml)
