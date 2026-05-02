# Strack 架构笔记

## 当前分层

为了尽快形成一个可演化的随机特征线原型，当前实现把职责拆成三层：

1. `tools/pack_input.py`
   - 解析 XML
   - 解析自定义多群库
   - 把 `zone` 表达式转成 RPN
   - 把 `pin / lattice / universe` 层级几何展开成扁平 CSG
   - 输出 Fortran 更容易读取的 `.stracki`
2. `src/*.f90`
   - 几何定位
   - 随机射线追踪
   - 源迭代与 `keff` 更新
   - 结果输出
3. `cmake/` 生成模块
   - `strack_config`：把源码目录、Python 解释器、并行后端等配置注入 Fortran
   - `strack_parallel`：根据构建结果生成串行版或 MPI 版并行抽象层

这个分层的目标很直接：把 XML 和层级几何的复杂度尽量留在 Python 预处理阶段，让 Fortran 主体保持数值内核的清晰性。

## 当前数值主线

- 几何：基于 `surface + cell(zone)` 的 CSG
- 层级几何：`pin / universe / rectangular lattice` 在预处理阶段展开
- 空间离散：`cell` 或 `cell -> cartesian sub-box`
- 起射策略：
  - 真空边界体系优先从真空面起射并施加零入流
  - 闭体系继续使用体内随机起射，并依赖 inactive 距离削弱初值影响
- 传输：先走 `distance_inactive` 死区，再走 `distance_active` 活跃区
  - 对真空起射的开放体系，活跃段不会在几何内部被 `distance_active` 人为截断，而是继续追到自然泄漏
- 估计量：利用段长与指数衰减关系更新区域通量
- 本征值：按裂变源比值更新 `keff`

## MPI 设计

### 目标

这一版 MPI 设计优先解决两件事：

- 本地多核和超算多节点使用同一份可执行文件与同一套分解策略
- 没有 OpenMPI 的环境仍然可以正常串行构建和回归

### 构建策略

- CMake 总是探测 Python 解释器，因为 XML 预处理必须可用
- 只有当 `mpifort` 在 `PATH` 上时，才继续尝试 `find_package(MPI)`
- 如果 MPI 可用，生成 `generated/strack_parallel.f90` 的 MPI 版本并链接 `MPI::MPI_Fortran`
- 如果 MPI 不可用，生成同名串行占位模块，保持上层代码不分叉

### 运行策略

- `rank 0` 负责把 XML 打包成 `.stracki`
- 所有 rank 在屏障后读取同一个 `.stracki`
- 每个迭代循环中，`particles` 表示“全局总射线数”，不是每个 rank 各自的射线数
- `strack_parallel:parallel_distribute_count` 对全局射线历史做块分解
- 每个 rank 独立追踪自己的射线，累积局部 `delta` 与 `track`
- 用 `MPI_Allreduce` 对 `delta` 和 `track` 做全局求和
- 归约后每个 rank 都拥有相同的通量更新量和 `keff`
- 只有 `rank 0` 负责 `.out`、`*_results.py` 和屏幕回显

### 随机数策略

- 串行运行保持原来的单流种子推进方式
- MPI 运行时，每条历史使用 `base_seed + cycle + global_ray_id` 混合得到独立种子
- 这样可以避免不同 rank 重复抽到同一条历史
- 这也意味着串行与 MPI 结果一般不会逐位一致，但 MPI 结果对 rank 数变化更稳定

## 已知局限

- 当前体积/权重归一化仍是工程原型水平，还不是 OpenMC 随机特征线那种更严格的 simulation-averaged volume 处理
- 几何搜索仍是朴素全表扫描，后续应替换为更高效的数据结构
- `hexagonal lattice` 仍未实现
- 还没有引入 CMFD、negative source fixup、source normalization 等增强机制
- MPI 当前只覆盖射线历史并行，还没有在更细粒度层面做混合并行
- 多节点模式默认依赖共享文件系统，尚未做输入文件广播

## 后续方向

1. 增加 `hexagonal lattice` 与更完整的 cell transformation 支持
2. 增加更严格的体积估计与通量归一化
3. 引入更接近 OpenMC 风格的 batch 管理和随机特征线控制参数
4. 在 MPI 基础上继续评估 OpenMP 或混合并行
5. 扩展到更完整的 assembly 与 3D benchmark 验证
