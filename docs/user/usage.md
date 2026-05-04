# Strack 使用手册

这份文档把 `strack` 当成一套实际可用的程序来介绍，而不是只做功能概览。目标是让你在下面两类场景里都能直接查到答案：

- 我想跑一个新算例，输入卡应该怎么写
- 我想打开某个功能或修改某项计算设置，应该改输入卡的哪个位置

如果你需要的是构建、部署和跨平台运行步骤，请先看 [docs/user/build_run.md](/d:/Strack/docs/user/build_run.md)。  
如果你想深入理解射线抽样、边界处理或真空面起射公式，请继续看：

- [docs/user/ray_sampling_and_boundaries.md](/d:/Strack/docs/user/ray_sampling_and_boundaries.md)
- [docs/user/vacuum_surface_sampling.md](/d:/Strack/docs/user/vacuum_surface_sampling.md)
- [docs/user/output_reporting.md](/d:/Strack/docs/user/output_reporting.md)

## 1. 当前支持范围

当前版本已经支持：

- 多群中子输运
- `criticality` 与 `fixed-source` 两种运行模式
- 二维与三维随机特征线
- CSG 几何中的 `surface` 与 `cell`
- `x-plane`、`y-plane`、`z-plane`
- `x-cylinder`、`y-cylinder`、`z-cylinder`
- `sphere`
- `pin`
- `universe`
- `rectangular lattice`
- `cell` 作为单个平源区
- `cell` 内笛卡尔平源区细分
- `reflect`、`vacuum`、`transmission` 边界
- `global` 与 `surface-local` 两种几何搜索模式
- `volume`、`vacuum-surface`、`auto` 三种起射模式
- `.out` 和 `*_results.py` 输出

当前暂未实现或暂不建议依赖的内容：

- `hexagonal lattice`
- 连续能量截面
- 完整 tally 体系
- `fill` 与 `source_regions` 同时使用
- 将 `translation` 用在普通材料叶子 `cell` 上的建模工作流

## 2. 输入卡总结构

`strack` 当前使用 XML 输入卡。根节点固定为 `<input>`。

最常见的完整结构如下：

```xml
<input>
  <geometry>
    ...
  </geometry>

  <materials>
    ...
  </materials>

  <sources>
    ...
  </sources>

  <options>
    ...
  </options>
</input>
```

说明：

- `<geometry>`：必需
- `<materials>`：必需
- `<options>`：必需
- `<sources>`：可选，仅在 `fixed-source` 或需要外源时使用

## 3. 常见改法速查

| 我想做什么 | 改输入卡哪里 | 最小改法 |
| --- | --- | --- |
| 跑二维问题 | `<options><spatial_dimension>` | `<spatial_dimension>2</spatial_dimension>` |
| 开启几何搜索加速 | `<options><geometry_search>` | `<geometry_search>surface-local</geometry_search>` |
| 强制体内起射 | `<options><ray_launch_mode>` | `<ray_launch_mode>volume</ray_launch_mode>` |
| 强制真空面起射 | `<options><ray_launch_mode>` | `<ray_launch_mode>vacuum-surface</ray_launch_mode>` |
| 调整 inactive / active 长度 | `<options><distance_inactive>`、`<distance_active>` | 直接改数值 |
| 调整随机数种子 | `<options><seed>` | `<seed>13579</seed>` |
| 把一个 `cell` 细分成多个平源区 | `<geometry><cell><source_regions ... /></cell>` | 增加 `<source_regions>` 子块 |
| 使用层级几何 | `<geometry>` 中添加 `pin` / `lattice` / `universe` / `fill` | 见第 5 节 |
| 切换到固定源问题 | `<options><run_mode>` | `<run_mode>fixed-source</run_mode>` |
| 定义固定源 | `<sources><source ... /></sources>` | 见第 7 节 |
| 调整边界后微移量 | `<options><boundary_epsilon_shift>` | `<boundary_epsilon_shift>1.0e-8</boundary_epsilon_shift>` |

## 4. 一个最小可运行输入示例

下面是一个最小的 `criticality` 示例：

