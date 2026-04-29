# Strack

`strack` 是一个面向随机特征线中子输运的实验性程序骨架，首个里程碑聚焦于多群中子、CSG 几何、二维/三维随机射线、平源区细分、验证算例和 Python 结果导出。

当前版本已经提供：

- `Fortran 2003 + CMake` 的主程序骨架
- 贴近 MCX 风格的 XML 输入子集
- 自定义多群截面库格式 `strack-mg`
- 支持 `x/y/z-plane`、`x/y/z-cylinder`、`sphere`
- `cell` 级平源区与笛卡尔细分平源区
- 基于随机射线的多群临界/固定源原型求解
- `*.out` 与 `*_results.py` 输出
- `validation/` 下的首批自验证题

快速开始见 [docs/user/usage.md](/d:/Strack/docs/user/usage.md)；架构说明见 [docs/developer/architecture.md](/d:/Strack/docs/developer/architecture.md)。
