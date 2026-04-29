# reflective_sphere_1g

## 题目目的

验证球面几何追踪和反射边界处理是否正确。

## 模型说明

- 几何：半径 `1.0 cm` 的球体
- 边界：球面全反射
- 能群：1 群
- 平源区：外接盒内 `6 x 6 x 6` 细分

## 截面参数

- `Sigma_t = 0.50`
- `nuSigma_f = 0.11`
- `Sigma_s = 0.40`
- 因此 `Sigma_a = 0.10`
- 参考本征值：`k_inf = 1.10`

## 验证判据

- 当前 `tools/run_validation.py` 中采用容差 `1.0e-1`

## 文件

- 输入：[reflective_sphere_1g.xml](/d:/Strack/validation/cases/reflective_sphere_1g.xml)
- 截面：[sphere_1g.xml](/d:/Strack/validation/mgxs/sphere_1g.xml)
