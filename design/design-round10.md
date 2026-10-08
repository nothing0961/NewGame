# 设计备忘 · 第十轮：事件小玩法（2026-10-08）

> 会话决策记录。第三轮把事件页定为「容器＋可注入小玩法模块的宿主」（design-round3 §4），
> 第八轮实装 38 个事件时先落「三选一菜单」壳（design-round8 §4），真实小玩法列后设。
> 本轮把**全部 38 个事件**从三选一菜单升级为拖拽小玩法，交互原型收敛为 **4 个可复用模块**
> （择一／分拣／配平／揭示），结果词汇从「仅 hp」扩展为 **hp ＋下一战轻增益**。
> 用户口径（2026-10-08）：覆盖＝全部事件；素材＝事件专属道具牌；结果＝hp＋轻增益。

## 0. 决案（2026-10-08）

1. **覆盖＝全部 38 事件**，三选一菜单整体退役：事件节点的 `choices`/`feedback`/`effects`
   schema 删除，统一换为 `gameplay` 键
2. **素材＝事件专属道具牌**：运行时合成的 `CardData`（不入卡池／仓库／存档、不动玩家牌组），
   视觉复用卡框（118×171 四色框）；玩家卡组代价（出牌打伤害等）不做——open-decisions
   「得卡效果不可行」结论不变
3. **结果词汇 `{hp, block, draw}`**：`hp` 沿用（层内入场血修正 `pending_hp_delta`）；
   `block`＝下一场对局**开局格挡**；`draw`＝下一场**起手多抽**。缺键视为 0
4. **交互原型 4 模块**：pick 择一／sort 分拣／balance 配平／reveal 揭示——
   38 事件按 §2 表分配（pick 22 / sort 4 / balance 3 / reveal 9）
5. **全走拖拽**（与战斗一致）：道具牌拖进槽位／筐／秤盘／翻面，点击只保留最终确认按钮
6. **模块逻辑纯函数化**（`EventGames`，不碰 UI）——UI 只做交互与呈现，逻辑可单测
7. **轻增益消耗点＝下一场 story 战斗开局**；教学／练习／教程战不消耗；
   `reset_layer()`（死亡重掷）与 hp 修正同步清零
8. **轻增益累计上限**：`pending_block ≤ 3`、`pending_draw ≤ 2`（防一条路走满事件滚雪球）；
   单事件 draw 至多 1 处；数值待实测可调

## 1. 四模块规格

通用：事件页保留 标题＋场景读白；玩法区换为模块交互；结算后显示结果文本→ 完成按钮
（沿用旧节奏）。道具牌＝程序化合成（kind=UTILITY、无费用角标），拖拽载荷为模块自定义
字典（不复用战斗的 zone/index 载荷）。所有数值/文案为【测试内容】。

### 1.1 pick 择一（原三选一的升级壳）

- **交互**：2–5 张面朝上的道具牌一排；拖一张进「行动槽」（单槽、可再拖换）；「执行」结算
- **数据**：`{"module":"pick","hint":"…","cards":[{"name","sub","text","outcome":{…}}]}`
- **结算**：选定卡 outcome 入 RunState；显示该卡 `text`（原 feedback）
- **迁移规则**：原 `choices[i]`→卡 `sub`、`feedback[i]`→卡 `text`、`effects[i]`→`outcome`；
  `name` 取 choice 文案短名（实施时截取）

### 1.2 sort 分拣

- **交互**：3–6 张道具牌，全部拖进两筐之一（筐可有容量上限，拖超被拒）；放置完才可「收好」结算
- **数据**：`{"module":"sort","left_label","right_label","capacity","capacity_side",
  "settle":"…","cards":[{"name","sub","left":{…},"right":{…}}]}`
- **结算**：Σ 各卡所属侧 outcome；显示 `settle` 汇总读白＋自动结果行

### 1.3 balance 配平

- **交互**：3–5 张带数字道具牌拖上秤盘凑目标值（可拖回）；「称量」结算
- **数据**：`{"module":"balance","target":N,"settle":"…","cards":[{"name","sub","weight"}]}`
  （`bands` 可缺省，用默认分档）
- **结算**：`diff = |Σweight − target|`；默认分档：0→`{hp:+1}`／1→`{}`／≥2→`{hp:-1}`

### 1.4 reveal 揭示

- **交互**：3–5 张背面牌一排；拖出一张→翻面并**立即结算**该张（可随时「收手」停）；
  变体 **reveal+finish**：全翻完追加奖励并自动结算
- **数据**：`{"module":"reveal","stop_label":"…","cards":[{"name","sub","text","outcome"}],
  "finish":{"text","outcome"}}`（无 `finish` ＝普通揭示）