```xml
<input>
  <geometry>
    <surface id="xmin" type="x-plane" coeffs="-1.0" boundary="reflect" />
    <surface id="xmax" type="x-plane" coeffs="1.0" boundary="reflect" />
    <surface id="ymin" type="y-plane" coeffs="-1.0" boundary="reflect" />
    <surface id="ymax" type="y-plane" coeffs="1.0" boundary="reflect" />
    <surface id="zmin" type="z-plane" coeffs="-1.0" boundary="reflect" />
    <surface id="zmax" type="z-plane" coeffs="1.0" boundary="reflect" />

    <cell id="core" material="fuel" zone="xmin -xmax ymin -ymax zmin -zmax">
      <source_regions dimension="6 6 6"
                      lower_left="-1.0 -1.0 -1.0"
                      upper_right="1.0 1.0 1.0" />
    </cell>

    <cell id="outside" material="void" zone="-xmin|xmax|-ymin|ymax|-zmin|zmax" />
  </geometry>

  <materials>
    <library type="strack-mg" path="homogeneous_1g_mgxs.xml" />
    <material id="fuel" xs="fuel" />
  </materials>

  <options>
    <run_mode>criticality</run_mode>
    <cycle>30</cycle>
    <inactive>5</inactive>
    <particles>1200</particles>
    <distance_inactive>6.0</distance_inactive>
    <distance_active>60.0</distance_active>
    <seed>13579</seed>
    <ray_source>
      <lower_left>-1.0 -1.0 -1.0</lower_left>
      <upper_right>1.0 1.0 1.0</upper_right>
    </ray_source>
  </options>
</input>
```

## 5. `<geometry>` 模块

`<geometry>` 负责定义曲面、区域、层级几何和平源区细分。

### 5.1 `<surface>`

基本写法：

```xml
<surface id="xmin" type="x-plane" coeffs="-1.0" boundary="reflect" />
```

属性说明：

| 属性 | 是否必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 曲面名称，供 `zone` 表达式引用 |
| `type` | 是 | 曲面类型 |
| `coeffs` | 是 | 曲面参数 |
| `boundary` | 否 | 边界类型；缺省时按 `transmission` 处理 |

支持的 `type` 与 `coeffs` 写法：

| `type` | `coeffs` 格式 | 物理意义 |
| --- | --- | --- |
| `x-plane` | `x0` | 平面 `x = x0` |
| `y-plane` | `y0` | 平面 `y = y0` |
| `z-plane` | `z0` | 平面 `z = z0` |
| `x-cylinder` | `y0 z0 r` | 轴向沿 `x` 的圆柱 |
| `y-cylinder` | `x0 z0 r` | 轴向沿 `y` 的圆柱 |
| `z-cylinder` | `x0 y0 r` | 轴向沿 `z` 的圆柱 |
| `sphere` | `x0 y0 z0 r` | 球 |

`type` 兼容的常见别名：

- `plane-x` -> `x-plane`
- `plane-y` -> `y-plane`
- `plane-z` -> `z-plane`
- `cylinder-x` -> `x-cylinder`
- `cylinder-y` -> `y-cylinder`
- `cylinder-z` -> `z-cylinder`

支持的 `boundary`：

| 写法 | 说明 |
| --- | --- |
| `reflect` | 反射边界 |
| `reflective` | `reflect` 的别名 |
| `vacuum` | 真空边界 |
| `out` | `vacuum` 的别名 |
| `transmission` | 穿透边界 |
| `cross` | `transmission` 的别名 |

什么时候改这里：

- 改几何尺寸：改 `coeffs`
- 改边界条件：改 `boundary`
- 改几何类型：改 `type` 和对应 `coeffs`

### 5.2 `<cell>`

基本写法：

```xml
<cell id="core" material="fuel" zone="xmin -xmax ymin -ymax zmin -zmax" />
```

支持属性：

| 属性 | 是否必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 区域名称 |
| `zone` | 是 | CSG 区域表达式 |
| `material` | 与 `fill` 二选一 | 叶子材料区域 |
| `fill` | 与 `material` 二选一 | 用 `pin` / `lattice` / `universe` 填充该区域 |
| `universe` | 否 | 该 `cell` 所属宇宙名；缺省为根宇宙 |
| `translation` | 否 | 三个数，主要用于带 `fill` 的层级实例平移 |

