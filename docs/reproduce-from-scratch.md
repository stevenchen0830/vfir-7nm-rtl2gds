# 从公开仓库复现：安装、验证、物理实现与证据

本文是可执行入口；[分阶段 IC Design 手册](rtl-to-gds-walkthrough.md)解释各阶段原理。
三个不同目标必须分开：

| 目标 | 入口 | 能证明什么 |
| --- | --- | --- |
| 检查公开材料 | Python unit tests、report manifests | 文件完整、脚本检查通过；不等于重新运行 EDA |
| 复核历史 v4 | 匿名下载最终 V/SDC/SPEF + pinned Liberty + standalone STA | 在指定模型下复核同一个已布线候选 |
| 从 RTL 再跑一遍 | pinned ORFS + 新 FLOW_VARIANT + synth..finish | 新的物理实现；不得假定与历史 GDS/PPA 逐字节一致 |

**尚不能承诺 foundry signoff 或任意新机器上的 bit-identical GDS。**
历史 v4 存在阶段参数变化，公开的干净重跑配置不是历史每次操作的自动重放。
当前新 MAC 是功能验证候选，不是已经布线通过的新芯片。

## 1. Linux / WSL 环境

建议 Ubuntu 22.04，源码/构建放 Linux 文件系统（而不是 `/mnt/c`）以减少 IO 开销。
Python 3.10+、Git、GNU Make、C++ 编译器、Icarus 和 Verilator；physical build
按下面 ORFS 自带脚本安装依赖。完整 FIR DRT 历史峰值约 24.8 GiB，建议至少
32 GiB 可用 RAM 和 80 GiB 空闲磁盘，实际占用依工具构建和保留跑次增加。
不要同时启动多个大型 FIR DRT，也不要把 swap 当作正常性能配置。

```bash
sudo apt-get update
sudo apt-get install -y git python3 python3-venv build-essential iverilog verilator
git clone https://github.com/stevenchen0830/vfir-7nm-rtl2gds.git
cd vfir-7nm-rtl2gds
export REPO="$PWD"
git rev-parse HEAD
python3 -m unittest discover -s tests -v
python3 tools/check_reproduction.py
python3 tools/check_flow_views.py
python3 verification/reference_model.py
```

锁定复现时应记下上面的仓库 SHA，并以该 SHA 重跑，不以漂移的 `main` 代替。
快速检查预期全部 PASS；历史 timing closure gate 返回非零是已知违例，不应忽略。
仅 AI 学习实验需要额外的 NumPy，见 `experiments/README.md`。

### 安装历史 ORFS 工具链

```bash
cd ..
git clone https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git
cd OpenROAD-flow-scripts
git checkout 8c009b0b663703fc3fe2f474eab918b12fffbaf6
git submodule update --init --recursive
sudo ./setup.sh
./build_openroad.sh --local --no_init --threads 4
export ORFS_ROOT="$PWD"
source ./env.sh
cd "$REPO"
python3 tools/preflight.py --orfs-root "$ORFS_ROOT" --output work/preflight.json
```

