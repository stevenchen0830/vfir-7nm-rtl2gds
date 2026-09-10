# IMG_FILTER：从规格到 GDS 的分阶段实践手册

本文对应 v4 split-rotator RTL，介绍如何阅读、验证和重现本项目。
它是学术 RTL-to-GDS 流程：ASAP7 是预测性 7 nm PDK，SRAM 仍为外部接口，
没有 foundry-qualified LVS/EM 与完整 MMMC 签核。先阅读
[约束假设与历史更正](constraint-assumptions.md)，再解释任何频率或 PASS。

## 0. 环境与结果入口

物理工具运行在 Linux/WSL。以下命令从仓库根目录执行：

```bash
export REPO="$PWD"
export ORFS_ROOT=/path/to/OpenROAD-flow-scripts
export PATH="$ORFS_ROOT/tools/install/OpenROAD/bin:$ORFS_ROOT/tools/install/yosys/bin:$PATH"
export NUM_CORES=4
export FLOW_VARIANT=reproduce_v4_01
git rev-parse HEAD
git -C "$ORFS_ROOT" rev-parse HEAD
openroad -version
yosys -V
```

历史工具：ORFS `8c009b0b663703fc3fe2f474eab918b12fffbaf6`、OpenROAD
`26Q3-1499-g46ab99414e`、Yosys `0.68+ a5af9d690`，详见
[TOOL_VERSIONS.txt](../reports/TOOL_VERSIONS.txt)。安装工具请按该 ORFS
版本的官方说明，不把宿主机新版本当作历史环境。UVM 使用另一套 Verilator
5.050，不能拿 Ubuntu 22.04 自带的 4.038 直接运行 native UVM。

三个明确入口：历史约束 `config_historical.mk`、v4 实现
`config_v4.mk`、最终 FF 网表上 100/30 ps 的 `audit_ff_u100.tcl`。
默认 `config.mk` 选择 v4 150/30，而不是旧 blanket 约束。
新实现与历史候选的阶段参数差异见约束文档，不承诺每次布局逐字节相同。

## 1. 规格与架构

| 项目 | 接口与约束 |
| --- | --- |
| 像素 | RGBA，每分量 unsigned 10 bit；每 beat 4 像素、160 bit |
| 图像范围 | 回归/集成约定 W=24..1440、H=24..4096；更大宽度需要单独验证，不由端口位宽自动获得支持 |
| 配置编码 | `img_width=W-1`、`img_height=H-1` |
| Kernel | `blk_v` 为 1..49 的奇数；8-bit 非负对称系数，展开后总和 128 |
| 配置时机 | 帧之间发 `frm_start`，上一帧输出先排空；配置按接口约定保持稳定 |
| 流接口 | `rdy && need` 的时钟沿才接受一个 beat；阻塞时 valid 和数据保持 |
| 存储 | 49 个外部单端口 SRAM，160 bit × 1440 words；无实际宏放置 |

数学参考：

```math
Y(y,x,c)=\min\left(1023,\left\lfloor\frac{64+\sum_{k=-h}^h a_k X(\operatorname{mirror}(y+k),x,c)}{128}\right\rfloor\right).
```

上边界 -1 映射到 0，下边界 H 映射到 H-1，即边缘重复的镜像。
W 非 4 的倍数时，最后 beat 无效像素不计入比较。

架构把行 m 固定存入 bank `m mod 49`，地址为当前行 beat 索引。
每行准备等效 bank 权重 `C[j]`，镜像映射到同一行的系数先相加。
这样旋转的是 392-bit 权重向量，数据保留在固定 bank。
当前输入行通过 bypass 进入 MAC，释放相应 bank 给写操作；最大核下最多
48 次 bank read 加一次 write。49 个 bank 槽加 bypass 是 50 个逻辑乘积槽，
并不是同时需要 50 个独立输入行。

![Architecture](img/architecture.svg)

SRAM 协议：posedge 且 CE=1 时执行操作；WE=1 写入，WE=0 同步读取，
读数据通过 NBA 在该边沿后更新；CE=0 保留上次读出值。单端口读写互斥。
行为模型还检查地址范围和 read-before-write；这不等同于真实 SRAM 的 tCQ、
setup/hold、功耗或物理模型。W=1440 时每行只用 360 words。

