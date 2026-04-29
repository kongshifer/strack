# jeff15_pincell_hierarchical_1g

## 题目目的

验证 `pin + universe` 层级几何能否严格展开为与显式 CSG 基线一致的物理模型。

## 参考来源

- OECD/NEA, JEFF Report 15: *Light Water Reactor (LWR) Pin Cell Benchmark Intercomparisons*.
- 入口页：https://www.oecd-nea.org/jcms/pl_13298/light-water-reactor-lwr-pin-cell-benchmark-intercomparisons?details=true

## 几何说明

- 外层 root cell：`1.26 cm x 1.26 cm` 方形 pin-cell
- `universe="pin_u"` 的局部盒单元填充 `fuel30_pin`
- `fuel30_pin` 由 `fuel30 / clad / water` 三层组成

## 验证角色

- 该算例应与 [jeff15_pincell_explicit_1g.xml](/d:/Strack/validation/cases/jeff15_pincell_explicit_1g.xml) 给出相同 `keff`
- 它主要验证：
- `pin` 的环区展开
- `universe` 的层级填充
- 局部几何到全局 CSG 的扁平化

## 文件

- 输入：[jeff15_pincell_hierarchical_1g.xml](/d:/Strack/validation/cases/jeff15_pincell_hierarchical_1g.xml)
- 显式基线：[jeff15_pincell_explicit_1g.xml](/d:/Strack/validation/cases/jeff15_pincell_explicit_1g.xml)
- 截面：[jeff15_lwr_1g.xml](/d:/Strack/validation/mgxs/jeff15_lwr_1g.xml)