注意：

- 当前版本中，一个 `cell` 不要同时写 `material` 和 `fill`
- `material="void"` 表示不可输运区，通常用于几何外侧的 `outside` 区域
- `translation` 的主要用途是“实例化一个被填充的层级对象”；普通叶子材料 `cell` 通常直接靠曲面建模位置

### 5.3 `zone` 区域表达式

`zone` 沿用 MCX / MCNP 风格的 CSG 布尔表达式。

规则：

- `surf`：曲面的正半空间
- `-surf`：曲面的负半空间
- 空格：交
- `|`：并
- `~`：补
- `(` `)`：括号

例子：

```xml
zone="xmin -xmax ymin -ymax zmin -zmax"
```

这表示：

- `x >= xmin`
- `x <= xmax`
- `y >= ymin`
- `y <= ymax`
- `z >= zmin`
- `z <= zmax`

对圆柱和球：

- `-fuel_cyl` 表示“在圆柱内部”
- `fuel_cyl` 表示“在圆柱外部”
- `-s1` 表示“在球内”
- `s1` 表示“在球外”

常见写法：

```xml
<cell id="fuel" material="fuel" zone="xmin -xmax ymin -ymax zmin -zmax -rf" />
<cell id="clad" material="clad" zone="xmin -xmax ymin -ymax zmin -zmax rf -rc" />
<cell id="moderator" material="water" zone="xmin -xmax ymin -ymax zmin -zmax rc" />
```

### 5.4 `<source_regions>`

当你想把一个 `cell` 再切成多个平源区时，在该 `cell` 内加入 `<source_regions>`。

写法：

```xml
<cell id="core" material="fuel" zone="xmin -xmax ymin -ymax zmin -zmax">
  <source_regions dimension="8 8 1"
                  lower_left="-1.0 -1.0 -0.5"
                  upper_right="1.0 1.0 0.5" />
</cell>
```

支持写法：

| 项 | 是否必填 | 说明 |
| --- | --- | --- |
| `dimension` 或 `dimensions` | 是 | `nx ny nz`；也允许只写 `nx ny`，程序会自动补成 `nz = 1` |
| `lower_left` | 是 | 3 个数 |
| `upper_right` | 是 | 3 个数 |

注意：

- `lower_left` 和 `upper_right` 都必须写 3 个值，即使是二维问题也一样
- 细分盒应覆盖你想细分的 `cell` 区域
- 当前版本不支持 `fill` 与 `source_regions` 同时使用

什么时候改这里：

- 想提高平源区分辨率
- 想做同一几何下“粗平源区 / 细平源区”对比

### 5.5 `pin`

`pin` 用来描述沿坐标轴方向的同心圆柱分层。

写法：

```xml
<pin id="fuel_pin">
  <materials>fuel clad water</materials>
  <radii>0.41 0.475</radii>
</pin>
```

可选属性：

| 属性 | 默认值 | 说明 |
| --- | --- | --- |
| `axis` | `z-cylinder` | 允许 `x-cylinder`、`y-cylinder`、`z-cylinder` |

规则：

- `materials` 个数必须等于 `radii` 个数加 1
- 第 1 层是最内层
- 最后一层是最外层包壳之外的背景材料

什么时候改这里：

- 你想用更简洁的方式建 `pin cell`
- 你后面准备把 `pin` 填到 `universe` 或 `lattice`

### 5.6 `universe` 与 `fill`

层级几何靠 `universe` 和 `fill` 组织。

典型写法：

```xml
<surface id="uxmin" type="x-plane" coeffs="-0.63" />
<surface id="uxmax" type="x-plane" coeffs="0.63" />
<surface id="uymin" type="y-plane" coeffs="-0.63" />
<surface id="uymax" type="y-plane" coeffs="0.63" />
<surface id="uzmin" type="z-plane" coeffs="-50.0" />
<surface id="uzmax" type="z-plane" coeffs="50.0" />

<pin id="fuel_pin">
  <materials>fuel clad water</materials>
  <radii>0.41 0.475</radii>
</pin>

<cell id="pin_box" universe="pin_u" fill="fuel_pin"
      zone="uxmin -uxmax uymin -uymax uzmin -uzmax" />
<cell id="root" fill="pin_u" zone="xmin -xmax ymin -ymax zmin -zmax" />
```

