# homogeneous_square_2g

## 题目目的

验证二维等效、双群、全反射均匀体系中的多群散射与裂变耦合是否正常。

## 模型说明

- 几何：`x-y` 平面上的正方形 `[-1, 1] x [-1, 1]`
- 二维等效处理：`z` 向厚度为 `1.0`，并采用反射边界
- 边界：四周全反射
- 能群：2 群
- 平源区：`8 x 8 x 1` 的 `source region` 细分

## 参考值

- 这个算例的参考值来自当前输入截面对应的均匀本征问题
- 当前验证参考：`keff = 1.257143`

## 当前验证结果

- 当前自动回归结果：`keff = 1.257143`
- 与参考值的绝对误差：`0.000000`
- `tools/run_validation.py` 中当前容差：`1.0e-1`

## 这个算例主要验证什么

- `2D` 模式是否工作正常
- 双群散射与裂变源耦合
- 均匀体系下的二维随机射线推进
- `cell` 内 `source region` 细分在二维问题中的行为

## 文件

- 输入：[homogeneous_square_2g.xml](/d:/Strack/validation/homogeneous_square_2g/homogeneous_square_2g.xml)
- 截面：[homogeneous_2g_mgxs.xml](/d:/Strack/validation/homogeneous_square_2g/homogeneous_2g_mgxs.xml)
