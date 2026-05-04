# Strack 输出与报错说明

## 输出文件

每次运行 `strack` 后，当前版本会生成两类主要输出：

- `case.out`
  - 保存输入卡回显
  - 保存屏幕回显中的参数、统计量、计时和最终结果
  - 保存逐循环 `keff / max_dphi` 历史
- `case_results.py`
  - 保存便于 Python 后处理的数组、统计量和计时字典

如果输入是 XML，程序会先调用 `tools/pack_input.py` 生成 `.stracki`，然后再进入 Fortran 求解阶段。

## 屏显与 `.out` 的结构

`case.out` 与终端屏显的主要结构保持一致：

0. 实时 `cycle / batch` 进度
   - 每个循环结束后立即回显一行
   - inactive 循环显示当前 `keff`
   - active 循环显示当前 `keff`、当前 active 样本均值与 `stderr`
1. `INPUT ECHO`
   - 原始输入文件路径
   - 原始输入文件全文回显
2. `CALCULATION SETTINGS`
   - 在计算结束后统一输出，避免与实时循环信息交错
   - 算例名、输入路径、打包路径
   - 并行后端、rank 数
   - `run_mode`
   - `geometry_search`
   - 空间维度、群数、循环数、射线数
   - `distance_inactive / distance_active`
   - source region 数、非 void cell 数、材料数、随机种子
   - 当前射线起射模式和边界统计
3. `SIMULATION STATISTICS`
   - 总历史数
   - 几何交点数
   - 细分面穿越次数
   - 轨迹积分段数
   - 每循环平均值
4. `TIMING STATISTICS`
   - 初始化时间
   - XML 预处理时间
   - 输入装载时间
   - 输入回显时间
   - 带 `*` 强调的总模拟时间
   - transport/source/tally/MPI 各阶段时间
   - active / inactive 循环时间
   - 输出写文件时间
5. `RESULTS`
   - `k-effective (active mean) +/- stderr`
   - 最后一轮 `keff`
   - `keff_variance`
   - 参与统计的 active 循环数

## `*_results.py` 中的关键字段

### 本征值相关

- `keff`
  - 最后一轮迭代得到的 `keff`
- `keff_mean`
  - 所有 active 循环 `keff` 的样本均值
- `keff_variance`
  - 所有 active 循环 `keff` 的样本方差
- `keff_stddev`
  - `sqrt(keff_variance)`
- `keff_stderr`
  - `keff_stddev / sqrt(n_active_cycles)`
- `keff_history`
  - 每轮循环的 `keff` 历史

### source region 通量相关

- `source_region_flux`
  - 最后一轮迭代的 source region 平均标量通量密度
- `source_region_flux_mean`
  - active 循环样本均值
- `source_region_flux_variance`
  - active 循环样本方差
- `source_region_flux_stddev`
  - active 循环样本标准差
- `source_region_flux_stderr`
  - active 循环样本标准误差

### cell 通量相关

- `cell_flux`
  - 由 source region 通量按轨迹权重折叠得到的最后一轮 cell 平均通量密度
- `cell_flux_mean`
  - active 循环样本均值
- `cell_flux_variance`
  - active 循环样本方差
- `cell_flux_stddev`
  - active 循环样本标准差
- `cell_flux_stderr`
  - active 循环样本标准误差

### 其他辅助量

- `source_region_weights`
  - active 循环累计的轨迹权重
- `simulation_statistics`
  - 总循环数、总射线数、交点数、积分段数等统计
- `timing_statistics`
  - 初始化、输运、输出等时间统计

## 当前方差的定义

当前版本对 `keff`、source region 通量和 cell 通量，都是把每个 active 循环视为一个样本，按样本统计量计算：

\[
s^2 = \frac{1}{N-1}\sum_{n=1}^{N}(x_n-\bar{x})^2
\]

其中：

- `N = n_active_cycles`
- `x_n` 是第 `n` 个 active 循环的标量或通量估计
- `\bar{x}` 是 active 循环样本均值

因此当前输出更接近“批次样本统计量”，而不是严格意义上经过自相关修正的最终蒙特卡罗不确定度。

## 结果解释建议

- 如果想看程序收敛后的代表值，优先看 `keff_mean`、`cell_flux_mean`、`source_region_flux_mean`
- 如果想看最后一轮求解状态，可看 `keff`、`cell_flux`、`source_region_flux`
- 如果想看统计波动，优先看 `*_stderr`
- 如果想做更细的后处理，建议直接导入 `*_results.py`

## 输入报错机制

当前输入报错分两段：

1. XML 预处理阶段
   - 由 `tools/pack_input.py` 负责
   - 缺失属性、非法边界、无效数值、路径错误等会直接报错
   - 错误信息会回显到终端，并写入 `.out`
2. `.stracki` 装载阶段
   - 由 Fortran `load_model` 负责
   - 未知 section、字段数不足、整数/实数解析失败、未知 surface/material 等会报错
   - 错误信息会尽量包含：
     - 文件名
     - 行号
     - 字段名或记录名

## 当前已知限制

- XML 预处理阶段的错误通常能定位到具体选项或块，但还没有覆盖到所有节点的精确 XML 行号
- `stderr` 目前基于 active 循环样本统计，没有做更严格的批相关性分析
- 极短运行下，某些很小的计时项可能显示为 `0.0`
