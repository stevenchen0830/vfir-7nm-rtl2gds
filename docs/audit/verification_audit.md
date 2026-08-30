# VFIR 7 nm 项目验证审计

审计对象：`stevenchen0830/vfir-7nm-rtl2gds`，提交 `cc60e8a`  
本地工具：Icarus Verilog 14.0、Yosys 0.68+136、SBY v0.68、EQY v0.68、Boolector 3.2.4

## 总结

| 检查项 | 结论 | 关键证据 |
|---|---|---|
| 形式功能完备性 | **部分通过，未完备证明** | RTL 回归 54 帧、2,821,840 次分量比对、0 错误；参考模型 117 组通过；关键控制属性 40 周期 BMC 通过。尚无覆盖完整 FIR 事务语义的无界形式证明。 |
| CDC/RDC | **模块 CDC 结构通过；RDC 有条件** | 556 个时序单元全部使用同一个 `clk`，所有异步复位单元只使用 `rst_n`。但 21,416 个状态位中 20,178 位不复位，且复位同步释放器位于模块外、仓库中不可见。 |
| 综合等价 | **未完全证明** | 本地 RTL→Yosys 通用综合网表共 682 个分区：532 个证明等价，149 个 `UNKNOWN`，巨型 `rdata_q[7839:0]` 发生资源/工具错误，0 个明确不等价。仓库没有物理流程最终网表，无法检查真正的 ORFS 输出。 |
| MMMC/最终时序 | **明确未闭合** | 1 GHz 下 BC 和 WC 均有 setup/hold/DRV 违例；仓库也明确说明单一 SPEF、修复后未重布线/重提取、无 LVS/EM。 |

因此，当前项目可以诚实表述为：**学术 RTL-to-GDS 流程展示，RTL 动态验证充分，关键控制和单时钟结构已有额外证据，但不是功能形式完备、综合等价闭合或 tapeout signoff 项目。**

## 1. 形式功能检查

### 已通过

- 自检 RTL testbench：54 帧，2,821,840 次分量检查，0 错误，`TEST PASSED`。
- Python 参考模型：镜像边界 14 个角例、117 组 shape/kernel 架构对照、常量图保持和 10-bit 饱和余量均通过。
- Yosys 展开与结构检查：`check -assert` 为 0 个问题；仅有 3 条“unpacked memory 转寄存器”信息性警告。
- 从复位出发的 40 周期控制安全 BMC 通过，覆盖：
  - 状态机、写 bank 和输入计数器边界；
  - `mem_we` 必须从属于 `mem_ce` 且 one-hot；
  - SRAM 同一 bank 不同时读写；
  - 复位后输出和 SRAM 命令保持静默；
  - 输出被 backpressure 阻塞时 `valid` 不丢失。

### 尚未证明

这些结果不能推出“所有合法输入序列都正确”。现有形式属性主要是控制安全属性，没有把黄金 FIR 数学模型与 RTL 的完整输出事务逐拍连接，也没有证明任意帧长、全部系数、所有停顿排列下的端到端等价。因此本项状态仍是 **PARTIAL / NOT COMPLETE**。

闭合方式是建立 transaction-level formal harness：约束合法帧配置和系数稳定性，用独立黄金模型生成期望输出序列，并证明每次输出握手的数据、次序和数量一致；再对大状态空间做 bank/lane 分解与 assume-guarantee 证明。

## 2. CDC/RDC 检查

结构提取结果：

- 时序单元：556 个，共 21,416 位状态；
- 顺序逻辑时钟网：1 个，全部对应顶层 `clk`；
- 异步复位网：1 个，全部对应顶层 `rst_n`；
- 未发现数据作时钟、内部生成时钟或多时钟域，因此模块内部没有 CDC crossing；
- 1,238 位带异步复位，20,178 位不复位。

RDC 不能直接判为完全通过。SDC 对 `rst_n` 设全局 false path，并假定它由模块外同步器释放；仓库没有该同步器，无法验证其级数、MTBF、恢复/移除时间和所有目的寄存器的一致释放。大量不复位 datapath 在架构上可行，但必须依赖已复位的 valid/control 信号隔离未知数据。40 周期控制 BMC 为关键隔离路径提供了有限证据，尚不是芯片级 RDC signoff。

