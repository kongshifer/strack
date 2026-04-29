# Strack 架构笔记

## 当前设计

为了尽快形成一个可演化的随机特征线原型，当前版本把职责分成两层：

1. `tools/pack_input.py`
   - 负责解析 XML
   - 负责解析自定义多群库
   - 负责把 `zone` 表达式转成 RPN
   - 负责把 `pin / lattice / universe` 层级几何展开成扁平 CSG
   - 输出 Fortran 更容易读取的 `.stracki`
2. `src/*.f90`
   - 负责几何定位、随机射线追踪、源迭代、keff 更新、结果输出

这个分层的目的很实际：让 Fortran 主体尽量专注数值计算，而不是在首版里把大量精力消耗在 XML 解析上。

## 当前数值主线

- 几何：基于 `surface + cell(zone)` 的 CSG
- 层级几何：`pin / universe / rectangular lattice` 在 Python 预处理阶段展开
- 空间离散：`cell` 或 `cell ∩ cartesian sub-box`
- 射线：在 `ray_source` 盒内均匀采样起点，在单位球面均匀采样方向
- 真空边界体系：优先从真空边界面起射并施加零入流
- 闭体系/全反射体系：继续使用体内随机起射，并依赖 inactive 距离消除初值影响
- 传输：先走 `distance_inactive` 死区，再走 `distance_active` 活跃区
- 估计量：利用段长与指数衰减关系更新区域通量
- 本征值：按累积权重加权的裂变源比值更新 `keff`

## 已知局限

- 当前体积/权重归一化仍是“工程上可运行的第一版”，还不是 OpenMC 随机射线那种更严格的 simulation-averaged volume 处理
- 几何搜索是朴素全表扫描，后续应替换为加速结构
- `hexagonal lattice` 仍未实现
- 暂未引入 CMFD、negative source fixup、source normalization 等增强机制

## 建议的下一步

1. 增加 `hexagonal lattice` 与更完整的 cell transformation 支持
2. 增加更严格的体积估计和通量归一化
3. 引入 OpenMC 风格的随机射线参数与 inactive/active batch 管理
4. 增加 OpenMP 并行
5. 扩展验证题到更完整的 assembly 与 3D benchmark
