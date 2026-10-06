# 设计备忘 · 第八轮：第 2–7 层内容实装（2026-10-06）

> 会话决策记录。本轮把第七轮名录（`design-round7.md`）落成可玩内容：**按层内容池＋专属敌牌组＋
> 小怪/层主数值＋事件选项轻量效果＋罪卡先行版**。第 8 层（同位体终局）留待专轮——第 7 层通关后
> 停在「待续」＝本段内容边界。层内玩法框架（`design-round4.md` §4 冻结）与战斗基础规则不变。

## 0. 决案（计划批准 2026-10-06）

1. **范围＝第 2–7 层**；第 8 层另设专轮（`generate_route(8)` 返回空、`has_content(8)=false`、通关 L7 走既有 `is_demo_end` 待续分支）
2. **罪卡＝先行版·各具特色**：每层一张简单独特罪卡（沿用既有机制词汇），标注「**待罪卡专轮替换**」（已登记 open-decisions）
3. **事件选项＝带轻量效果**（负伤/疗愈）：本轮词汇仅 `{"hp": ±n}`；「得卡」效果已论证不可行（见 §5）
4. **数值＝温和爬升**：小怪约 16→36、层主约 24→44、敌牌伤害 1→3 小步
5. **恶魔名贯穿**（第七轮决案 2）：L2–7 净化后同行层主用恶魔名；L1 双名制不动

## 1. 按层内容（名录 → 实装）

| 层 | 小怪（HP 递增） | 事件（池） | 层主（HP） | 敌牌组（8 张） | 罪卡 |
|---|---|---|---|---|---|
| L2 色欲 | 粉雾歌者16 / 糖丝傀儡18 / 镜前舞者20 / 缠丝泡影22 | 试衣镜 / 糖果摊 / 合唱席 / 粉焰之墙 / 献花台 | 阿斯莫德 24 | 8×enemy_strike | lust 既有 |
| L3 暴食 | 空胃食客18 / 餐铃偶20 / 匙叉傀儡22 / 驮汤行者24 / 残羹聚合26 | 长桌宴席 / 一碗汤 / 果子树 / 后厨门 | 别西卜 28 | 7×strike＋1×gnaw(2) | gluttony 新 |
| L4 贪婪 | 守财偶20 / 金币堆22 / 账簿鬼24 / 上锁者26 / 拾遗者28 | 金山房 / 计数台 / 抵押行 / 保险柜 / 账房的灯 / 朝下的石像 / 天平房 | 玛门 32 | 6×strike＋2×gold_smash(2) | greed 新 |
| L5 嫉妒 | 效颦影22 / 镜中来客24 / 低语复读26 / 缝目者28 / 替补之影30 | 谢幕的舞台 / 针线长廊 / 重影卧室 / 榜单 / 望远镜 / 回声井 / 空椅子 | 利维坦 36 | 6×strike＋2×mirror_cut(2) | envy 新 |
| L6 傲慢 | 高塔守望24 / 折光使25 / 台阶卫27 / 背石傀28 / 晨星残影30 / 俯瞰群31 / 灯影卫32 | 最高处的房间 / 空王座 / 聚光灯 / 雕像广场 / 坠落点 / 负重阶梯 / 报幕台 / 加冕台 | 路西法 40 | 6×strike＋1×piercing_light(2)＋1×falling_debris(3) | pride 新 |
| L7 暴怒 | 余烬行者26 / 怒号27 / 焚印傀儡29 / 烟幕行者30 / 钟摆32 / 引线鼠33 / 攥拳偶35 / 闷雷36 | 烙印室 / 黑烟走廊 / 无人裁判的擂台 / 碎片拼盘 / 沸水缸 / 揉皱的信 / 先吼的谷 | 萨麦尔 44 | 5×strike＋2×ember_lash(2)＋1×flame_burst(3) | anger 新 |

