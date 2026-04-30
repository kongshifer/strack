# jeff15_7x7_hierarchical_1g

## 题目目的

验证 `pin + lattice + universe` 层级几何展开后，是否能与显式 `7 x 7` 基线给出一致结果。

## 参考来源

- OECD/NEA, JEFF Report 15: *Light Water Reactor (LWR) Pin Cell Benchmark Intercomparisons*

## 几何说明

- 物理问题与 `jeff15_7x7_explicit_1g` 相同
- 几何写法改为 `pin + lattice + universe`
- 尺寸、边界和截面设置与显式基线保持一致

## 当前版本的物理简化

- 这里只验证层级几何功能
- 截面仍然使用自定义 1 群宏观截面库，不代表正式复现原始 benchmark

## 当前验证结果

- 当前自动回归结果：`keff = 0.833326`
- 与显式基线 `jeff15_7x7_explicit_1g` 完全一致

## 这个算例主要验证什么

- `pin` 展开
- `lattice` 展开
- `universe` 展开
- 层级几何与显式 `7 x 7` 基线的一致性

## 文件

- 输入：[jeff15_7x7_hierarchical_1g.xml](/d:/Strack/validation/jeff15_7x7_hierarchical_1g/jeff15_7x7_hierarchical_1g.xml)
- 截面：[jeff15_lwr_1g_mgxs.xml](/d:/Strack/validation/jeff15_7x7_hierarchical_1g/jeff15_lwr_1g_mgxs.xml)
