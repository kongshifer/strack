# jeff15_pincell_explicit_1g

## 题目目的

作为 `pin / universe` 功能开发前的显式 `surface + cell` CSG 基线。

## 参考来源

- OECD/NEA, JEFF Report 15: *Light Water Reactor (LWR) Pin Cell Benchmark Intercomparisons*

## 几何说明

- pin pitch：`1.26 cm`
- 燃料半径：`0.41 cm`
- 包壳外半径：`0.475 cm`
- 外边界与轴向边界：全反射
- 建模方式：显式 `surface + cell`

## 当前版本的物理简化

- 这里只借鉴 benchmark 的几何风格
- 截面使用自定义的 1 群宏观截面库，用于快速回归，不代表正式复现原始 benchmark

## 当前验证结果

- 当前自动回归结果：`keff = 0.808898`
- 该值作为显式基线，被层级几何版本直接对照

## 这个算例主要验证什么

- 显式 pin-cell CSG 建模
- 后续 `pin + universe` 版本的对照基线

## 文件

- 输入：[jeff15_pincell_explicit_1g.xml](/d:/Strack/validation/jeff15_pincell_explicit_1g/jeff15_pincell_explicit_1g.xml)
- 截面：[jeff15_lwr_1g_mgxs.xml](/d:/Strack/validation/jeff15_pincell_explicit_1g/jeff15_lwr_1g_mgxs.xml)