规则：

- `universe="pin_u"` 定义该 `cell` 属于哪个宇宙
- `fill="pin_u"` 表示用该宇宙去填充另一个 `cell`
- `fill` 也可以直接引用 `pin` 或 `lattice`

说明：

- 求解前，`tools/pack_input.py` 会把层级几何展开成扁平 `surface + cell`
- 当前版本不支持 `fill` 与 `source_regions` 同时使用

### 5.7 `lattice`

当前只支持矩形 `lattice`。

二维写法：

```xml
<lattice id="lat7" type="rectangular">
  <pitch>1.26 1.26</pitch>
  <dimensions>7 7</dimensions>
  <lower_left>-4.41 -4.41</lower_left>
  <universes>
    u30 u30 u30 u30 u30 u30 u30
    u30 u30 u30 u30 u30 u30 u30
    u30 u30 u30 u07 u30 u30 u30
    u30 u30 u30 u30 u30 u30 u30
    u30 u30 u30 u30 u30 u30 u30
    u30 u30 u30 u30 u30 u30 u30
    u30 u30 u30 u30 u30 u30 u30
  </universes>
</lattice>
```

支持项：

| 项 | 是否必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 格架名称 |
| `type` | 是 | 当前只能写 `rectangular` |
| `<pitch>` | 是 | 二维写 `px py`，三维写 `px py pz` |
| `<dimensions>` | 是 | 二维写 `nx ny`，三维写 `nx ny nz` |
| `<lower_left>` | 是 | 与 `dimensions` 长度一致 |
| `<universes>` | 是 | 数量必须等于所有格点总数 |

二维读入规则：

- 文本按“每行从左到右，行从上到下”写
- 实际铺格时，以 `lower_left` 为左下角原点

三维读入规则：

- 按 `z` 层从低到高
- 每层内部仍按“行从上到下、列从左到右”

### 5.8 `<geometry>` 常见建模建议

- 对开边界问题，推荐显式写一个 `outside` 的 `void` `cell`
- 对二维问题，通常仍使用薄的 `z` 厚度和 `z` 向反射边界
- 对真空泄漏主导问题，尽量让外真空平面和 `ray_source` 盒子对齐，这样可以使用真空面起射

## 6. `<materials>` 模块

`<materials>` 负责把几何中的材料名映射到多群截面库。

### 6.1 `<library>`

写法：

```xml
<library type="strack-mg" path="homogeneous_1g_mgxs.xml" />
```

属性说明：

| 属性 | 是否必填 | 说明 |
| --- | --- | --- |
| `type` | 是 | 当前支持 `strack-mg` 和 `strack-mgxs` |
| `path` | 是 | 截面库路径，相对路径是相对于输入 XML 文件所在目录 |

### 6.2 `<material>`

写法：

```xml
<material id="fuel" xs="fuel" />
<material id="moderator" xs="water" />
```

属性说明：

| 属性 | 是否必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | 几何输入卡中使用的材料名 |
| `xs` | 否 | 映射到库文件中的材料名；不写时默认等于 `id` |

注意：

- `material="void"` 不需要在 `<materials>` 里再定义
- 如果 `xs` 指向的库材料不存在，程序会直接报错

### 6.3 多群截面库格式

库文件根节点为 `<mgxs groups="N">`。

示例：

```xml
<mgxs groups="2">
  <material id="fuel">
    <total>0.22 0.80</total>
    <nu_sigma_f>0.14 0.12</nu_sigma_f>
    <chi>1.0 0.0</chi>
    <scatter>
      <row>0.08 0.09</row>
      <row>0.00 0.50</row>
    </scatter>
  </material>
</mgxs>
```

每个 `<material>` 需要：

- `<total>`
- `<nu_sigma_f>`
- `<chi>`
- `<scatter><row>...</row></scatter>`

规则：

- 所有向量长度必须等于 `groups`
- `scatter` 必须是 `groups x groups`
- 第 `g` 行表示“从源群 `g` 散到各目标群”的截面

## 7. `<sources>` 模块

