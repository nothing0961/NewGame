# 设计备忘 · 第十五轮：第三幕开头幕间实装——入队／心境问答／身世闪回／黄昏草地／城堡一夜（2026-10-12）

> 会话决策记录。第十二～十四轮（design-round12/13/14.md）已实装第二幕全链条（入场 A/B、前演出、
> 三阶段机制战、OUTRO_A/B 收尾链），但第二幕收尾之后是直接进过渡页——第三幕开头尚缺。小组交付
> 《第三幕 幕间.doc》（2026-10-12），＝第三幕开场「幕间」段：莉维娅重新入队→心境问答→身世闪回→
> 黄昏草地「好朋友」→城堡一夜→翌日晨→阳台门入 L3。本轮按既有逐拍演出管线把幕间做成 22 拍表＋
> 闪回暗色样式，并以**方案 B** 接入层尾收尾链（崩档重进只补幕间、不重打层主）。

## 0. 口径决案（2026-10-12 用户口径，三项）

1. **闪回＝合拍演出＋暗色闪回样式**：身世段（12 拍）不拆独立页面／不配底图，作为 beat 表内
   `"flashback": true` 拍——无底图／立绘／说话人，压暗底色＋冷紫调制（`FLASHBACK_TINT`）
2. **幕间美术＝2 张**：`bg_castle_home`（城堡内景·夜，三室一厅现代家）＋`bg_grass_dusk`
   （黄昏草地）；其余段复用既有底图（拍 0–2 用 `bg_castle`）；闪回拍零素材
3. **门控＝方案 B `act3_interlude_done`**：层尾 OUTRO_B 末拍**先**统一落账（收罪卡＋同行）＋
   结层＋存盘（flag 未置）→ 幕间 22 拍 → 末拍置 flag＋存盘 → 既有过渡页 → L3 地图；
   幕间途中退出／崩溃重进＝只补幕间（不重打层主战）

## 1. 演出结构（`StoryBeats.ACT3_INTERLUDE`，22 拍）

| 拍 | 段 | 底图／立绘 | 内容 |
|---|---|---|---|
| 0–2 | 入队开场·心境问答 | bg_castle／livia | 慌忙起身道谢→「请允许我重新加入你的队伍，成为你的向导」（高冷形象破裂、软软糯糯）→「继续当我的向导吧？莉维娅小姐」→答疑邀请→贝嘉提问（各层场地为何不同）→**心境具象化**（城堡/小镇＝美梦；玩具/小裙子＝曾渴望但从未有的事物；笔筒/钢笔＝恐惧）＋家教严·优绩主义自述 |
| 3–14 | **身世闪回（12 拍）** | 无（暗底＋FLASHBACK_TINT） | 七岁教室背《诗经》→同学们聊娃娃/魔法少女动画（『……好吵』）→车上训话（生日要娃娃被拒——「动画是教坏小朋友的东西」）→训斥余波（回家热饭味如嚼蜡）→偷看动画（「奇迹与魔法，友情与战斗！」初次向往）→生日（妈妈带小蛋糕、要到钱）→周末买玩偶藏书柜（纸条「妈妈爱你，莉维娅。」）→骗过妈妈→**玩偶被丢**（「那个娃娃已经被我丢了。」）→「做错事了就不许哭！」＋同学指点孤立（「她变得更听妈妈的话。」）→初一生日要补习班→母亲病倒·被赶回学校（「她只记得，妈妈后来死了。」）→被「爸爸」带走·约束末拍（「但她早已被死去的妈妈给永远约束住了。」「包括她自己。」） |
| 15–17 | 黄昏草地 | bg_grass_dusk／livia→无 | 「奇迹涌现」收束自述（美梦竟以魔法的形式呈现——虽是被污染的欲望）→贝嘉「请抬起头。」→朋友宣言（「算好朋友？」「好朋友！」×3——菲戈蕾跟喊）→拥抱·「咸咸的！」→结界昼夜交替→「我们先去休息吧？」 |
| 18–19 | 城堡一夜 | bg_castle_home／livia→figelie | 现代风格三室一厅（＋浴室/卫生间/厨房）→挑房间→「终于能亲手触碰到你了」打理戏→半夜钻被窝→翌日晨菲戈蕾**刷新在被窝里**（(ᗜ ᴗ ᗜ)）→房门「——贝嘉，咦？？？」 |
| 20 | 镜前 | bg_castle_home／figelie | 打理乱糟糟的头发·与菲戈蕾互瞪（「一点不吃亏」）→抓住打理·鸡飞狗跳→「因为有了魔力就不需要吃饭了」 |
| 21 | 阳台门 | bg_castle_home／livia | 「打开客厅的阳台门就到了。」→迈入阳台门（茫茫白光）——button＝「**进入第三层**」 |