- **结算**：Σ 已翻卡 outcome（＋全翻 bonus）；逐卡 `text` 按翻序显示

## 2. 38 事件分配表

### L2 色欲（5）

| 事件 | 模块 | 内容要点 |
|---|---|---|
| 试衣镜 | pick | 迁移（原三选一 3 卡） |
| 糖果摊 | reveal | 甜糖{hp-1}／糖纸{hp+1}／罐底字条{block+1}／空玻璃纸{0} |
| 合唱席 | pick | 迁移 |
| 粉焰之墙 | reveal+全翻 | 温{0}／火舌{hp-1}／甜的挽留{0}；全翻→墙那头{block+1} |
| 献花台 | pick | 迁移 |

### L3 暴食（4）

| 事件 | 模块 | 内容要点 |
|---|---|---|
| 长桌宴席 | sort | 筐＝吃下／留下。热汤 吃{hp+1}留{0}；硬菜 吃{hp-1}留{0}；新米 吃{0}留{hp+1}；糖霜点心 吃{hp-1,draw+1}留{0} |
| 一碗汤 | pick | 迁移 |
| 果子树 | sort(摘侧容2) | 筐＝摘下来／留在树上。熟透 摘{hp+1}留{0}；半熟 摘{hp-1}留{hp+1}；青果 摘{hp-1}留{0}；树顶 摘{block+1}留{draw+1} |
| 后厨门 | pick | 迁移 |

### L4 贪婪（7）

| 事件 | 模块 | 内容要点 |
|---|---|---|
| 金山房 | sort(背走容2) | 筐＝背走／留在原地。金锭 背{hp-1}留{0}；碎银 背{0}留{0}；怀表 背{hp-1,draw+1}留{0}；鹅卵石 背{hp-1,block+1}留{0}；金像 背{hp-2}留{0} |
| 计数台 | pick | 迁移 |
| 抵押行 | pick | 迁移（含原「押上{-1,draw+1}」项） |
| 保险柜 | reveal | 一杯温水{hp+1}／金光{hp-1}／空柜{0}／暗格{draw+1} |
| 账房的灯 | pick | 迁移 |
| 朝下的石像 | pick | 迁移 |
| 天平房 | balance | 目标 6：金币1、账纸2、小石像3、金杯2、一捧灰1（默认分档） |

### L5 嫉妒（7）

| 事件 | 模块 | 内容要点 |
|---|---|---|
| 谢幕的舞台 | pick | 迁移 |
| 针线长廊 | sort(带走容1) | 筐＝带走／留下。银线 带{draw+1}留{0}；金线 带{block+1}留{0}；灰线 带{hp-1}留{0} |
| 重影卧室 | pick | 迁移 |
| 榜单 | pick | 迁移 |
| 望远镜 | reveal | 别人的笑{hp-1}／别人的位置{0}／树{0}／台阶{hp+1,draw+1} |
| 回声井 | reveal | 碎声{hp-1}／换腔调{0}／别人的名字{0}／越往下{0}／自己的声音{hp+1,draw+1} |
| 空椅子 | pick | 迁移 |

### L6 傲慢（8）

| 事件 | 模块 | 内容要点 |
|---|---|---|
| 最高处的房间 | reveal | 森林{hp+1}／粉雾{0}／坠落错觉{hp-1}／台阶{block+1} |
| 空王座 | pick | 迁移 |
| 聚光灯 | pick | 迁移 |
| 雕像广场 | pick | 迁移 |
| 坠落点 | reveal+全翻 | 很高{0}／一路烧下来{hp-1}／没有人接{hp-1}；全翻→松开手{hp+1,draw+1} |
| 负重阶梯 | balance | 目标 4：1／2／2／3（名暂拟） |
| 报幕台 | pick | 迁移 |
| 加冕台 | pick | 迁移 |

### L7 暴怒（7）

| 事件 | 模块 | 内容要点 |
|---|---|---|
| 烙印室 | pick | 迁移 |
| 黑烟走廊 | pick | 迁移 |
| 无人裁判的擂台 | pick | 迁移 |
| 碎片拼盘 | balance | 目标 5：1／2／2／3（名暂拟） |
| 沸水缸 | reveal+全翻 | 湿柴{0}／干柴{0}／火星柴{hp-1}；全翻→火熄{hp+1,block+1} |
| 揉皱的信 | pick | 迁移 |
| 先吼的谷 | reveal+全翻 | 你的声音{0}／别人的{hp-1}／更大的{hp-1}；全翻→最底：你的调子{hp+2,block+1} |

## 3. 数值口径