状态机为 IDLE、PREP、FILL、MAIN、DRAIN。`blk_v=1` 可走无需历史行的路径。
13 个 PREP 周期中：0 装系数；1..8 求 `(2H+23) mod 49`；9 捕获 rotator
低三级结果；10 捕获 `c_fut`；11 转入 `c_cur`；12 完成 PREP。
v4 把旋转量 1/2/4 与 8/16/32 分开寄存，缩短真实组合路径。

![FSM overview](img/fsm.svg)

数据处理依次经过输入缓冲、SRAM 操作、`rdata_q`、pair MAC、partial sums、
舍入/输出缓冲。RTL 注释中的六周期是内部处理路径描述；首个有效输出还包含
PREP、约 h 行填充及 FIFO 等待。遇到 backpressure 后延迟可变化，应按握手
计数而非固定墙钟周期验证。稳态、输入充足且输出不阻塞时目标吞吐为 4 pixels/cycle。

位宽依据：最大合法累加值 `1023*128=130944`，加舍入 64 后为 131008。
所有项非负，因此有效事务的任意部分和不超过该界。v4 保留 ACCW=20；
17-bit 缩窄是可单独验证的优化候选，本文并未修改 v4。CNN 的有符号权重和
bias 不满足这个界，不能沿用这项缩窄。未复位 payload 由复位后的 valid
隔离；完整 RDC 安全仍依赖外部复位同步释放及进一步验证。

## 2. RTL 验证

先执行快速检查，再运行耗时回归：

```bash
python3 verification/reference_model.py
iverilog -g2005 -o /tmp/vfir-smoke.vvp rtl/img_filter_def.v rtl/img_filter.v verification/img_filter_tb.v
vvp /tmp/vfir-smoke.vvp +SMOKE +SEED=12345678
verilator --lint-only -Irtl -Wno-UNSIGNED rtl/img_filter.v --top-module IMG_FILTER
```

预期：参考模型输出 `ALL REFERENCE CHECKS PASSED`；RTL 输出 `TEST PASSED`
和 `ALIGNMENT checks=`。去掉 `+SMOKE` 执行 54 帧。保存完整日志、seed、
工具版本、RTL hash 和退出码。历史 54 帧为 2,821,840 次分量比较、0 errors。
2026-09-07 的周回归四个 seed 通过，但全量任务约六小时后 cancelled；不能
用这个 cancelled run 声称重新跑完 54 帧。

扩展 native UVM：

```bash
export UVM_HOME=/path/to/uvm-verilator/src
export UVM_BUILD_DIR=/path/on/linux/filesystem/vfir-uvm
export VERILATOR=/path/to/verilator-5.050/bin/verilator
bash verification/uvm/run_verilator.sh
```

脚本测试 kernel 1/3/7/49；Python 生成随机输入与直接数学卷积 golden，
UVM predictor 从 input monitor 实际观察到的握手数据独立计算卷积，再与
Python golden 和 DUT 输出两次对照。49-bank SRAM 模型不再把读数据固定为零。
默认宽度 24/25/26/27、高度 56，覆盖所有尾 beat 类别、上下镜像边界与 bank wrap；
再加入一帧学习得到的 K=5 系数，合计 17 帧、6,440 个输出 beat，均已通过。
覆盖计数和 SRAM 访问量写入日志，仍不是完整 UVM/code/toggle coverage closure。

两个负向控制分别破坏一个输出和 SRAM 读数据。预期出现 `MISMATCH`、
非零退出码，再由回归脚本报告 `NEGATIVE CONTROL DETECTED`。
仅有 `UVM_FATAL` 文本不够：此 Verilator/UVM 组合可能通过 `$finish` 返回 0，
top 的 final 检查把 UVM error/fatal 转成 `$fatal(1)`。这个缺陷由故障注入发现。

