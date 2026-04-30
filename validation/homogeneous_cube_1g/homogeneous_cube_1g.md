# homogeneous_cube_1g

## 题目目的

验证一群、均匀、全反射三维体系在无限介质极限下是否能收敛到本征值 `k_inf`。

## 模型说明

- 几何：立方体 `[-1, 1]^3`
- 边界：六面全反射
- 能群：1 群
- 平源区：`6 x 6 x 6` 的 `source region` 细分

## 截面参数

- `Sigma_t = 0.40`
- `nuSigma_f = 0.125`
- `Sigma_s = 0.30`
- 因此 `Sigma_a = 0.10`
- 参考本征值：`k_inf = nuSigma_f / Sigma_a = 1.25`

## 当前验证结果

- 当前自动回归结果：`keff = 1.249955`
- 与参考值 `1.25` 的绝对误差：`0.000045`
- `tools/run_validation.py` 中当前容差：`8.0e-2`

## 这个算例主要验证什么

- 最基础的随机特征线 `keff` 主线
- 3D 平面 CSG 几何
- 全反射边界处理
- `cell` 内继续细分 `source region` 的功能

## 文件

- 输入：[homogeneous_cube_1g.xml](/d:/Strack/validation/homogeneous_cube_1g/homogeneous_cube_1g.xml)
- 截面：[homogeneous_1g_mgxs.xml](/d:/Strack/validation/homogeneous_cube_1g/homogeneous_1g_mgxs.xml)
