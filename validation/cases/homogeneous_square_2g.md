# homogeneous_square_2g

## 题目目的

验证两群散射、降群和裂变耦合是否正确，以及多群本征值更新是否能收敛到解析矩阵特征值。

## 模型说明

- 几何：`[-1, 1] x [-1, 1] x [-0.5, 0.5]`
- 边界：六面全反射
- 物理上可视作二维均匀问题的三维等效表示
- 能群：2 群
- 平源区：`8 x 8 x 1`

## 截面参数

- `Sigma_t = [0.22, 0.80]`
- `nuSigma_f = [0.14, 0.12]`
- `chi = [1.0, 0.0]`
- `Sigma_s = [[0.08, 0.09], [0.00, 0.50]]`

## 参考值

- 参考值取两群均匀体系本征矩阵主特征值
- 当前脚本计算的参考 `keff = 1.257143`

## 验证判据

- 当前 `tools/run_validation.py` 中采用容差 `1.0e-1`

## 文件

- 输入：[homogeneous_square_2g.xml](/d:/Strack/validation/cases/homogeneous_square_2g.xml)
- 截面：[homogeneous_2g.xml](/d:/Strack/validation/mgxs/homogeneous_2g.xml)