- **池容量＝该层单图最大需求**（(最大列数−1)×3）：L2＝4战＋5事＝9 · L3＝5＋4＝9 · L4＝5＋7＝12 · L5＝5＋7＝12 · L6＝7＋8＝15 · L7＝8＋7＝15（容量恰好打平，入测试守护）
- **L2 占位替换**：污染体→粉雾歌者、残响回廊→糖丝傀儡、糖霜傀儡→镜前舞者、雾中合唱→缠丝泡影；粉雾→试衣镜、镜阶→糖果摊、烛台走廊→合唱席、糖罐→粉焰之墙、低语信箱→献花台
- 各层事件三键（scene/choices/feedback）＋effects 逐条新写，贴合层意象与节奏句；层主三键（sin_card/strip_lines/purify_lines）必填（见 §6）
- L7 过渡读白兼待续钩子（萨麦尔：「上面那位……见了你就知道了。」）
- 事件关小玩法（「玩法型事件」真实小玩法）仍待专轮——本轮事件＝三选一＋即读反馈

### 实现（layer_config.gd 重构）

- 常量：`LAYER2..LAYER7` 各四常量（BATTLES/EVENTS/BOSS/TRANSITION）＋按层字典 `LAYER_BATTLES/LAYER_EVENTS/LAYER_BOSSES/LAYER_TRANSITIONS`（保留 LAYER2_* 常量名，测试引用多）
- `LAST_PLAYABLE_LAYER := 7`（原 2）；`has_content(layer) = layer == TUTORIAL_LAYER or layer <= 7`
- `generate_route` 按层取池＋抽 `_build_route(pool, bounds, rng)` 辅助；`generate_route(8)` 返回 `[]`
- `_boss_node` / `transition_lines` 改查按层字典；L2–7 各 3 行过渡读白（同行层主性格句＋下一层钩子）

## 2. 数值

### 敌牌组（小怪与层主共用；纯数据 `stage.enemy_deck`，零引擎改动）

- 出牌机制：敌人每回合从手牌随机打 `0..手牌数` 张（打出的牌即攻击）；稳态手牌 ≈6 → 期望出牌 h/2 ≈ 3 张
- 均伤 a（每张期望伤）与期望伤/轮：L2 **1.0**（3.0）· L3 **1.125**（3.4）· L4 **1.25**（3.75）· L5 **1.25** · L6 **1.375**（4.1）· L7 **1.5**（4.5）
- 爆发轮上限 12（整组倾泻）≤ 满血 10＋格挡预算（防御牌 2–3 格挡/张）——已按出牌机制核对
- 7 张新敌牌（.tres，单一 `deal_damage`，抄 snail_bite 格式）：

| id | 名 | 费 | 伤 |
|---|---|---|---|
| gnaw | 啃咬 | 3 | 2 |
| gold_smash | 金锭砸落 | 4 | 2 |
| mirror_cut | 镜面切割 | 5 | 2 |
| piercing_light | 刺目光束 | 6 | 2 |
| falling_debris | 坠落的残石 | 6 | 3 |
| ember_lash | 余烬之鞭 | 7 | 2 |
| flame_burst | 烈焰炸开 | 7 | 3 |

- **调参杠杆**（若实测偏难）：换回低伤牌 / 层主 HP−4 / 全场 a−0.125

## 3. 层内续航（入场 HP 修正）

- `RunState.pending_hp_delta`（clamp **[−9, 0]**）：事件效果即时累积（掉血为负、回血抵消至多 0）
- `entry_hp() = PLAYER_MAX_HP(10) + pending`；入战 HUD 显示修正后值（「你：9 / 10」）
- 清零时机：层开始（`complete_layer` 内 `reset_layer`）/ 死亡重掷 / 层完成
- 接线链：`event_page.choice_chosen` → `main_flow._on_event_choice`（`int()` 兜 JSON 往返的 float）→ `run.apply_hp_delta` → 入战 `_start_battle(..., run.entry_hp())` → `battle_screen.configure` → `battle_state.start_story(deck, stage, entry_hp)`
- 存档：`save_progress` 加 `pending_hp_delta` 键；缺省 0（老档兼容，VERSION 保持 2）

## 4. 事件效果

