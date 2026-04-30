# Strack 使用说明

## 当前支持范围

当前版本已经支持：

- 多群中子输运
- `criticality` 与 `fixed-source`
- CSG `surface` 与 `cell`
- `universe`
- `pin`
- `rectangular lattice`
- `x-plane`、`y-plane`、`z-plane`
- `x-cylinder`、`y-cylinder`、`z-cylinder`
- `sphere`
- `cell` 作为单个平源区
- `cell` 内笛卡尔平源区细分
- `reflect`、`vacuum`、`transmission` 边界
- 可选 MPI 并行

当前仍未实现：

- `hexagonal lattice`
- 更严格的体积归一化与加速方法
- 连续能量截面
- 更完整的 tally 体系

## 构建

### 串行或自动探测 MPI

```powershell
cmake -S . -B build -G Ninja
cmake --build build
ctest --test-dir build --output-on-failure
```

说明：

- `strack` 会始终查找 Python 解释器，用于把 XML 预处理成 `.stracki`
- 如果 `mpifort` 不在 `PATH` 上，CMake 会自动回退到串行构建
- 如果只想显式关闭 MPI，可加 `-DSTRACK_ENABLE_MPI=OFF`

### 启用 OpenMPI

确保 OpenMPI 已安装，且 `mpifort`、`mpirun` 在 `PATH` 上，然后：

```bash
cmake -S . -B build -G Ninja -DSTRACK_ENABLE_MPI=ON
cmake --build build
```

如果 CMake 输出 `Building strack with MPI support`，说明当前可执行文件已经带 MPI 能力。

## 运行

### 串行

```powershell
.\build\strack.exe .\validation\cases\homogeneous_cube_1g.xml
```

### 本地多核

```bash
mpirun -np 8 ./build/strack.exe ./validation/cases/homogeneous_cube_1g.xml
```

### 超算多节点

```bash
mpirun -np 128 ./build/strack.exe ./validation/cases/homogeneous_cube_1g.xml
```

或者用作业系统自己的 launcher，例如：

```bash
srun -n 128 ./build/strack.exe ./validation/cases/homogeneous_cube_1g.xml
```

说明：

- MPI 版本与串行版本使用同一份输入格式、同一套求解流程
- 当前并行策略按“全局射线总数 `particles`”切分，每个 rank 负责其中一部分随机特征线历史
- 对于 XML 输入，只有 `rank 0` 会调用 `tools/pack_input.py` 生成 `.stracki`，其他 rank 在屏障后读取同一个打包文件
- 因此多节点运行默认假设各 rank 能访问同一工作目录或共享文件系统
- 如果集群环境不方便共享 XML 预处理结果，可以先串行生成 `.stracki`，再让 MPI 任务直接读取 `.stracki`

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

`source_regions` 是当前版本对“cell 内继续细分平源区”的入口：

- `dimension` 或 `dimensions`：`nx ny nz`
- `lower_left`：细分盒左下后角
- `upper_right`：细分盒右上前角

当前版本要求细分盒覆盖你希望细分的 `cell` 区域。

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

- `z-cylinder`
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

- `case.out`：迭代历史、`keff`、残差以及并行后端信息
- `case_results.py`：`keff_history`、`source_region_flux`、`cell_flux`、`source_region_weights`
- `case_results.py` 还会额外写出 `parallel_backend` 和 `parallel_ranks`

`*_results.py` 可以直接被 Python 导入：

```python
import case_results as r

print(r.parallel_backend, r.parallel_ranks)
print(r.keff)
print(r.cell_flux["core"])
```

## Validation

串行回归：

```powershell
ctest --test-dir build --output-on-failure
```

如果已经构建了 MPI 版本，也可以直接指定 launcher：

```bash
python tools/run_validation.py --exe build/strack.exe --repo . --launcher "mpirun -np 4"
```

更多算例入口见 [validation/README.md](/d:/Strack/validation/README.md)。
