# unstructured_circle_square_2g

## 题目目的

验证 `strack` 在二维异质两区两群问题上，是否能对“中心燃料圆、外部慢化剂正方形”的 benchmark 给出合理的 `keff` 与通量结果。

## 模型说明

- 几何：边长 `3.0 cm` 的正方形，中心是直径 `2.0 cm` 的圆形燃料区，外部为慢化剂区
- 空间表示：采用 8 个精确 CSG 象限区域显式建模
- 维度：显式 `2D`
- 边界：外边界四周反射，`z` 向采用二维等效反射包层
- 运行参数：`120` 个循环，`18` 个非活跃循环，`2500` 条随机特征线历史

## 截面参数

燃料区：

- `Sigma_t = [1.96647e-1, 5.96159e-1]`
- `nuSigma_f = [6.203e-3, 1.101e-1]`
- `chi = [1.0, 0.0]`
- `Sigma_s = [[1.78e-1, 1.002e-2], [1.089e-3, 5.255e-1]]`

慢化剂区：

- `Sigma_t = [2.22064e-1, 8.87874e-1]`
- `nuSigma_f = [0.0, 0.0]`
- `chi = [1.0, 0.0]`
- `Sigma_s = [[1.995e-1, 2.188e-2], [1.558e-3, 8.783e-1]]`

## 参考结果

你提供的表格里，多个参考程序给出的 `keff` 大致在：

- `MG-MCNP3B: 1.174655`
- `DRAGON: 1.175839`
- `TEPFEM: 1.171747`
- `DNTR: 1.174551`

## 当前验证结果

- 当前自动回归结果：`keff = 1.178010`
- 与 `MG-MCNP3B` 的绝对误差：`0.003355`
- `tools/run_validation.py` 中当前容差：`5.0e-3`

## 关于通量比较的说明

- 程序原始输出的 `source_region_flux` 和 `cell_flux`，物理含义更接近“区域平均标量通量密度”
- 如果直接用“燃料区快群 = 1”去归一化这些区域平均密度，慢化剂区通量会显得偏低
- 对这个 benchmark，如果要和参考表中的区域通量对比，更合理的做法是先做区域积分，再用燃料区快群积分量归一化
- 这个归一化目前建议放在后处理里完成，不写死在主程序中

## 这个算例主要验证什么

- 二维异质几何
- 平面与圆柱曲面混合 CSG
- 两区两群本征值问题
- 参考 `keff` 与区域通量后处理对比

## 文件

- 输入：[unstructured_circle_square_2g.xml](/d:/Strack/validation/unstructured_circle_square_2g/unstructured_circle_square_2g.xml)
- 截面：[unstructured_circle_square_2g_mgxs.xml](/d:/Strack/validation/unstructured_circle_square_2g/unstructured_circle_square_2g_mgxs.xml)