`<sources>` 是可选模块，主要用于 `fixed-source` 问题，也可用于有外源的测试。

写法：

```xml
<sources>
  <source cell="shield" strength="1.0" spectrum="1.0 0.0" />
</sources>
```

支持属性：

| 属性 | 是否必填 | 说明 |
| --- | --- | --- |
| `cell` | 是 | 固定源所在 `cell` 名 |
| `strength` | 否 | 源强度，默认 `1.0` |
| `spectrum` | 是 | 长度必须等于能群数 |

限制：

- 当前固定源只能加在“展开后的叶子材料 `cell`”上
- 不建议把 `cell` 指到带 `fill` 的层级容器上

如果你要跑固定源问题，通常同时需要：

```xml
<options>
  <run_mode>fixed-source</run_mode>
  ...
</options>
```

说明：

- `fixed-source` 下程序仍会执行源迭代，所以 `cycle / inactive / particles` 仍然有效
- `fixed-source` 下 `keff` 不是主要物理输出，重点看通量结果

## 8. `<options>` 模块

`<options>` 控制维度、迭代、抽样和加速选项，是你最常改的一块。

完整示例：

```xml
<options>
  <run_mode>criticality</run_mode>
  <geometry_search>surface-local</geometry_search>
  <ray_launch_mode>auto</ray_launch_mode>
  <spatial_dimension>2</spatial_dimension>
  <cycle>120</cycle>
  <inactive>18</inactive>
  <particles>2500</particles>
  <distance_inactive>5.0</distance_inactive>
  <distance_active>45.0</distance_active>
  <boundary_epsilon_shift>1.0e-8</boundary_epsilon_shift>
  <seed>314159</seed>
  <ray_source>
    <lower_left>-1.5 -1.5 -0.5</lower_left>
    <upper_right>1.5 1.5 0.5</upper_right>
  </ray_source>
</options>
```

### 8.1 所有可用选项总表

| 标签路径 | 是否必填 | 默认值 | 允许值 / 格式 | 说明 |
| --- | --- | --- | --- | --- |
| `<options><run_mode>` | 否 | `criticality` | `criticality` / `fixed-source` | 运行模式 |
| `<options><geometry_search>` | 否 | `global` | `global` / `surface-local` | 几何搜索模式 |
| `<options><ray_launch_mode>` | 否 | `auto` | `auto` / `volume` / `vacuum-surface` | 起射模式 |
| `<options><spatial_dimension>` | 否 | `3` | `2` / `3` | 二维或三维 |
| `<options><cycle>` | 否 | `50` | 正整数 | 总迭代数 |
| `<options><inactive>` | 否 | `10` | `0 <= inactive < cycle` | 非活跃迭代数 |
| `<options><particles>` | 否 | `1000` | 正整数 | 每个 cycle 的射线条数 |
| `<options><distance_inactive>` | 否 | `10.0` | 非负实数 | inactive 段射线长度 |
| `<options><distance_active>` | 否 | `80.0` | 非负实数 | active 段射线长度 |
| `<options><boundary_epsilon_shift>` | 否 | `1.0e-8` | 非负实数 | 穿面后微移量 |
| `<options><seed>` | 否 | `13579` | 整数 | 随机种子；若写偶数，程序会自动加 1 变成奇数 |
| `<options><ray_source><lower_left>` | 是 | 无 | 3 个实数 | 射线抽样盒下角 |
| `<options><ray_source><upper_right>` | 是 | 无 | 3 个实数 | 射线抽样盒上角 |

### 8.2 `run_mode`

改这里：

```xml
<run_mode>criticality</run_mode>
```

或

```xml
<run_mode>fixed-source</run_mode>
```

用法：

- `criticality`：求 `keff`
- `fixed-source`：给定外源，主要看通量

### 8.3 `geometry_search`

改这里：

```xml
<geometry_search>surface-local</geometry_search>
```

可选值：

- `global`：默认值，稳健，直接扫全局几何
- `surface-local`：加速模式，优先在局部相关曲面与相邻 `cell` 中搜索

兼容别名：

- `surface_local`
- `surface`
- `local`

推荐：

- 初次建模先用 `global`
- 大一点的二维 / 三维问题，可以试 `surface-local` 加速