- 合拍原则：多段原文并一拍（不删字）；段落拆分以「页面不拥挤」为准（ScrollContainer 兜底）
- 语言记号沿用原文形态：叙述直引「」／心里话『』／闪回叙述【】；闪回拍内对白仍用「」
- 拍 17 起立绘撤下（叙述为主）；拍 19–20 立绘切菲戈蕾（早晨戏主角）

## 2. 闪回样式（`prologue_page.gd` 新键 `flashback`）

- `FLASHBACK_TINT := Color(0.44, 0.42, 0.56)`（冷紫灰调制）
- `flashback: true` 拍：`bg` 全空（不放底图）→ `_bg_fallback` 仅色块
  （`bg_color = Color(0.10, 0.09, 0.13)` 深暗紫 → 应用时 `darkened(0.3)`）
- `_bg_rect`／`_portrait.modulate = FLASHBACK_TINT`（本表闪回拍均 `portrait: ""`，双保险）；
  非闪回拍 modulate 复位 `Color.WHITE`
- 闪回拍强制 `bg`／`portrait`／`speaker` 全空（测试守卫，见 §6）
- 进出边界：拍 2（正常样式）→ 拍 3 起闪回；拍 14（约束末拍）→ 拍 15 回黄昏草地（正常样式）——
  两处边界均有测试覆盖
- 复用性：后续层如需闪回可直接借 `flashback` 键（渲染零新增：仅调制既有节点）

## 3. 门控＝方案 B（`main_flow.gd` 接线与崩档语义）

```
L2 层主战胜 → OUTRO_A（「动手」）→ OUTRO_B（「继续」）
  └─ OUTRO_B 末拍 _on_story_outro_finished（重写）：
       收罪卡 lust ＋ 莉维娅同行 ＋ complete_layer()（layer 2→3）＋ save（flag 未置）
       ↓ stage.interlude == "act3" 命中且路线已走完
       进幕间演出 _show_performance(ACT3_INTERLUDE, _on_story_interlude_finished)
       （幕间途中退出/崩溃 → 重进 _ready 门控补看）
  └─ 幕间末拍 _on_story_interlude_finished(completed_layer)：
       act3_interlude_done = true ＋ save → _show_transition(第 2 层读白) → L3 地图
```

- **崩档语义（方案 B）**：幕间途中崩溃重进＝**只补幕间不重打层主**（落账已先行、flag 未置）；
  flag 仅在幕间末拍置位
- **补看门控（`_ready`）**：`not act3_interlude_done and current_layer == TUTORIAL_LAYER + 2
  and column_index == 0`——仅第三层初列未开走；更深／中段老档不补（防错位，同 L2 入场模式）
- 补看路径 `_show_act3_interlude()`：bind `run.current_layer - 1`（＝2）→ 过渡页读白为第 2 层
- 存档键 `act3_interlude_done`（旧档缺键＝false＝补看一次）；`VERSION` 不变（向后兼容）
- 派发表：`StoryBeats.INTERLUDE_TABLES = {"act3": ACT3_INTERLUDE}`；stage 节点键
  `LAYER2_BOSS["interlude"] = "act3"`；未知 id／空表 → `interlude_beats()` 返回空 →
  调用方回退直接进过渡页（与 intro/outro 同模式）
- 零改动路径：L3–7 层主（stage 无 interlude 键）、教学／练习／遭遇战／教程战全无涉；
  OUTRO_A/B 链（round13）与三阶段机制战（round14）零改动

## 4. 文本归一化（原文笔误订正清单）

| 原文 | 订正 | 说明 |
|---|---|---|
| 妈妈**地**厨艺很好 | 妈妈**的**厨艺很好 | 的地得 |
| 打算叫**莉维娅**起床 | 打算叫**贝嘉**起床 | 人物写错——她来叫的是贝嘉 |
| 豆**滴**大的眼泪 | 豆大的眼泪 | 语序笔误 |
| **她的自认为的**高冷形象 | 她自认为的高冷形象 | 多字 |
| 很难再在贝嘉面前**再**恢复 | 很难再在贝嘉面前恢复 | 重复「再」 |
| 于是　，本来就没有朋友 | 于是，本来就没有朋友 | 标点前空格 |

- 引号统一：`‘…’`（单引号）→『』（心里话）；径直引述统一「」；省略号统一 `.....`／`....`
  → `……`；成句标点微调（逗号→句号/破折号，如「优绩主义——我想要做的事」；补句号若干）
- 其余全文忠实转录（world.md §2026-10-12 续录段保留原文笔误——归一化对照即本表）

## 5. 实现接线（关键文件）

- `scripts/data/story_beats.gd`：`ACT3_INTERLUDE` 22 拍表（拍 0–2／3–14 闪回 12 拍／15–17／18–21）
  ＋`INTERLUDE_TABLES`＋`interlude_beats(id)`
- `scripts/ui/prologue_page.gd`：`FLASHBACK_TINT` 常量；beat 键 `flashback` 消费
  （`_bg_fallback.color = bg_color.darkened(0.3)`；`_bg_rect`/`_portrait.modulate = FLASHBACK_TINT`；
  非闪回拍复位 WHITE）
