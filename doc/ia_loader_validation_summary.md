# ia_loader 验证总结（v2.1）

## 1. 验证综合表

| 项目 | 内容 | 结论 |
|---|---|---|
| 验证对象 | `ia_loader`（`ia_loader_ctrl` / `tile_loader` / `ia_loader_cache_mgr` / top TB） | 覆盖核心链路 |
| 验证方法 | 定向用例 + 全量回归（`run_all`）+ 随机回归（`run_random`）+ Scoreboard 比对 | 方法完整 |
| 关键语义 | `ia_sending_done` 仅在 **L1 组完成** 拉高一次 | 已验证 |
| 关键路径 | L1 组连续对角化输出、tile 间零间隔、prefetch overlap | 已验证 |
| 数据格式特性 | `use_16bits` 作为验证 feature，覆盖 s16/s8 两条路径 | 已验证 |
| 校验粒度 | 由“单 tile 校验”升级为“整 L1 组校验” | 与 v2.1 一致 |
| 回归稳定性 | 预定义用例全通过，关键场景通过，随机回归记录通过 | 稳定 |

---

## 2. 测试用例总结（Predefined 18）

来源：`test/ia_loader/gen_test_data.py` 的 `PREDEFINED_CASES`

| Case | 参数 (K,N,M,R,W,U16) | 覆盖点 |
|---|---|---|
| `exact_1x1` | 8,8,8,1,1,1 | 最小单 tile 基线 |
| `exact_2x2` | 16,16,16,2,2,1 | 2x2 对齐；L1 组连续输出关键场景 |
| `col_rem` | 16,10,16,2,2,1 | N 非整除 SIZE（列余量） |
| `row_rem` | 10,16,16,2,2,1 | K 非整除 SIZE（行余量） |
| `both_rem` | 10,10,10,2,2,1 | 行列双余量 |
| `single_col` | 16,5,8,2,1,1 | N<SIZE，窄列 tile |
| `single_row` | 5,16,16,1,2,1 | K<SIZE，短行 tile |
| `large_r` | 32,16,16,4,2,1 | R=4，深 L1 组 |
| `large_w` | 16,16,32,2,4,1 | W=4，强复用 |
| `r1_w1` | 24,24,24,1,1,1 | 无复用路径 |
| `wide` | 8,32,16,1,2,1 | 宽矩阵 |
| `tall` | 32,8,16,4,1,1 | 高矩阵 |
| `max_reuse` | 32,32,32,4,4,1 | 最大复用（R/W 都大） |
| `tiny` | 1,1,1,1,1,1 | 极小矩阵边界 |
| `one_row` | 1,16,8,1,1,1 | 单行边界 |
| `one_col` | 16,1,8,2,1,1 | 单列边界 |
| `exact_2x2_s8` | 16,16,16,2,2,0 | s8 数据路径；符号扩展与对角化叠加校验 |
| `col_rem_s8` | 16,10,16,2,2,0 | s8 + 列余量边界联合校验 |

---

## 2.5. 随机测试用例（Random Cases）

| 参数 | 范围 | 覆盖说明 |
|---|---|---|
| K（行数） | 1～48（均匀随机） | 从极小到接近整数倍上界的行数覆盖 |
| N（列数） | 1～48（均匀随机） | 从极小到接近整数倍上界的列数覆盖 |
| M（输出列数） | 1～48（均匀随机） | 输出维度完整覆盖 |
| R（L1行分块） | {1, 2, 3, 4} | 浅/中/深L1组覆盖 |
| W（权重复用） | {1, 2, 3, 4} | 无复用/中等/强复用覆盖 |
| use_16bits | {0, 1} | s8/s16 数据路径双覆盖 |
| SRAM约束 | BASE_ADDR + K×row_stride ≤ SRAM_DEPTH×4 | 自动调整K/N以确保合法性 |

**回归记录**（示例）：
- `make run_random SEED=42 COUNT=20` → **20/20 PASS**
- 参数空间：6维（K/N/M/R/W/u16），总覆盖≈3M+ 个合法组合
- 重点覆盖：L1组深度、复用强度、数据位宽、边界条件随机组合

---

## 3. Feature List（验证点）

1. ICB 加载链路：`icb_cmd`/`icb_rsp` 握手、burst 解包、写 RAM 正确性。
2. Cache 状态表：`blk_valid`/`blk_busy` 的置位、转移、释放。
3. L1 组触发：`ia_data_valid` 与 `send_ia_trigger` 协同。
4. 对角化输出：col0-leader + shift-register，列间延时关系正确。
5. 完成信号：`cache_tile_done`（每 tile）与 `ia_sending_done`（每 L1 组）语义正确。
6. 循环计数器：`ia_idx`/`w_cnt`/`l1_idx`/`l2_idx` 推进与回绕。
7. overlap/prefetch：S_SEND 期间并行加载、L1 组切换路径（含 skip `S_LOAD`）。
8. 边界参数：`R_act`、`W_act`、最后行/列 tile、极小矩阵。
9. 数据位宽：`use_16bits=1/0` 双路径（s16/s8）及 s8 符号扩展一致性。
10. 零点链路：`TC_LHS_ZP -> lhs_zp -> expected` 端到端加偏置语义。

---

## 4. 验证思路

1. 先校准语义：按 v2.1 将 `ia_sending_done` 定义为 L1 组级完成。
2. 升级 TB：采集整 L1 组输出，逆对角化后再与 golden 比对。
3. 优先打关键路径：`exact_2x2`、`large_r`、`large_w`、`max_reuse`、`exact_2x2_s8`。
4. 全量回归：18 个预定义 case 做功能覆盖（含 2 个 s8 case）。
5. 随机回归：随机 K/N/M/R/W 检查稳定性与鲁棒性。

---

## 5. 验证结果

| 项目 | 结果 |
|---|---|
| `make run_all` | **18/18 PASS** |
| `make run CASE=exact_2x2` | PASS（关键连续输出场景） |
| `make run CASE=exact_2x2_s8` | PASS（s8 位宽路径） |
| `make run CASE=col_rem_s8` | PASS（s8 + 列余量） |
| `make run_random SEED=42 COUNT=20` | **20/20 PASS**（历史回归记录） |
| Scoreboard | 检查项全通过，0 error（L1 组级比对 + s8 符号扩展修正） |

结论：v2.1 在连续输出、done 语义、overlap/prefetch 与边界场景上均通过验证，可用于后续集成。

---

## 6. 复现命令

```bash
cd test/ia_loader
make run CASE=exact_2x2
make run CASE=exact_2x2_s8
make run CASE=col_rem_s8
make run_all
make run_random SEED=42 COUNT=20
# 可强制覆盖位宽模式（0=s8, 1=s16）
python3 gen_test_data.py --all --use_16bits 0 --out_dir out
```
