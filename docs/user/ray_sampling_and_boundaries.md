# 射线抽样与边界处理说明

这份文档说明 `strack` 当前版本中，随机特征线的起射、推进和边界处理规则是什么。内容以当前实现为准，主要对应 [src/strack_geometry.f90](/d:/Strack/src/strack_geometry.f90) 和 [src/strack_solver.f90](/d:/Strack/src/strack_solver.f90)。如果想看真空面起射的详细公式推导，可继续看 [docs/user/vacuum_surface_sampling.md](/d:/Strack/docs/user/vacuum_surface_sampling.md)。

## 总体流程

对每个外迭代 `cycle`，程序都会执行下面这条主线：

1. 根据上一步通量构造各个 `source region` 的散射源和裂变源。
2. 按 `particles` 抽样随机射线。
3. 对每条射线先确定起点和方向。
4. 根据起射方式给角通量 `psi` 赋初值。
5. 先走一段 `distance_inactive`，这段只推进、不计 tally。
6. 再走一段 `distance_active`，这段才累计 `delta` 和 `track`。
7. 对开放体系里从真空面起射的射线，如果活跃段走完时还没泄漏出几何，就继续追踪到自然泄漏后再停止。
8. 汇总所有射线贡献，更新区域通量和 `keff`。

## 起射规则

### 1. 先判断是否采用真空面起射

程序会先扫描几何中的 surfaces，只要发现满足下面条件的面，就优先采用“真空面起射”：

- 边界类型是 `vacuum` 或 `out`
- surface 类型是 `x-plane`、`y-plane` 或 `z-plane`
- 该 plane 的位置正好与 `ray_source` 盒子的某个外侧面重合

如果找不到这样的面，程序就退回到“体内随机起射”。

这意味着：

- 真空面起射当前只对轴对齐平面外边界生效
- 曲面真空边界不会触发这套起射逻辑
- 如果外边界没有和 `ray_source` 盒子贴合，也不会触发真空面起射

### 2. 体内随机起射

如果没有采用真空面起射，程序会在 `ray_source` 给出的包围盒里均匀抽样点：

- `3D`：`x/y/z` 都在盒内均匀抽样
- `2D`：`x/y` 均匀抽样，`z` 固定为包围盒中面

抽到点后，程序会检查该点是否落在非 void 的 cell 内；如果不在，就继续重抽。当前最多尝试 `200000` 次。

方向抽样规则是：

- `2D`：极角在 `[0, 2pi)` 上均匀抽样
- `3D`：在单位球面上各向同性抽样

### 3. 真空面起射

如果采用真空面起射，程序会先在所有可用真空外边界上按“面测度”加权选面：

- `2D`：按边长加权
- `3D`：按面积加权

随后在被选中的边界面上均匀抽样起点，再从朝向几何内部的半空间抽样方向：

- `2D`：从入射半圆上做余弦型抽样
- `3D`：从入射半球上做余弦型抽样

真空面起射的角通量初值固定为：

```text
psi = 0
```

这表示零入流边界条件。

## 角通量初值规则

不同起射方式下，射线初始角通量 `psi` 的处理不同：

- 真空面起射：`psi = 0`
- 体内随机起射：对每个能群取当前所在 source region 的

```text
psi_g = source_g / sigma_t_g
```

体内起射配合 `distance_inactive` 使用，目的是让初值影响先衰减一段再开始 tally。

## 射线推进规则

### 1. 每一步取最近事件

射线推进时，程序会同时计算两类距离：

- 到最近几何 surface 的距离
- 到当前 cell 内最近 `source region` 细分面的距离

本步实际步长取三者最小值：

- 剩余可走距离 `remaining`
- 最近 surface 距离
- 最近细分面距离

### 2. 段内解析更新

对当前段长 `step`，程序对每个能群按指数衰减关系更新角通量，并在活跃段中累计：

- `delta_acc(source_region, group)`
- `track_acc(source_region)`

如果本段属于 `distance_inactive`，则只更新 `psi`，不记 tally。

### 3. 穿过 source region 细分面

如果先碰到的是 `source region` 内部细分面：

- 射线方向不变
- 不触发任何边界条件
- 只更新 `source_region_index`

这类面只是平源区切分面，不是物理边界。

### 4. 穿过几何 surface

如果先碰到的是几何 surface，则按该 surface 的边界类型决定后续动作。为了避免数值上卡在边界面上，程序会在穿面或反射后沿新方向做一个很小的位移：

```text
epsilon_shift = 1.0e-8
```

## 边界条件处理规则

### 1. `reflect` / `reflective`

这两种写法都会被当成镜面反射边界。

处理规则是：

1. 把射线推进到边界面上
2. 用 surface 法向量做镜面反射
3. 沿反射后方向做一个 `epsilon_shift`
4. 重新定位射线落入的 cell
5. 如果找不到新 cell，或者新 cell 是 void，则终止该射线