失败示例（机制示例，实际日志以 audit 为准）：`MISMATCH beat ...` 表示数值或
对齐错误；`Read before write` 指向 bank 调度；`Output changed while blocked`
指向流控保持；超时首先检查是否少输入、少输出或永久阻塞。
形式 BMC 40 周期、EQY 532/680 proven、147 UNKNOWN、1 resource ERROR 是
已有补充证据；不能把有限动态回归或部分等价当成完整证明。

## 3. 综合

```bash
bash flow/run_stage.sh v4 synth
```

Yosys 负责语法展开、逻辑优化、技术映射及 clock-gating pass；ASAP7 使用
asap7sc7p5t、7.5T、RVT、NLDM，AO/OA/INVBUF/SIMPLE/SEQ 五类库。
BC 对应 FF 0.77 V/25°C，WC 对应 SS 0.63 V/100°C。TT 温度应读具体 Liberty，
不能从 BC/WC 推断。库路径、hash 和实际加载列表都要记录；同名 library
重复加载应失败，不能靠最后加载的文件碰运气。

主要输出：`1_2_yosys.v` 技术映射网表、`1_synth.odb` 综合数据库、
`1_synth.sdc` 传播后的约束。v4 综合面积约 43,063 µm²。
最终物理 metrics 记录 22,090 sequential cells、34 ICG、468,048 standard cells；
这些不是 RTL 状态位数。RTL 结构分析为 22,577 state bits，口径不同。
ICG 应统计真实 cell master、输出连接及 gated sinks，不用 `grep -c ICG`
匹配行数替代实例/扇出统计。`INFER_CLKGATES=1` 也不能单独证明映射发生。

## 4. Floorplan 与 Placement

```bash
bash flow/run_stage.sh v4 floorplan
bash flow/run_stage.sh v4 place
```

22% 初始 core utilization 和 PLACE_DENSITY=0.45 是当前约 16.9k 顶层
port bits、无 SRAM 宏的实验布局选择；利用率和布局密度不是同一个参数。
前者决定 core 尺寸，后者影响 global placement 的分布目标。
大量 mem_* 被暴露成顶层端口，IO 可放位置和连线长度可能比 cell area 更早
限制 die 缩小。不能据此推导含 SRAM 的完整芯片面积。

floorplan 包括 die/core、rows/tracks、IO、PDN、tap 等；placement 从全局位置
优化到 resize/buffer 和详细合法化。检查 overlap、IO 放置报错、拥塞 overflow、
局部利用率和线长，并看 WNS/DRV 是否恶化。日志的估算拥塞和最终布线 DRC
是不同指标；overflow=0 不代表所有 slew/timing 通过。

输出 `2_floorplan.odb`、`3_place.odb`。GUI 可用 `read_db` 打开检查点，
但截图只能辅助理解，应保留机器可读 metrics。

## 5. CTS

```bash
bash flow/run_stage.sh v4 cts
```

CTS 建立真实时钟树，之后使用 propagated clock。每条关键路径应展开：
源时钟、common path、launch insertion、capture insertion、data path、
uncertainty、library check、required time 和 slack。
skew 是相应 launch/capture 到达差；某些 report_clock_skew 输出还包含
uncertainty，不要把整个数当成纯物理偏斜。

本项目门控/非门控子树曾出现明显差异。增加 ICG 可能降低时钟动态功耗，
也改变 CTS 和 hold；必须在同候选、同角别、同 parasitic view 下比较。
数据加 buffer 能修某些 hold 路径，但会影响 setup、面积及布线。
旧版本最差路径名不能替代新候选的实际路径报告。

输出 `4_cts.odb`、`4_cts.sdc`。这是阶段性停止并保存的合适位置。
时钟 recovery/removal、pulse width、gating check 没有完整报告时标 UNKNOWN，
不能因普通 setup/hold 通过而推定它们通过。

具体读数示例来自此次 [FF 最终网表复核](../reports/v4_reproduced_ff_u100.rpt)，
不是 CTS 阶段的旧视图：`ymod_f[4] → shi1_q[2]` 最差 hold 路径，launch
clock 到达 509.82 ps，capture 到达 550.37 ps，差约 40.55 ps；data arrival
596.94 ps，hold uncertainty 30 ps，CRPR −1.31 ps，library hold 13.00 ps，
required=592.06 ps，因此 slack=596.94−592.06=+4.88 ps。
这展示了为什么不能把纯树偏斜、uncertainty 和最终 slack 混为同一指标。

