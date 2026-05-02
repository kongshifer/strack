# slab_1d_1g

## 题目目的

验证文献中的一维真空平板 `keff` 特征值问题，在 `strack` 采用“三维等效几何 + 真空面起射”路径下能否得到可信结果。

## 参考来源

- 谢仲生，Dorning J J. 三维中子输运方程离散纵坐标节块数值解法.
- Stepanov I T. The DPn Surface Flow Integral Neutron Transport Method for Slab Geometry.

## 模型说明

- 几何：厚度 `10 cm` 的均匀平板
- 建模方式：`x` 向为真空边界，`y/z` 向为反射边界，用三维等效模型表示一维 slab
- 能群：单群
- 平源区：沿厚度方向细分为 `160 x 1 x 1` 个 `source region`
- 迭代参数：`cycle = 120`，`inactive = 40`，`particles = 6000`

## 截面参数

- `Sigma_t = 1.0`
- `Sigma_a = 0.08`
- `nuSigma_f = 0.10`

## 参考值

- 文献参考：`keff ≈ 0.95348`

## 当前验证结果

- 当前自动回归结果：`keff = 0.953009`
- 与参考值的绝对误差：`0.000471`
- `tools/run_validation.py` 当前容差：`1.0e-3`

## 这次修正主要发现了什么

- 旧结果偏低的首要原因，不是截面或几何建模错误，而是开放体系中从真空面起射的特征线在活跃段里被 `distance_active` 过早截断
- 修正后，真空起射且仍在几何内的射线会继续追踪到自然泄漏，再结束 tally
- 这个题对本征迭代收敛和厚度方向平源区细分也比较敏感；把 `cycle / inactive / particles` 和 `source region` 数量调到更合理的档位后，结果会继续向参考值收敛

## 这个算例主要验证什么

- 真空边界起射策略是否正确
- 开放体系中的随机特征线泄漏处理
- 一维等效 slab 中的本征值收敛行为
- 沿厚度方向 `source region` 细分对精度的影响

## 文件

- 输入：[slab_1d_1g.xml](/d:/Strack/validation/slab_1d_1g/slab_1d_1g.xml)
- 截面：[slab_1g_mgxs.xml](/d:/Strack/validation/slab_1d_1g/slab_1g_mgxs.xml)