# homogeneous_cube_1g

## 题目目的

验证一群、均匀、全反射三维体系在无泄漏极限下是否收敛到无限介质本征值 `k_inf`。

## 模型说明

- 几何：`[-1, 1]^3` 立方体
- 边界：六面全反射
- 能群：1 群
- 平源区：`6 x 6 x 6`

## 截面参数

- `Sigma_t = 0.40`
- `nuSigma_f = 0.125`
- `Sigma_s = 0.30`
- 因此 `Sigma_a = 0.10`
- 参考本征值：`k_inf = nuSigma_f / Sigma_a = 1.25`

## 验证判据

- 期望 `keff` 接近 `1.25`
- 当前 `tools/run_validation.py` 中采用容差 `8.0e-2`

## 文件

- 输入：[homogeneous_cube_1g.xml](/d:/Strack/validation/cases/homogeneous_cube_1g.xml)
- 截面：[homogeneous_1g.xml](/d:/Strack/validation/mgxs/homogeneous_1g.xml)
