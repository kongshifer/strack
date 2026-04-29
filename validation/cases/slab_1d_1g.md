# slab_1d_1g

## 题目目的

验证真空泄漏条件下一维平板本征值问题是否能被当前随机射线原型正确捕捉。

## 参考来源

- Stepanov J. The DPn Surface Flow Integral Neutron Transport Method for Slab Geometry[J]. Nucl Sci & Eng, 1981, 78(1): 53-65.
- 谢仲生, Dorning J J. 三维中子输运方程离散纵坐标节块数值解法[J]. 核科学与工程, 1986, 6(4): 311-322.

## 模型说明

- 原题：一维均匀平板，厚度 `10 cm`
- 本程序中的等效建模：
- `x = 0` 与 `x = 10 cm` 为真空边界
- `y`、`z` 方向取 `[-0.5, 0.5]`，并施加反射边界，以等效一维问题
- 能群：1 群
- 平源区：`80 x 1 x 1`

## 截面参数

- `Sigma_t = 1.0`
- `Sigma_a = 0.08`
- `nuSigma_f = 0.10`
- `Sigma_s = Sigma_t - Sigma_a = 0.92`

## 参考值

- 文献参考解：`keff ≈ 0.95348`

## 当前程序结果说明

- 当前 `strack` 原型采用随机射线 + 平源区源迭代
- 该算例在当前配置下通常得到 `keff ≈ 0.9506`
- 相对参考解偏低约 `0.3%`
- 这一偏差反映了当前原型在真空泄漏体系上的近似误差水平，后续可继续通过更严格的体积归一化和轨道统计改进

## 验证判据

- 当前 `tools/run_validation.py` 中采用参考值 `0.95348`
- 容差设为 `1.0e-2`

## 文件

- 输入：[slab_1d_1g.xml](/d:/Strack/validation/cases/slab_1d_1g.xml)
- 截面：[slab_1g.xml](/d:/Strack/validation/mgxs/slab_1g.xml)
