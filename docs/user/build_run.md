# Strack 构建与运行

## 适用范围

本文只说明 `strack` 的构建、部署和运行方式，覆盖：

- Windows 本地串行构建与运行
- Windows 本地 MPI 构建与运行
- Linux 本地串行构建与运行
- Linux/OpenMPI 多节点运行入口

输入卡语法、几何能力和结果字段请结合代码中的现有算例与开发文档阅读。

## 目录约定

当前验证算例按“每个算例一个文件夹”组织：

```text
validation/
  homogeneous_cube_1g/
    homogeneous_cube_1g.xml
    homogeneous_1g_mgxs.xml
    homogeneous_cube_1g.md
    homogeneous_cube_1g_results.py
  ...
  results/
    README.md
```

这意味着：

- 每个算例自己的 XML、截面、说明和结果文件都放在同一个子目录里
- 算例内的 `<library path="...">` 使用本目录下的相对路径
- 自动回归汇总写到 `validation/results/README.md`

## 依赖

### Windows

建议准备：

- `cmake`
- Fortran 2003 编译器
- `ninja`，可选但推荐
- `python`

如果需要 MPI，再额外准备：

- `mpifort`
- `mpirun`

### Linux

建议准备：

- `cmake`
- `gfortran` 或其他支持 Fortran 2003 的编译器
- `ninja-build`，可选但推荐
- `python3`

如果需要 MPI，再额外准备：

- `openmpi`
- `mpifort`
- `mpirun`

## Windows 手动构建

### 串行版本

```powershell
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

如果你不用 `Ninja`，可以改用 Visual Studio 生成器：

```powershell
cmake -S . -B build_vs -G "Visual Studio 17 2022"
cmake --build build_vs --config Release
```

### MPI 版本

确保 `mpifort` 在 `PATH` 中后：

```powershell
cmake -S . -B build_mpi -G Ninja -DCMAKE_BUILD_TYPE=Release -DSTRACK_ENABLE_MPI=ON
cmake --build build_mpi
```

## Windows 一键构建

```powershell
powershell -ExecutionPolicy Bypass -File .\build_scripts\deploy_windows.ps1
```

常用例子：

```powershell
powershell -ExecutionPolicy Bypass -File .\build_scripts\deploy_windows.ps1 -BuildDir build_release -RunTests
powershell -ExecutionPolicy Bypass -File .\build_scripts\deploy_windows.ps1 -BuildDir build_mpi -MPI on -RunTests
```

脚本支持：

- 自动探测 `Ninja`
- 可选 `-Clean`
- 可选 `-RunTests`
- `-MPI auto|on|off`

## Linux 手动构建

### 串行版本

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

### MPI 版本

```bash
cmake -S . -B build_mpi -G Ninja -DCMAKE_BUILD_TYPE=Release -DSTRACK_ENABLE_MPI=ON
cmake --build build_mpi
```

## Linux 一键构建

```bash
bash ./build_scripts/deploy_linux.sh
```

常用例子：

```bash
bash ./build_scripts/deploy_linux.sh --build-dir build_release --run-tests
bash ./build_scripts/deploy_linux.sh --build-dir build_mpi --mpi on --run-tests
```

## 运行方式

### Windows 串行

```powershell
.\build\strack.exe .\validation\homogeneous_cube_1g\homogeneous_cube_1g.xml
```

### Windows MPI

```powershell
mpirun -np 8 .\build_mpi\strack.exe .\validation\homogeneous_cube_1g\homogeneous_cube_1g.xml
```

### Linux 串行

```bash
./build/strack ./validation/homogeneous_cube_1g/homogeneous_cube_1g.xml
```

### Linux MPI

```bash
mpirun -np 8 ./build_mpi/strack ./validation/homogeneous_cube_1g/homogeneous_cube_1g.xml
```

### Linux 多节点

```bash
mpirun -np 128 ./build_mpi/strack ./validation/homogeneous_cube_1g/homogeneous_cube_1g.xml
```

如果集群作业系统要求使用自己的 launcher，也可以改成：

```bash
srun -n 128 ./build_mpi/strack ./validation/homogeneous_cube_1g/homogeneous_cube_1g.xml
```

## 回归验证

手动运行：

```powershell
ctest --test-dir build --output-on-failure
```

或直接调用：

```powershell
python tools/run_validation.py --exe build/strack.exe --repo .
```

MPI 回归可指定 launcher：

```bash
python tools/run_validation.py --exe build_mpi/strack --repo . --launcher "mpirun -np 4"
```

## 当前测试状态

- Windows 一键构建脚本会在本机实际执行并验证
- Linux 脚本已在本机 Git Bash 的 POSIX shell 下完成语法、入口以及配置/编译流程校验
- 由于当前工作机不是原生 Linux 内核，本轮还没有做真正的 Linux 本机编译/运行，建议你后续在 Linux 机器上再跑一遍