## 6. Routing 与寄生提取

```bash
bash flow/run_stage.sh v4 route
bash flow/run_stage.sh v4 finish
```

GRT（global routing）分配大尺度路径和层，产生 route guide，并用于拥塞/
估算 RC 分析；DRT（detailed routing）放置具体 track、线段和 via，处理几何规则。
`5_1_grt.odb` 是全局布线检查点，`5_2_route.odb` 是详细布线结果。
OpenRCX 从最终几何提取寄生，形成 `6_final.spef`。同目录存在 `6_final.v`
并不代表当前新 run 完成：必须检查它的 hash、mtime、日志和 run 身份。

修复后如果未重新布线和提取，只能写 GRT-estimated 或 placement-estimated
结果。不能把旧 SPEF 直接当作修改后网表的新物理证据。
完整 ECO 验证链：修改 → 合法化 → GRT/DRT → RCX → 全目标视图 STA。
现有单 SPEF 跨 Liberty 的诊断不是逐 RC corner 提取的 MMMC。

输出通常为 `6_final.v/.def/.sdc/.spef/.gds/.odb`。SDF 是从 STA 模型导出的
仿真延迟文件，历史 v4 没有生成；本次补导出的文件必须带新日期和场景标签，
不能宣称历史已经执行过 SDF GLS。

## 7. STA 与 PPA 判定

对原始 final candidate 独立复核：

```bash
export RESULT_DIR="$ORFS_ROOT/flow/results/asap7/img_filter/v4"
python3 tools/run_sta_audit.py --orfs-root "$ORFS_ROOT" --result-dir "$RESULT_DIR" \
  --corner FF --u100 --output work/ff_u100.rpt --sdf work/v4_ff.sdf
```

不加 `--u100` 则保留 final SDC 的 150/30。脚本固定历史五类 Liberty，
不会因目录里后来加入另一版 SIMPLE 库就自动替换；日志打印实际文件。
它设置 20 分钟上限、检查退出码和 DONE_MARKER；这说明报告完整执行，
不代表 timing 或 coverage 达标。SDF 的 FF min/max 是该 Liberty 场景，
不能把单角 SDF 称为 FF/SS 联合 min/max。

| 历史 v4 视图 | Setup WNS/TNS | Hold WNS/TNS | 正确结论 |
| --- | --- | --- | --- |
| FF、1 ns、100/30 ps | +34.31 / 0 ps | +4.88 / 0 ps | 指定假设下 setup/hold 通过 |
| FF、1 ns、150/30 ps | -15.69 / -117.37 ps | +4.88 / 0 ps | setup 未闭合，19 endpoints |
| TT、1 ns、150/30 ps | -333.53 ps / 见原报告 | +15.27 ps / 见原报告 | 跨角诊断，setup 未闭合 |
| SS、2 ns、历史 150/150 ps | +76.89 / 0 ps | -303.10 / -1,570,621.12 ps | setup 通过而 hold 未通过；单 SPEF 诊断 |

通过门槛需要逐视图确认 setup/hold WNS≥0、TNS=0、违例端点=0，并检查
slew/cap/fanout、时钟检查、意外 unconstrained endpoints 和所有有效例外。
v4 仍有 243 slew 违例；几何 routing DRC=0 不替代这些电气/时序检查。
check_timing 的历史超时不应永久归因于所有版本，应对新工具和分组检查重评估。

面积 47,297.3 µm² 是 post-route standard-cell area，排除了外部 SRAM 宏。
45.58 mW 是该 FF view 的 vectorless 估计，既不是测得硅功耗，也不是
VCD/SAIF 驱动的总系统能耗。IR-drop 数字依赖 PDN、电流估计和供电边界，
不等同于 EM/IR foundry signoff。比较新架构时固定工作负载、频率、角别、
输出负载、活动与面积统计口径。

## 8. 检查点、耗时、内存与恢复

