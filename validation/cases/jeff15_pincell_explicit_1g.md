# jeff15_pincell_explicit_1g

## 题目目的

作为 `pin / universe` 几何功能的显式 CSG 基线。

## 参考来源

- OECD/NEA, JEFF Report 15: *Light Water Reactor (LWR) Pin Cell Benchmark Intercomparisons*.
- 入口页：https://www.oecd-nea.org/jcms/pl_13298/light-water-reactor-lwr-pin-cell-benchmark-intercomparisons?details=true

## 几何说明

- 取 JEFF Report 15 单 pin-cell 问题的典型几何尺度
- pin pitch：`1.26 cm`
- 燃料半径：`0.41 cm`
- 包壳外半径：`0.475 cm`
- 外边界：四周及轴向全反射

## 当前版本的物理简化

- 为了服务 `strack` 的快速回归验证，这里没有使用原始 benchmark 的连续能量或多群物理数据
- 当前只保留 benchmark 风格的几何尺寸
- 截面使用自定义 1 群宏观截面：[jeff15_lwr_1g.xml](/d:/Strack/validation/mgxs/jeff15_lwr_1g.xml)

## 验证角色

- 这是显式 `surface + cell` 建模基线
- 对应层级版本见 [jeff15_pincell_hierarchical_1g.md](/d:/Strack/validation/cases/jeff15_pincell_hierarchical_1g.md)

## 文件

- 输入：[jeff15_pincell_explicit_1g.xml](/d:/Strack/validation/cases/jeff15_pincell_explicit_1g.xml)
- 截面：[jeff15_lwr_1g.xml](/d:/Strack/validation/mgxs/jeff15_lwr_1g.xml)
