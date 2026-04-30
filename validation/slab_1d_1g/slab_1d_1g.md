# slab_1d_1g

## 题目目的

验证文献一维真空平板本征值问题在 `strack` 中的三维等效建模路径是否合理。

## 参考来源

- 谢仲生，Dorning J J. 三维中子输运方程离散纵坐标节块数值解法.
- Stepanov I T. The DPn Surface Flow Integral Neutron Transport Method for Slab Geometry.

## 模型说明

- 几何：厚度 `10 cm` 的平板
- 建模方式：`x` 向为真空边界，`y/z` 向为反射边界，用三维等效模型表示一维问题
- 能群：1 群
- 平源区：`80 x 1 x 1` 的 `source region` 细分

## 截面参数

- `Sigma_t = 1.0`
- `Sigma_a = 0.08`
- `nuSigma_f = 0.10`

## 参考值

- 文献参考：`keff ≈ 0.95348`

## 当前验证结果

- 当前自动回归结果：`keff = 0.947358`
- 与参考值的绝对误差：`0.006122`
- `tools/run_validation.py` 中当前容差：`1.0e-2`

## 这个算例主要验证什么

- 真空边界起射策略
- 近一维问题中的随机射线推进
- 长细几何里的 `source region` 细分效果

## 文件

- 输入：[slab_1d_1g.xml](/d:/Strack/validation/slab_1d_1g/slab_1d_1g.xml)
- 截面：[slab_1g_mgxs.xml](/d:/Strack/validation/slab_1d_1g/slab_1g_mgxs.xml)
