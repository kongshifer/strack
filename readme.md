# Strack

`strack` 是一个面向随机特征线中子输运的实验性程序原型，当前聚焦于“先把可计算、可验证、可扩展的主线跑通”。首版范围限定为多群中子、CSG 几何、二维/三维随机特征线、平源区细分、验证算例，以及便于 Python 后处理的结果导出。

当前已经提供：

- `Fortran 2003 + CMake` 主程序框架
- 贴近 NECP-MCX/OpenMC 风格的 XML 输入与 `.stracki` 预打包流程
- 自定义多群截面库格式 `strack-mg`
- `surface + cell` CSG，支持 `x/y/z-plane`、`x/y/z-cylinder`、`sphere`
- `pin`、`universe`、`rectangular lattice`
- `cell` 级平源区与 `cell` 内笛卡尔细分
- 可选 MPI 并行，兼容本地多核和多节点 OpenMPI 环境
- `*.out` 与 `*_results.py` 输出
- `validation/` 下的首批验证算例与说明文档

基础使用见 [docs/user/usage.md](/d:/Strack/docs/user/usage.md)，MPI/并行补充说明见 [docs/user/usage_mpi.md](/d:/Strack/docs/user/usage_mpi.md)，开发说明见 [docs/developer/architecture.md](/d:/Strack/docs/developer/architecture.md)。
