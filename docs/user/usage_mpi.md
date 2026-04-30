# Strack MPI 使用补充

## 构建

### Windows

如果本机已经具备可用的 MPI Fortran 工具链：

```powershell
cmake -S . -B build_mpi -G Ninja -DCMAKE_BUILD_TYPE=Release -DSTRACK_ENABLE_MPI=ON
cmake --build build_mpi
```

或者直接使用一键脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\build_scripts\deploy_windows.ps1 -BuildDir build_mpi -MPI on -RunTests
```

### Linux

确保 `mpifort`、`mpirun` 在 `PATH` 上，然后：

```bash
cmake -S . -B build_mpi -G Ninja -DCMAKE_BUILD_TYPE=Release -DSTRACK_ENABLE_MPI=ON
cmake --build build_mpi
```

或者：

```bash
bash ./build_scripts/deploy_linux.sh --build-dir build_mpi --mpi on --run-tests
```

如果 CMake 输出 `Building strack with MPI support`，说明当前可执行文件已经带 MPI 能力。

## 运行

### Windows 本地多核

```powershell
mpirun -np 8 .\build_mpi\strack.exe .\validation\homogeneous_cube_1g\homogeneous_cube_1g.xml
```

### Linux 本地多核

```bash
mpirun -np 8 ./build_mpi/strack ./validation/homogeneous_cube_1g/homogeneous_cube_1g.xml
```

### Linux 多节点

```bash
mpirun -np 128 ./build_mpi/strack ./validation/homogeneous_cube_1g/homogeneous_cube_1g.xml
```

或者用作业系统自己的 launcher，例如：

```bash
srun -n 128 ./build_mpi/strack ./validation/homogeneous_cube_1g/homogeneous_cube_1g.xml
```

## 当前并行策略

- MPI 版本与串行版本使用同一份输入格式、同一套求解流程
- 当前并行策略按“全局射线总数 `particles`”切分，每个 rank 负责其中一部分随机特征线历史
- 对于 XML 输入，只有 `rank 0` 会调用 `tools/pack_input.py` 生成 `.stracki`
- 其他 rank 在屏障后读取同一个打包文件
- 多节点运行默认假设各 rank 能访问同一工作目录或共享文件系统

如果集群环境不方便共享 XML 预处理结果，可以先串行生成 `.stracki`，再让 MPI 任务直接读取 `.stracki`。

## Validation

串行/并行都可以通过 `tools/run_validation.py` 指定 launcher：

```bash
python tools/run_validation.py --exe build_mpi/strack --repo . --launcher "mpirun -np 4"
```

更多算例索引见 [validation/README.md](/d:/Strack/validation/README.md)。