建议在集成仓库中加入 reset synchronizer RTL、同步释放属性和商业/开源结构报告，并增加“复位后直到 valid 建立前，未复位 payload 不可影响输出或 SRAM 命令”的无界形式属性。

## 3. 综合等价检查

本地通用综合成功，Yosys 最终生成 471,688 个通用单元，`check -assert` 为 0 个问题。随后 EQY 将 RTL 与该通用综合网表切成 682 个分区：

- 532 个分区证明等价；
- 149 个分区在深度 5 SAT 和深度 2 SMT 后仍为 `UNKNOWN`；这些分区的 reset-reachable base case 通过，但任意状态归纳没有闭合；
- `rdata_q[7839:0]` 单分区过大：SAT 内存增长到约 5 GB 后切换策略，SMT2 生成又发生 Windows stack overflow；
- 没有任何分区给出真实 `FAIL`/不等价反例。

这表示“未发现综合改错证据”，但不等于 LEC PASS。更关键的是，公开仓库缺少 `6_final.v`、最终 SPEF 和对应 Liberty，因此无法对真正的 ORFS/ASAP7 最终网表进行等价与最终 STA。

闭合方式：从物理流程导出最终综合网表/布局后网表，保留状态匹配信息；将 `rdata_q` 按 SRAM bank 或固定 bit slice 分区，并给未复位状态添加 reset-reachable/valid 不变量，然后重新跑完整 LEC。

## 4. MMMC 与最终时序

### 仓库已有的 1 GHz 结果

| 视图 | Setup WNS / TNS | Hold WNS / TNS | 其他违例 |
|---|---:|---:|---:|
| BC finish | −50.35 ps / −2,045.86 ps，140 条 | −37.77 ps / −8,679.22 ps，1,601 条 | slew 881，cap 1 |
| WC finish | −950.61 ps / −4,608,623 ps，10,694 条 | 报告仍有 5,682 条 hold | slew 330 |

所以 1 GHz 明确没有闭合。仓库的周期扫描约在 1,950.6 ps（约 513 MHz）才满足 true-WC setup；这与“1 GHz 最终签核通过”不是同一结论。

### 签核口径缺口

- 单一 SPEF 被复用，不是真正的多 RC corner 提取；
- selective-gating hold repair 后没有重新布线和重新提取，复查为 GRT 估算视图；
- `sta_bc_full.rpt` 和 `sta_wc_audit.rpt` 的 `check_timing` 均以 `tool_rc=124` 超时，没有完成无约束端点、no-clock、IO delay 等完整审计；
- SDC 对 setup/hold 共用 `set_clock_uncertainty 150`，同时以虚拟时钟、800 ps 公共插入和 output `-min 500` 表达共享树假设；这是学术模型，必须由真实接口和宏时序模型校准后才能签核；
- `rst_n` 全 false-path 依赖外部同步释放假设；
- 没有 post-repair route/RC、LVS、EM、SRAM macro integration signoff。

本项严格状态是 **FAIL / NOT CLOSED**，而不是“尚未检查”。

## 建议的最小闭合路径

1. README 保留“academic flow / GRT-estimated / non-tapeout”标签，不宣称 1 GHz 或 signoff closed。
2. 若目标是当前项目完整收尾，保留你提出的三刀裁剪是合理的；没有必要为了展示仓库继续烧数小时跑 no-ICG 极端腿。但应把残余时序和视图口径放到主结果表，而不是脚注。
3. 若目标升级为可签核项目，则必须补齐最终网表、每角 Liberty/RC、重新布线提取、完整 `check_timing`、LEC、RDC、LVS/EM 和 SRAM 宏模型；这是一条新的 signoff 工作流，不能靠现有报告补写完成。

## 证据文件

- `rtl_testbench_simulation.log`
- `reference_model_checks.log`
- `formal_control_bmc.log`
- `cdc_rdc_structural_report.md`
- `equivalence_partial_report.md`
- `yosys_elaboration.log`
- `yosys_synthesis.log`
- `verification_summary.json`
