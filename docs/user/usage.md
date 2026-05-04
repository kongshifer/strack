# Strack 使用说明

## 当前支持范围

首个版本聚焦于“先跑起来、先能验证”的主线，当前支持：

- 多群中子输运
- `criticality` 与 `fixed-source` 两种运行模式
- CSG 几何中的 `surface` 与 `cell`
- `universe`
- `pin`
- `lattice`（当前为 `rectangular`）
- `x-plane`、`y-plane`、`z-plane`
- `x-cylinder`、`y-cylinder`、`z-cylinder`
- `sphere`
- `cell` 作为单个平源区
- `cell` 内的笛卡尔平源区细分
- `reflect`、`vacuum`、`transmission` 边界

当前暂未实现：

- `hexagonal lattice`
- 高阶角通量加速与更完整的随机射线体积归一化
- 连续能量截面
- 完整 tally 体系

## 构建

```powershell
cmake -S . -B build -G Ninja
cmake --build build
ctest --test-dir build --output-on-failure
```

## 运行

```powershell
.\build\strack.exe .\validation\cases\homogeneous_cube_1g.xml
```

程序会自动：

1. 调用 `tools/pack_input.py` 把 XML 输入打包成 `.stracki`
2. 运行 Fortran 求解器
3. 生成 `*.out` 和 `*_results.py`

## 输入文件结构

```xml
<input>
  <geometry>
    <surface id="xmin" type="x-plane" coeffs="-1.0" boundary="reflect" />
    <surface id="xmax" type="x-plane" coeffs="1.0" boundary="reflect" />
    <cell id="core" material="fuel" zone="xmin -xmax ymin -ymax zmin -zmax">
      <source_regions dimension="6 6 6"
                      lower_left="-1.0 -1.0 -1.0"
                      upper_right="1.0 1.0 1.0" />
    </cell>
    <cell id="outside" material="void" zone="-xmin|xmax|-ymin|ymax|-zmin|zmax" />
  </geometry>

  <materials>
    <library type="strack-mg" path="../mgxs/homogeneous_1g.xml" />
    <material id="fuel" xs="fuel" />
  </materials>

  <options>
    <run_mode>criticality</run_mode>
    <cycle>60</cycle>
    <inactive>10</inactive>
    <particles>2000</particles>
    <distance_inactive>10.0</distance_inactive>
    <distance_active>90.0</distance_active>
    <seed>13579</seed>
    <ray_source>
      <lower_left>-1.0 -1.0 -1.0</lower_left>
      <upper_right>1.0 1.0 1.0</upper_right>
    </ray_source>
  </options>
</input>
```

## 区域表达式

`zone` 沿用 MCX / MCNP 一类 CSG 习惯：

- 正半空间：`surf`
- 负半空间：`-surf`
- 交：空格
- 并：`|`
- 补：`~`
- 括号：`(` `)`

例如：

```xml
zone="xmin -xmax ymin -ymax zmin -zmax"
```

## 平源区细分

`source_regions` 是当前版本对“cell 内继续细分平源区”的实现入口。

- `dimension` 或 `dimensions`：`nx ny nz`
- `lower_left`：细分盒左下后角
- `upper_right`：细分盒右上前角

当前版本要求这个细分盒覆盖你希望细分的 cell 区域。

## 层级几何

当前版本支持通过 `fill` 和 `universe` 组织层级几何。求解前，`tools/pack_input.py` 会把它们展开成扁平 CSG。

### `pin`

`pin` 当前实现为沿坐标轴的同心圆柱分区，默认沿 `z` 轴：

```xml
<pin id="fuel_pin">
  <materials>fuel clad water</materials>
  <radii>0.41 0.475</radii>
</pin>
```

可选 `axis`：

- `z-cylinder`：默认值
- `x-cylinder`
- `y-cylinder`

### `universe`

`universe` 通过 `cell` 的 `universe` 属性定义，通过另一个 `cell` 的 `fill` 引用：

```xml
<cell id="pin_box" universe="pin_u" fill="fuel_pin"
      zone="uxmin -uxmax uymin -uymax uzmin -uzmax" />
<cell id="root" fill="pin_u" zone="xmin -xmax ymin -ymax zmin -zmax" />
```

### `lattice`

当前支持矩形 `lattice`：

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

说明：

- 二维矩形格架按“每行从左到右，行从上到下”读入
- 实际填充时仍以 `lower_left` 为原点向右、向上布置
- 三维矩形格架支持 `dimensions="nx ny nz"` 与 `pitch="px py pz"`

## 多群截面库格式

库文件根节点为 `<mgxs groups="N">`，每个材料包含：

- `total`
- `nu_sigma_f`
- `chi`
- `scatter`

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

`scatter` 的第 `g` 行表示“从群 `g` 散到各目标群”的截面。

## 输出

- `case.out`：迭代历史、keff、残差等屏幕回显信息
- `case_results.py`：`keff_history`、`source_region_flux`、`cell_flux`、`source_region_weights`

`*_results.py` 可以直接被 Python 导入：

```python
import case_results as r
print(r.keff)
print(r.cell_flux["core"])
```

## Validation

- 验证题入口见 [validation/README.md](/d:/Strack/validation/README.md)
- 每个算例都在 `validation/cases/` 下配有同名 Markdown 说明

## 新增起射与边界微移选项

`options` 里现在可以显式控制射线起射模式和边界后的微小位移量：

```xml
<options>
  ...
  <ray_launch_mode>auto</ray_launch_mode>
  <boundary_epsilon_shift>1.0e-8</boundary_epsilon_shift>
  ...
</options>
```

说明如下：

- `ray_launch_mode`
  - `auto`：默认值。如果 `ray_source` 盒子外侧存在与之重合的 `x/y/z-plane` 真空面，则采用真空面起射；否则退回体内随机起射。
  - `volume`：强制体内随机起射，不再自动切换到真空面起射。
  - `vacuum-surface`：强制真空面起射。如果当前几何里没有可用的真空平面外边界，程序会直接报错并停止。
- `boundary_epsilon_shift`
  - 默认值是 `1.0e-8`。
  - 射线穿过几何边界、反射边界或 `source region` 细分面之后，程序会沿新方向人为前推这一小段距离，避免数值上卡在边界面上。
  - 这个量必须非负。取太大可能带来额外几何误差，取太小甚至取 `0` 则可能导致边界重复命中或定位失败。
  - 当前版本里不建议把它压到 `1e-10` 量级或更小；对 `slab_1d_1g` 这类真空泄漏题，这样做会明显扭曲 `keff`。

推荐用法：

- 一般问题先用 `auto`。
- 想和 OpenMC 风格的体内起射做对照时，用 `volume`。
- 真空泄漏主导题、并且你希望严格测试真空面起射策略时，用 `vacuum-surface`。