- 38 事件（L2 5 / L3 4 / L4 7 / L5 7 / L6 8 / L7 7）× 3 选项：`effects` 与 `choices` 下标对齐；词汇仅 `hp`（±）
- 规则：每事件 **≥1 个无代价项**（`{}` 或 hp>0）；`+1`＝疗愈/被善待、`−1`＝代价、`−2` 仅 L5 回声井 / L6 坠落点 / L7 烙印室 各 1
- 计划偏差 1 处：原计划「每事件 ≥1 个 `{}`」；L7 烙印室无 `{}` 但第三项 hp+1 属无代价项——放宽为「`{}` 或 hp>0」（保留数据）
- `event_page`：删「—— 玩法区（占位）——」hint Label；加 `signal choice_chosen(index)`（首次选择时 emit）

## 5. 罪卡先行版（待罪卡专轮替换）

| 罪卡 | 层 | 效果（cost 6 / permanent） | 任务计数（次攻击） |
|---|---|---|---|
| 暴食 gluttony | L3 | 伤 4＋回 4 | 3 |
| 贪婪 greed | L4 | 伤 4＋抽 2 | 3 |
| 嫉妒 envy | L5 | 伤 3＋压制敌方攻击 1 回合 | 2 |
| 傲慢 pride | L6 | 伤 8 | 3 |
| 暴怒 anger | L7 | 伤 7＋格挡 3 | 4 |

- L2 沿用既有色欲（lust，伤 2＋抽 2，计数 2）；`SIN_TASK_CONFIG` 补 5 条占位
- 效果设计**避开** `buff_attack_turn`/`gain_cost`——其日志文案为弃牌措辞，与罪卡「打出」场景不符
- id 冲突已核（`greed` vs `greed_shot` 无关）
- **「得卡」不可行结论（存档）**：`CardPool.owned` 是集合语义＋初始 20 张全拥有——事件「获得某张卡」无感知收益，本轮不做；如强需须另设计「可感知」的获取语义

## 6. STRIP 死锁修复（本轮最高风险项）

- **根因**：原 `_boss_node` 对 layer≥3 返回无 `sin_card`/`strip_lines`/`purify_lines` 的骨架 → 层主战胜后 `absorb_sin()` 前置条件不满足（battle_state.gd）→ **STRIP 阶段卡死**
- **修复**：L3–7 每层层主三键必填；L2 保留既有文案
- **守护**：`test_layer_bosses_complete` 逐层校验（sin_card 对应 / strip ≥3 行 / purify ≥4 行——L2 保留既有 3 行，放宽为 3）
- **流程测试**：`test_boss_strip_flow_layer3` 逐层打 L3–7 层主全链路（胜→STRIP→收下→DEBRIEF→ENDED）

## 7. 测试与验收

- 1349 → **1786 项全过**（3 连跑稳定）
- 夹具换新名录；约 30 处名称/血量字面量同步（污染体→粉雾歌者等）；新增 7 用例组：
  `test_layer_pools_complete`（池容量＋字段＋敌牌组 8 张可载入＋效果词汇）／`test_layer_bosses_complete`／`test_sin_cards_data`／`test_last_playable_boundary`／`test_entry_hp_modifier`／`test_boss_strip_flow_layer3`／`test_event_effect_flow`（真实流程链：事件结算→带伤入战 HUD）
- 走查截图 6 张核对通过：地图 L7 四态＋长名录节点（168px 无溢出）／L8 边界（1–7 已净化＋8 待续）／事件页（无占位提示＋反馈）／带伤入战 HUD「你：8 / 10」／L3 STRIP 覆盖层（拿起「暴食」）／L2 上行过渡

## 8. 后设（本轮明确不做）

- **第 8 层（同位体终局）＝专轮**：名录/终局机制/美术留待；游戏侧停在「待续」边界
- **罪卡专轮**：先行版数值与文案届时整体复核替换
- 事件关小玩法（各层「玩法型事件」真实小玩法）
- 事件「得卡」类效果（不可行结论已存档）
- 地图节点宽度（168px 长名录）——走查确认无溢出，本轮不动
- 各层正式美术（敌人立绘/地图美术）＝美术轮
- 数值实测复核：期望伤/轮 3.0→4.5 的实战体感（方差风险）待实测