### 8.4 `ray_launch_mode`

改这里：

```xml
<ray_launch_mode>auto</ray_launch_mode>
```

可选值：

- `auto`
- `volume`
- `vacuum-surface`

兼容别名：

- `internal` / `body` / `body-internal` -> `volume`
- `vacuum_surface` / `surface` / `vacuum-face` -> `vacuum-surface`

三种模式的意义：

- `auto`
  - 有可用真空平面外边界时，自动用真空面起射
  - 否则退回体内起射
- `volume`
  - 始终体内均匀各向同性起射
  - 当前版本里，体内起射射线撞到真空/void 泄漏面后，会把角通量重置为零并继续推进
- `vacuum-surface`
  - 始终从真空面起射
  - 如果几何里没有与 `ray_source` 对齐的真空平面外边界，会直接报错

推荐：

- 一般问题：先用 `auto`
- 想做体内起射对照：用 `volume`
- 真空泄漏主导问题：优先 `vacuum-surface`

重要说明：

- 对 `vacuum-surface`，通常推荐 `distance_inactive = 0`
- 对 `volume`，`distance_inactive` 往往更有意义

### 8.5 `spatial_dimension`

改这里：

```xml
<spatial_dimension>2</spatial_dimension>
```

说明：

- `2`：二维随机射线
- `3`：三维随机射线

注意：

- 即使是二维问题，`ray_source` 也仍然必须给 3 个坐标
- 二维问题通常仍建成一个薄的三维模型，并在 `z` 向设反射边界

### 8.6 `cycle`、`inactive`、`particles`

改这里：

```xml
<cycle>120</cycle>
<inactive>40</inactive>
<particles>6000</particles>
```

含义：

- `cycle`：总迭代数
- `inactive`：前多少个 cycle 只用于收敛，不计最终统计
- `particles`：每个 cycle 抽多少条随机射线

建议：

- 简单回归题可以小一点
- 真空泄漏主导题、强异质题，通常需要更多 `cycle` 和 `particles`

### 8.7 `distance_inactive` 与 `distance_active`

改这里：

```xml
<distance_inactive>10.0</distance_inactive>
<distance_active>80.0</distance_active>
```

含义：

- `distance_inactive`：每条射线先走多长，但这段不记 tally
- `distance_active`：随后再走多长，这段才记 tally

怎么选：

- `volume` 起射：
  - 可以用非零 `distance_inactive` 去削弱错误初值影响
- `vacuum-surface` 起射：
  - 通常直接设 `0.0`
  - 因为起始角通量已经是精确的零入流边界值

### 8.8 `boundary_epsilon_shift`

改这里：

```xml
<boundary_epsilon_shift>1.0e-8</boundary_epsilon_shift>
```

作用：

- 射线穿过边界、反射边界或细分面之后，沿新方向微小前推一点
- 目的是避免数值上卡在边界面上

建议：

- 默认 `1.0e-8` 一般够用
- 不建议压到 `1e-10` 量级或更小
- 也不建议取得太大，否则会引入额外几何误差

### 8.9 `seed`

改这里：

```xml
<seed>13579</seed>
```

说明：

- 如果你写的是偶数种子，程序会自动加 1 改成奇数
- 做重复性测试时，建议固定种子

### 8.10 `ray_source`

写法：

```xml
<ray_source>
  <lower_left>-1.0 -1.0 -1.0</lower_left>
  <upper_right> 1.0  1.0  1.0</upper_right>
</ray_source>
```

规则：

- 必须存在
- `lower_left` 和 `upper_right` 都必须写 3 个值
- 每个方向都要求 `upper_right > lower_left`

作用：

- 定义随机射线的抽样包围盒
- 对 `auto` / `vacuum-surface` 模式来说，也影响真空面可用性判断

推荐：

- 尽量让 `ray_source` 包围实际非 void 几何
- 对真空面起射问题，尽量让 `ray_source` 外盒与真实真空外边界重合

## 9. 输出文件

一次正常运行后，常见输出包括：

- `case.out`
- `case_results.py`
- `case.stracki`

含义：

- `case.out`：屏显回显、输入回显、迭代历史、计时、结果摘要
- `case_results.py`：可直接被 Python 导入的结果数组
- `case.stracki`：XML 预打包后的内部输入文件

