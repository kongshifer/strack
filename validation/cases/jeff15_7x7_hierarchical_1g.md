# jeff15_7x7_hierarchical_1g

## 题目目的

验证 `pin + lattice + universe` 三层层级几何能否严格展开为与显式 7x7 CSG 基线一致的模型。

## 参考来源

- OECD/NEA, JEFF Report 15: *Light Water Reactor (LWR) Pin Cell Benchmark Intercomparisons*.
- 当前案例借鉴其中 “7x7 array with one central different cell” 的几何组织方式
- 入口页：https://www.oecd-nea.org/jcms/pl_13298/light-water-reactor-lwr-pin-cell-benchmark-intercomparisons?details=true

## 几何说明

- root cell 填充一个 `7 x 7` 的矩形 `lattice`
- `lattice` 中绝大多数位置填充 `u30`，中心位置填充 `u07`
- `u30` / `u07` 两个 `universe` 再分别填充 `fuel30_pin` / `fuel07_pin`

## 验证角色

- 该算例应与 [jeff15_7x7_explicit_1g.xml](/d:/Strack/validation/cases/jeff15_7x7_explicit_1g.xml) 给出相同 `keff`
- 它主要验证：
- `pin` 的多实例放置
- `lattice` 的矩形排布与读入顺序
- `universe` 的递归展开

## 文件

- 输入：[jeff15_7x7_hierarchical_1g.xml](/d:/Strack/validation/cases/jeff15_7x7_hierarchical_1g.xml)
- 显式基线：[jeff15_7x7_explicit_1g.xml](/d:/Strack/validation/cases/jeff15_7x7_explicit_1g.xml)
- 截面：[jeff15_lwr_1g.xml](/d:/Strack/validation/mgxs/jeff15_lwr_1g.xml)