当前反射是严格的几何镜面反射，不做漫反射或白边界处理。

### 2. `vacuum` / `out`

输入预处理阶段会把 `out` 归一化成 `vacuum`。

处理规则分两层：

- 起射层面：如果它是贴着 `ray_source` 盒子的轴对齐外边界，就可作为真空面起射面，且入流角通量取零
- 追踪层面：射线穿过后会继续尝试在边界另一侧定位 cell；如果另一侧没有非 void cell，就认为发生泄漏并终止射线

所以对 vacuum 边界来说，程序体现的是：

- 零入流
- 出流自由泄漏

### 3. `transmission` / `cross`

输入预处理阶段会把 `cross` 归一化成 `transmission`。如果 XML 里没有写 `boundary`，默认也是 `transmission`。

处理规则是：

- 射线直接穿过 surface
- 方向不变
- 穿面后重新定位 cell
- 如果另一侧存在非 void cell，则继续追踪
- 如果另一侧没有 cell 或者是 void，则终止射线

这意味着：

- `transmission` 真正适合用在内部几何分界面
- 如果把外边界写成 `transmission`，但边界外又没有定义新的非 void cell，那么它在效果上仍然会泄漏终止

### 4. `void` cell

`void` 不是一种边界类型，而是一种 cell 材料状态。当前实现里，void cell 会被当作不可输运区域处理：

- 起点不会抽到 void cell 内
- 射线穿面后如果定位到 void cell，会立刻终止

因此，显式写一个包围几何的 `outside` void cell，在当前版本里等价于泄漏汇。

## 几何搜索规则

当前几何追踪支持两种搜索模式：

### 1. `global`

- 找最近 surface 时扫描全部 surfaces
- 穿面后重新定位 cell 时扫描全部 cells

这是最直接、最稳妥的模式，也是默认值。

### 2. `surface-local`

- 找最近 surface 时，只扫描当前 cell 真正用到的 surfaces
- 穿面后优先在该 surface 相邻的 candidate cells 里找下一个 cell
- 如果局部搜索失败，再退回全局扫描

这个模式主要是为了减少几何搜索开销，不改变物理规则。

## 随机数与并行下的抽样

当前实现使用线性同余型随机数推进。

- 串行运行：一条射线的更新种子会接着传给下一条射线
- MPI 运行：每条历史使用 `base_seed + cycle + global_ray_id` 混合后的独立种子

因此：

- 同一输入在串行和 MPI 下通常不会逐位一致
- 但只要统计量足够，物理结果应当收敛到同一水平

## 使用时最需要注意的几点

1. 如果你希望程序真正按“真空入流为零”的开放体系逻辑起射，最好把外边界建成与 `ray_source` 盒子重合的 `x/y/z-plane` 真空面。
2. 如果问题本质上接近一维 slab，推荐像现有 `slab_1d_1g` 那样，用主输运方向开边界、其余方向反射。
3. `transmission` 只表示“不在这张 surface 上做反射或真空入流处理”，不保证边界外仍然存在可追踪介质。
4. `source region` 细分面不会改变方向，也不会施加边界条件；它只影响平源区分辨率。
5. 开放泄漏主导问题通常对 `distance_active`、`cycle / inactive / particles` 和平源区细分更敏感，验证时不要把这些参数压得太省。

## 相关源码

- 起点与方向抽样：[src/strack_geometry.f90](/d:/Strack/src/strack_geometry.f90)
- 射线推进与边界穿越：[src/strack_solver.f90](/d:/Strack/src/strack_solver.f90)
- 输入边界字符串归一化：[tools/pack_input.py](/d:/Strack/tools/pack_input.py)

## 当前可选控制项

现在程序不再只靠自动判断，也支持用户在输入卡里显式指定：

```xml
<ray_launch_mode>auto</ray_launch_mode>
<boundary_epsilon_shift>1.0e-8</boundary_epsilon_shift>
```

- `ray_launch_mode=auto`
  - 有可用真空平面外边界时走真空面起射
  - 否则退回体内随机起射
- `ray_launch_mode=volume`
  - 始终体内随机起射
- `ray_launch_mode=vacuum-surface`
  - 始终要求真空面起射
  - 如果几何里没有与 `ray_source` 盒子重合的 `x/y/z-plane` 真空外边界，程序会直接报错
- `boundary_epsilon_shift`
  - 控制射线穿面、反射后或穿过细分面后的人为前推距离
  - 默认值仍为 `1.0e-8`
  - 当前版本里不建议把它压到 `1e-10` 量级或更小，因为这已经接近内部几何判定容差，可能引发边界附近的数值抖动

因此，当前程序里“采用哪种起射方式”有两层判断：

1. 用户有没有用 `ray_launch_mode` 强制指定
2. 如果设为 `auto`，才再检查当前几何是否具备真空面起射条件
