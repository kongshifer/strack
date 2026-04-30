# reflective_sphere_1g

## 题目目的

验证程序对球面 CSG 几何和曲面反射边界的处理是否正常。

## 模型说明

- 几何：半径为 `1.0` 的球体
- 边界：球面全反射
- 能群：1 群
- 平源区：在包围盒 `[-1, 1]^3` 中使用 `6 x 6 x 6` 的 `source region` 细分

## 参考值

- 当前验证参考：`keff = 1.100000`

## 当前验证结果

- 当前自动回归结果：`keff = 1.099876`
- 与参考值的绝对误差：`0.000124`
- `tools/run_validation.py` 中当前容差：`1.0e-1`

## 这个算例主要验证什么

- `sphere` 曲面几何
- 曲面反射边界条件
- 三维曲面射线追踪
- `cell` 内 `source region` 细分在曲面问题中的使用

## 文件

- 输入：[reflective_sphere_1g.xml](/d:/Strack/validation/reflective_sphere_1g/reflective_sphere_1g.xml)
- 截面：[sphere_1g_mgxs.xml](/d:/Strack/validation/reflective_sphere_1g/sphere_1g_mgxs.xml)
