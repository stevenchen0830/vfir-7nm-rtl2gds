# SRAM / FIR 时序交接表（待提供真实模型）

当前不是已批准的物理约束。2026-09-11 已收到一份接口现状审计表，
它明确把各 PVT 的 tCQ、setup/hold 及 SRAM 时钟到达参数标为 N/A。
这份材料确认了预算缺口，并没有补齐真实宏的表征数据。
不会根据期望 slack 反推参数，也不会将历史 10/100 ps tCQ 假设称为测量值。

审计表来源 SHA256：`6b51f0867ca78235e77a6542a26b86bc3a7eda2a84b927480be595b0eb5e3e6b`。
原文件包含非公开课题引用，故不复制到公共仓库，只记录脱敏结论：

- 一个时钟源/同频同相不代表 SRAM 引脚与 FIR 触发器的物理插入延迟相同。
  当前没有 SRAM 宏放置，不能声称它们的实际时钟分支已验证。
- 固定的 800 ps 若高估实际 SRAM launch insertion，会使输入 hold 偏乐观，
  不能称为 hold 的保守安全高估；共享树并不能兜底任意差分偏斜。
- 30 ps uncertainty 仍是设计假设，没有时钟表征、变化/相关性预算就不能以
  “惯例”升级成签核依据。旧 150 ps 的悲观性也不能证明 30 ps 必然正确。
- 上式必须包含 FIR 引脚至 D 的内部最短路径；不能把仅端口侧 arrival
  直接与完整 flop required time 比较。最终用 full-clock path 逐项核对。
- 要逐场景匹配 min/max 与相关 clock arrivals；不能机械地把 FF tCQmin
  与任意 SS clock/check 拼接，也不能无条件把输出 `-min` 改成 `-t_hold`。

## 所需材料

| 类别 | 必需内容 |
| --- | --- |
| Macro 身份 | 名称、depth×width、端口数、读写模式、读延迟、CE/WE 极性、dout hold 行为 |
| 逻辑/物理视图 | 每个 PVT 的 Liberty；匹配 LEF/abstract；可用时 GDS/Verilog/SDF；文件 SHA256 |
| Read data | 各角、相应负载/slew 下 tCQ min/max；禁读时是否保持；是否带输出寄存器 |
| Commands/write | addr/CE/WE/wdata 对 SRAM clock 的 setup/hold，逐端口或明确分组 |
| Clock | 公共 source 定义、两边 source/network insertion min/max、相关性及 uncertainty 分解 |
| Interconnect | 宏与 FIR 边界的连线 min/max；包络包含哪些段，避免 SPEF 重复计算 |
| Reset | 同步释放器位置、接口何时允许 valid、reset recovery/removal 验证责任 |
| 许可 | 是否允许公开再分发；商业/学校受限材料默认不上传 GitHub |

不同工艺的 SRAM 不能直接当作 ASAP7 macro 的物理/时序模型。只得到数据手册时，
可以建立有来源的 block 接口模型，但仍不能称为宏集成签核。

## 推导方法而非填数方法

选取一个共同参考时钟，在该参考下展开实际的到达时间：

```text
SRAM launch clock Ls -> tCQ -> 外部数据连线 -> FIR input -> 内部数据连线 -> D
FIR capture clock Lf --------------------------------------------------> CK
```

同沿 hold 要求（暂省略工具的 CRPR 细节）：

`Ls_min + tCQ_min + data_external_min + data_internal_min
 >= Lf_max + t_hold + U_hold`。

setup 用相邻有效边沿：

`Ls_max + tCQ_max + data_external_max + data_internal_max
 <= T + Lf_min - t_setup - U_setup`。

相关 launch/capture 的极值应遵循实际相关性/OCV，而不是任意组合；propagated
clock 与 uncertainty 不能重复计算同一物理 skew。由虚拟时钟包含的部分决定
input delay 还要表达什么，不能把完整 arrival 和 tCQ 都叠加一次。

输出到 SRAM 同理，先确定接收端 required time，再映射到 `set_output_delay`。
只有在同参考、无额外 latency/skew 项的简单模型中，`-min=-t_hold` 才能直接用。
当前 `+500 ps` 必须与虚拟时钟 800 ps 一起审计，不能简单改符号称为修复。

## 新候选的执行门槛

1. 校验模型 identity、PVT、单位、depth/width、协议与许可证；归档来源和 hash。
2. 按 core / stream / SRAM path group 画时钟关系并批准 min/max 预算。
3. 单独保存新 SDC 和配置，保持 1 ns 产品目标；保留历史 SDC 不覆盖。
4. RTL 回归 + 综合 + placement/CTS 阶段性检查，诊断 setup 与 capture skew。
5. 修复后 DRT → RCX → 全 PVT min/max/DRV；有真实 RCmin/max 规则时扩展矩阵。
6. 没有实际模型覆盖的视图标 UNKNOWN/BLOCKED，绝不由估算或约束放宽推定通过。