不加 `--latest`。锁定 OpenROAD `46ab99414e396fbdd379a432ac664357355bd932`、
Yosys `a5af9d690a43744bf6b2cc3dea2717c16b54621c`。
流程参考 [ORFS 官方安装说明](https://openroad-flow-scripts.readthedocs.io/en/latest/user/BuildLocally.html)，
但以已 checkout 版本的脚本参数为准。二进制编译器/系统不同可以导致 binary hash
不同；preflight 同时记录版本与 SHA，而不是伪装为同一二进制。

原机器还有一项本地修改：为 Yosys clockgate 暴露 `CLKGATE_MIN_NET_SIZE`。
[精确补丁](../flow/toolchain/clockgate-min-net-size.patch)已公开。
不设置该变量时该分支不执行；选择性门控对照实验使用时才需要：

```bash
git -C "$ORFS_ROOT" apply --check "$REPO/flow/toolchain/clockgate-min-net-size.patch"
git -C "$ORFS_ROOT" apply "$REPO/flow/toolchain/clockgate-min-net-size.patch"
```

先检查 diff，已应用时不要重复 apply。`preflight.py` 会对本地修改返回
`REVIEW_REQUIRED`（非零），而不是静默认可。将精确补丁、配置、工具清单纳入
新跑次记录再作比较。[本机实际清单](../reports/toolchain_inventory_20260911.json)
保留了这项告警；没有伪造“clean checkout”。

## 2. 不登录 GitHub 下载并校验历史候选

```bash
cd "$REPO"
python3 tools/fetch_v4_release.py --selection sta --unpack --output work/v4-public
```

通过 HTTPS 匿名下载 `6_final.v.gz/.sdc.gz/.spef.gz`，同时校验压缩与解压后的
SHA256。期望每个文件显示 `VERIFIED`；现有错误文件不会被覆盖。
断网/超时保留 `.part` 供诊断，换新目录重试，不将半个文件当成检查点。
需要 DEF、派生 SDF、vendor views 时改为 `--selection all`。
Vendor tar 不自动解包，避免覆盖工具安装；[资产说明](physical-assets.md)给出
许可和目录语义。原 Liberty 版权必须保留，不能改称本项目 MIT。

某些旧库文件名在新 checkout 中不存在时，先对照公开 vendor manifest 的文件
hash，再将已许可的归档内容放入单独干净的模型目录或补齐匹配的 ORFS 路径。
不得任意选择同名的新 Liberty，或同时加载两个 SIMPLE library。

```bash
python3 tools/run_sta_audit.py --orfs-root "$ORFS_ROOT" \
  --result-dir "$REPO/work/v4-public" --corner FF --u100 \
  --output work/public-ff-u100.rpt
python3 tools/run_closure_matrix.py --orfs-root "$ORFS_ROOT" \
  --result-dir "$REPO/work/v4-public" --output work/public-150-30-matrix
```

第一条复核历史 100/30 ps 假设，预期 setup +34.31 ps、hold +4.88 ps（报告精度范围内）。
第二条保持 1 ns、150/30 ps，逐 FF/TT/SS 输出 min/max/DRV；目前预期退出 2，
因为候选确有违例。不要在 shell 中用 `|| true` 把它变绿。
两者都复用同一份已提取 SPEF，**不是三个独立 RC 角的完整 MMMC**。

本轮已经实际匿名下载这三个文件，压缩/原始 hash 均匹配，并用下载件重跑
第一条 STA：[公开输入重跑报告](../reports/public_reproduction_20260911/FF_u100.rpt)
和[输入/工具/脚本 manifest](../reports/public_reproduction_20260911/FF_u100.manifest.json)。
结果复现 +34.31/+4.88 ps，但原 243 个 slew 违例仍存在；下载成功不是芯片签核成功。

## 3. 从 v4 RTL 重新生成新 GDS

```bash
export NUM_CORES=4
export CORNER=BC
export FLOW_VARIANT=my_v4_bc_01
bash flow/run_stage.sh v4 synth
bash flow/run_stage.sh v4 floorplan
bash flow/run_stage.sh v4 place
bash flow/run_stage.sh v4 cts
bash flow/run_stage.sh v4 route
bash flow/run_stage.sh v4 finish
```

想研究慢角实现，应从开始就选择 `CORNER=WC` 和另一个 variant，不能把 BC
产物的名称改为 WC。这些命令启动大型实验，不是 lightweight CI 的一部分。
源文件、SDC、配置、工具或线程设置改变后，旧 stamp 会拒绝续用；新建 variant。
遇到错误先保留日志和已完成 ODB。绝不回拨文件 mtime、复制旧 final 文件冒充
新结果或修改 stamp 绕过保护。

每一阶段的输入/输出、原理、WNS/TNS/拥塞检查与实测历史耗时，见
[walkthrough 第 3–8 节](rtl-to-gds-walkthrough.md#3-综合)。
核心闭环为：**spec → RTL → verification → synthesis → floorplan → placement
→ CTS → GRT → DRT → RCX → STA/PPA → 违例定位 → 修复后重新走物理闭环**。
PVT/RC、接口、reset、DRC/LVS/EM/IR 是不同检查维度，不是末尾一个 PASS 开关。

## 4. 新 MAC 候选及真实 SRAM 接口

候选入口：[FIR pipeline experiment](../experiments/fir_pipeline/README.md)。
它从哈希固定的 v4 生成独立 top，原 `rtl/` 不变。
完整帧回归使用 Verilator 5.x `--binary --timing`；本机实测 5.050。
发行版自带的旧 4.038 不能运行这个编译仿真入口，仍可用 Icarus 四态 smoke。

已收到的 SRAM 现状表将真实 Liberty/LEF、tCQ、clock min/max 标为 N/A，
仍需有来源的实际模型/预算。
[接口交接表](sram-interface-contract.md)列出了必需信息。在此之前不启动最终
物理闭合跑次，也不把 800 ps/10 ps 旧假设改成能通过的数字。
收到的模型若有保密/再分发限制，只公开允许公开的预算、引用和 SHA，不上传受限模型。

## 5. 验收与已知不能复现的内容

- **报告完整性**：manifest 校验 + DONE marker + 非零失败码。
- **功能**：明确两态/四态、seed、帧数、比较数、错误数与 source hash。
- **物理**：同一候选 V/DEF/ODB + 重新提取的 SPEF + 各视图实际 SDC/Liberty。
- **晋级**：所有目标视图 setup/hold/DRV 为零；约束覆盖与例外另审。
- **缺失不是 PASS**：最终 mapped LEC/SDF GLS、真实 SRAM 集成及 foundry LVS/EM
  仍不能由现有公开报告推出。ASAP7 不提供真实 foundry 流片资格。
- **逐 RC 角**：当前平台的一份 `rcx_patterns.rules` 不应复制改名成 RCmin/RCmax。
  必须有对应校准规则再提取，[OpenRCX 官方说明](https://openroad.readthedocs.io/en/latest/main/src/rcx/README.html)。
- **完全冷启动**：本轮验证下载与现有 pinned 二进制运行；没有在空白虚拟机从零
  编译整个工具链。CI 记录功能和文档可移植性，不冒充大型物理流程冷启动验收。

反馈失败时附：仓库 SHA、preflight JSON、具体命令、完整首个报错、目标 run/variant、
输入 hash 与最新正常检查点。无需提供密码、GitHub token 或商业许可证内容。