`*_results.py` 里常见的结果量有：

- `keff`
- `keff_mean`
- `keff_stderr`
- `keff_variance`
- `keff_history`
- `source_region_flux`
- `cell_flux`
- `source_region_weights`
- `timing_statistics`

## 10. 常见输入修改示例

### 10.1 把三维问题改成二维问题

只改 `<options>`：

```xml
<spatial_dimension>2</spatial_dimension>
```

同时建议：

- 保留薄的 `z` 厚度
- 在 `z` 向用反射边界

### 10.2 打开几何搜索加速

```xml
<geometry_search>surface-local</geometry_search>
```

### 10.3 强制使用真空面起射

```xml
<ray_launch_mode>vacuum-surface</ray_launch_mode>
<distance_inactive>0.0</distance_inactive>
```

### 10.4 强制做体内起射对照

```xml
<ray_launch_mode>volume</ray_launch_mode>
<distance_inactive>100.0</distance_inactive>
```

### 10.5 给 `cell` 加平源区细分

```xml
<cell id="slab" material="fuel" zone="xmin -xmax ymin -ymax zmin -zmax">
  <source_regions dimension="160 1 1"
                  lower_left="0.0 -0.5 -0.5"
                  upper_right="10.0 0.5 0.5" />
</cell>
```

### 10.6 切到固定源问题

```xml
<sources>
  <source cell="shield" strength="1.0" spectrum="1.0 0.0" />
</sources>

<options>
  <run_mode>fixed-source</run_mode>
  ...
</options>
```

## 11. 新手最常见的输入错误

- 忘了写 `<ray_source>`
- `ray_source` 不是 3 个值
- `inactive >= cycle`
- `particles <= 0`
- `distance_inactive` 或 `distance_active` 写成负数
- `boundary_epsilon_shift` 写成负数
- 材料映射到不存在的库材料
- `fill` 与 `source_regions` 同时使用
- 固定源的 `spectrum` 个数和能群数不一致
- `vacuum-surface` 模式下，真空平面外边界没有和 `ray_source` 对齐

这些错误大多会在 `.out` 和终端里直接给出定位信息。

## 12. 从哪里找可直接参考的输入卡

建议直接看 `validation/` 下的现成算例：

- 一维等效 slab： [validation/slab_1d_1g/slab_1d_1g.xml](/d:/Strack/validation/slab_1d_1g/slab_1d_1g.xml)
- 二维异质圆柱-方形题： [validation/unstructured_circle_square_2g/unstructured_circle_square_2g.xml](/d:/Strack/validation/unstructured_circle_square_2g/unstructured_circle_square_2g.xml)
- 简单均匀三维盒子： [validation/homogeneous_cube_1g/homogeneous_cube_1g.xml](/d:/Strack/validation/homogeneous_cube_1g/homogeneous_cube_1g.xml)
- 层级 `pin`： [validation/jeff15_pincell_hierarchical_1g/jeff15_pincell_hierarchical_1g.xml](/d:/Strack/validation/jeff15_pincell_hierarchical_1g/jeff15_pincell_hierarchical_1g.xml)
- 层级 `lattice`： [validation/jeff15_7x7_hierarchical_1g/jeff15_7x7_hierarchical_1g.xml](/d:/Strack/validation/jeff15_7x7_hierarchical_1g/jeff15_7x7_hierarchical_1g.xml)

验证索引见 [validation/README.md](/d:/Strack/validation/README.md)。

## 13. 相关文档

- 构建与运行： [docs/user/build_run.md](/d:/Strack/docs/user/build_run.md)
- 输出与方差说明： [docs/user/output_reporting.md](/d:/Strack/docs/user/output_reporting.md)
- 射线抽样与边界： [docs/user/ray_sampling_and_boundaries.md](/d:/Strack/docs/user/ray_sampling_and_boundaries.md)
- 真空面起射推导： [docs/user/vacuum_surface_sampling.md](/d:/Strack/docs/user/vacuum_surface_sampling.md)
- MPI/并行补充： [docs/user/usage_mpi.md](/d:/Strack/docs/user/usage_mpi.md)