- hp：常规 −1；重扣 −2（金像）；回报 +1 常见、+2 仅先吼之谷全翻
- block：+1 常见；draw：+1，**每事件至多一处**（数据守护校验）
- 每事件必须存在**温和路径**（不净亏的走法）：pick＝某卡 hp≥0；sort＝存在整盘摆法总 hp≥0；
  balance＝存在可达档位 ≥0；reveal＝随时收手＝0 自动满足
- pick 迁移事件保持原 hp 效果不动（第八轮已定稿的口径），新内容（16 事件）承载轻增益

## 4. 轻增益接线

- **RunState**：新增 `pending_block`／`pending_draw`（默认 0）；`apply_outcome(outcome)`
  （hp→现 `apply_hp_delta`；block/draw 累加并按 §0-⑧ 上限 clamp）；`entry_block()`／
  `entry_draw()`；`consume_buffs()`（入战后清零）；`reset_layer()` 一并清零
- **main_flow**：story 战斗开局传 `run.entry_block()/entry_draw()` 并在开战后 `consume_buffs()`；
  教学／练习／教程战不传不消耗
- **battle_state.start_story(＋entry_block, ＋entry_draw)**：开局格挡在 `_start_player_turn()`
  **之后**应用（该函数会清零格挡）；起手＝HAND_SIZE＋entry_draw；战斗日志追加
  「备战：开局 +N 格挡、起手多抽 M 张」
- **存档**：`save_progress` 增 `pending_block`／`pending_draw`（缺省 0，VERSION 2 不升，
  兼容旧档）；使用点 `int()` 归一 JSON 往返
- **地图页**：有 buff 时显示备战线「备战：格挡+N 抽牌+M」（实现时读 map_page.gd 定位置）

## 5. 实现结构

- 新增 `scripts/data/event_games.gd`（`class_name EventGames`）：`validate()`／
  `resolve_pick`／`resolve_sort`／`resolve_balance`／`resolve_reveal_flip`／
  `resolve_reveal_finish`；outcome 归一过滤未知键并 int 化
- 新增 `scripts/ui/event_games/`：`event_game_base.gd`（结算区＋完成＋`settled(outcome)` 信号）、
  `pick_panel.gd`／`sort_panel.gd`／`balance_panel.gd`／`reveal_panel.gd`、
  `prop_card.gd`（卡框视觉复用＋自定义拖拽载荷）
- `event_page.gd` 宿主化：按 `gameplay.module` 实例化 panel；信号 `choice_chosen` →
  `game_resolved(outcome)`；保留 title/scene/完成节奏
- `layer_config.gd`：38 事件 schema 迁移；`main_flow.gd`：`_on_event_resolved(outcome)`
- 新 `class_name` → 先 `--import` 刷全局类缓存再跑测试（既有铁律）
- 槽位控件 `make_slot()` 的 PanelContainer 默认 STOP 会截断引擎拖放走链——已改 PASS
  （弃牌区/日志区/出牌区同型修复第四次复现；探针 `.tmp/probe_filters.gd` 实证各控件默认值）

## 6. 测试与验收

- **数据守护**：38 事件均有 `gameplay`、模块∈4、outcome 仅 hp/block/draw 且为 int、
  温和路径存在（§3）、单事件 draw ≤1
- **逻辑单测**：四模块 resolve 函数（含 clamp、默认分档、全翻 bonus、容量）
- **E2E（真实鼠标拖拽）**：四模块各一条完整流（拖→结算→完成）；reveal 中途收手；
  reveal 全翻自动结算
- **轻增益生命周期**：事件得 buff → story 开局生效（格挡数/起手张数/日志行）→ 战后清零；
  练习不消耗；reset_layer 清零
- **存档往返**：pending_block/draw 持久化；旧档缺键 → 0
- **既有用例更新**：test_event_page／test_event_effect_flow／test_layer_pools_complete／
  `_pool_event` 夹具
- **实测（2026-10-08 当日完成）**：1793 → **1848 项全过**（69 用例组，3 连跑稳定）；
  新增 4 组＝事件逻辑单测／数据守护＋四模块真实鼠标拖拽 E2E／轻增益生命周期＋存档加键往返
- 截图走查 10 张核对通过（地图备战线／四模块初始与结算态／轻增益入战日志与格挡上手）

## 7. 后设（本轮不做）

- 得卡效果／玩家卡组代价：不做（结论保持）
- 道具牌美术（现为卡框复用的程序化样式）＝美术轮
- 全部新文案（道具名/读白/提示）＝【测试内容】待定稿轮
- 容量／上限／分档数值待用户实测复核
- 罪卡专轮、第 8 层专轮等既有后设不变