[机器可读阶段统计](../reports/v4_stage_costs.json) 来自保留的 v4 日志尾部，
不是所有失败重试的总时间，也不是下一轮的时间保证。历史主机 WSL 22 threads、
26 GB RAM＋20 GB swap；增加线程不保证 repair 按比例加速。

| 阶段日志 | 主要检查点 | 历史 wall time | peak memory（约 GiB） |
| --- | --- | --- | --- |
| 1_2_yosys | 1_2_yosys.v | 6.1 min | 4.4 |
| 2_1_floorplan | 2_1_floorplan.odb | 2.3 min | 1.8 |
| 3_3_place_gp | 3_3_place_gp.odb | 17.3 min | 4.9 |
| 3_5_place_dp | 3_place.odb | 6.1 min | 3.1 |
| 4_1_cts | 4_cts.odb | 12.5 min | 3.9 |
| 5_1_grt | 5_1_grt.odb | 165.7 min | 8.3 |
| 5_2_route | 5_2_route.odb | 94.6 min | 24.8 |
| 6_report | reports / 6_final.* | 19.5 min | 13.0 |

| 阶段 | 必需输入 | 交接给下一阶段 |
| --- | --- | --- |
| 综合 | RTL、配置、SDC、Liberty、Yosys/ABC | 映射网表、1_synth.odb/sdc |
| Floorplan | 综合库/网表、LEF、PDN/IO 配置 | 2_floorplan.odb、约束 |
| Placement | floorplan ODB、Liberty、RC 估算 | 3_place.odb/sdc、拥塞/DRV 指标 |
| CTS | placement ODB、时钟单元与 CTS 参数 | 4_cts.odb/sdc、传播时钟树 |
| GRT / DRT | CTS ODB、路由层/规则、有效 SDC | 5_1_grt.odb、5_2_route.odb |
| RCX / finish | 最终路由几何、RC 提取规则、单元视图 | 最终 ODB/DEF/V/GDS/SPEF/SDC |
| Standalone STA | 同一候选 V/SPEF/SDC、精确 Liberty | min/max/DRV 报告、输入 manifest、可选单角 SDF |

暂停应等当前阶段正常结束、ODB 写盘及 make 退出。中途杀掉进程通常保留
上一个完整阶段，但当前阶段的内存内修改会丢失；没有通用命令能把正在
repair 的任意时刻自动保存成可续跑数据库。不要承诺断电后从任意迭代接着跑。

第二天继续时，用相同 ORFS、源码、SDC 和 FLOW_VARIANT：

```bash
export ORFS_ROOT=/path/to/OpenROAD-flow-scripts
export FLOW_VARIANT=reproduce_v4_01
bash flow/run_stage.sh v4 finish
```

`run_stage.sh` 保存输入 fingerprint；修改源码/SDC 后复用同 variant 会拒绝。
用新 variant 跑新实验，不回拨 mtime，不使用 `make clean` 清理基线，不用
伪造旧 stamp 绕过依赖。仍要检查 stage 参数、工具与 upstream hooks，hash
完整性也不能单独证明结果的物理正确性。

```bash
(cd reports && sha256sum -c manifest_v4.sha256)
python3 tools/export_v4_assets.py --orfs-root "$ORFS_ROOT" \
  --output work/v4-assets --repo "$PWD"
(cd work/v4-assets && sha256sum -c assets.sha256)
```

前者仅校验六份历史报告。资产 manifest 另外记录压缩文件和解压后内容的 hash。
网表、SPEF、SDC、Liberty、脚本及工具版本都齐全，才具备重新执行 STA 的条件；
SDF GLS 还需要匹配单元仿真模型、实例路径、timescale、复位/接口模型和注释覆盖检查。
相关资产与许可证见 [physical-assets.md](physical-assets.md)。

## 9. 后续 AI 扩展的证据边界

[AI experiments](../experiments/README.md) 与历史 v4 分开：学习型 FIR 保持原
接口合法系数；INT8 CNN 是新算子，使用有符号权重/独立量化规则；EDA 搜索
先用小型基准验证调度与优化方法。任何新 RTL 的 v4 PPA 都不能直接继承。