- `scripts/ui/main_flow.gd`：`_ready` 补看门控；`_on_story_outro_finished` 重写（先落账结层存盘、
  interlude 键命中才进幕间——空表/未走完回退 `_finish_story_stage`）；`_on_story_interlude_finished`
  （置 flag＋存盘＋过渡页）；`_show_act3_interlude()`（补看，bind `current_layer - 1`）
- `scripts/data/run_state.gd`：`act3_interlude_done` 字段（缺省 false）
- `scripts/data/save_game.gd`：`act3_interlude_done` 存档键（缺键默认 false，VERSION 不变）
- `scripts/data/layer_config.gd`：`LAYER2_BOSS["interlude"] = "act3"`（intro/outro 键保留）

## 6. 测试（`tests/run_tutorial_test.gd`）

- 新用例 `test_story_beats_l3_interlude`：表体（22 拍／每拍字段完整）＋闪回计数 12＋闪回拍
  bg/portrait/speaker 全空守卫＋边界拍（2/3、14/15）＋非闪回拍底图文件在场＋三段锚点
  （拍 2＝bg_castle／15＝bg_grass_dusk／18＝bg_castle_home）＋关键台词抽查＋笔误守卫
  （妈妈的厨艺／打算叫贝嘉起床／豆大的眼泪）＋末拍 button「进入第三层」＋派发表
  （"act3" 命中／未知空）＋`LAYER2_BOSS.interlude == "act3"`＋**页面级样式**（拍 0 正常
  modulate==WHITE → 拍 3 起 modulate==FLASHBACK_TINT＋底色 darken(0.3) → 拍 15 复位 WHITE）
- 新用例 `test_interlude_gating`：独立存档文件三场景——①仅缺幕间标记（层 3 初列）→ 启动直入
  补看 → 21 推 → 末推置 flag＋存盘＋过渡页；②重进直达地图（flag 已还原）；③老档幕间中段
  （column_index 1）→ 不补看、不置位
- 改造 `test_main_flow_layer2`：收尾末拍断言重写（未置 flag 直入幕间、层已结、罪卡/同行已落账；
  22 拍后置 flag＋过渡页）
- `test_save_roundtrip`：`act3_interlude_done` 往返＋旧档缺键默认 false
- **测试 2085 → 2145 项全过（3 连跑）**

## 7. 走查截图（`.tmp/shot_round15.gd`，14 张全过目）

1. 入队开场（城堡外，莉维娅重新入队）
2. 心境问答（场景＝被侵蚀心境的具象化）
3. 闪回首拍·教室诗经（暗色闪回样式）
4. 闪回·娃娃对话（『……好吵』）
5. 闪回·玩偶被丢（「那个娃娃已经被我丢了」）
6. 闪回·母亲病逝（「妈妈后来死了」）
7. 闪回末拍·约束（「包括她自己。」）
8. 黄昏草地·请抬起头（新底图 bg_grass_dusk）
9. 草地·好朋友拥抱（「咸咸的！」）
10. 城堡内景·夜（新底图 bg_castle_home，三室一厅）
11. 翌日晨·菲戈蕾钻被窝
12. 镜前互瞪（菲戈蕾不吃亏）
13. 阳台门·「进入第三层」
14. 上行过渡页（第 2 层读白）

状态打印核验：补看直达 boot（layer=3 col=0 interlude_done=false）→ 末拍后
（interlude_done=true、过渡页可见）。

## 8. 美术（2 张·Maker 生成）

| 文件（`assets/sprites/prologue/`） | 用途 | 生成参数 |
|---|---|---|
| `bg_grass_dusk.png`（1280×720） | 黄昏草地（拍 15–17） | 16:9、2K；日落暖色、起伏草坡、野花；`reference_images` 对齐既有幕间底图风格 |
| `bg_castle_home.png`（1280×720） | 城堡内景·夜（拍 18–21） | 16:9、2K；现代三室一厅客厅、阳台玻璃门外见粉色魔法城堡 |

- 原图落 `assets/image/`（物料目录，不进提交）；运行时副本＋`.import` 随代码提交
- 复用：拍 0–2 用既有 `bg_castle`；闪回拍零素材（§2 调制实现）

## 9. 边界与遗留

- 闪回样式＝调制实现（无独立素材、零新增渲染节点）；后续层闪回可直接复用 `flashback` 键
- 幕间补看仅第三层初列门控；老档幕间中段（column 1+）不补——同 L2 入场防错位模式
- 幕间途中存档状态＝层已结、L3 初列、flag false——重进必补看（且只补幕间，层主战不重打）
- 「爸爸」男人身份／「心境具象化」通例化／第三幕层内内容核对——三条登记
  open-decisions【待小组／待第三幕专轮】
- 菲戈蕾来历（open-decisions 既有条）本稿未触及；L3＝暴食层，层主情报待后续稿
