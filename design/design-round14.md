# 设计备忘 · 第十四轮：L2 层主战机制钩子实装——大炮拦截／传送破局／玩偶军队／遏制窗口（2026-10-12）

> 会话决策记录。第十二/十三轮（design-round12/13.md）已实装第二幕全部演出（入场 A/B、层主战
> 前演出、收尾 OUTRO_A/B），但 L2 层主战**本体仍是占位**（阿斯莫德 24 血＋共享小怪敌牌组）。
> open-decisions 三处【待专轮】挂着：①机制钩子（欲望状态／净化克／遏制窗口，加收尾稿实写的
> 大炮/传送/玩偶军队）②L2 场景与名录核对。本轮（用户 2026-10-11 选定「L2 机制钩子专轮＋轻量
> 杂项打包」，执行跨 10-11→10-12）把层主战做成与 OUTRO 叙事一一映射的三阶段机制战；顺带清
> 轻量杂项＋L2 名录对齐正典重命名。

## 0. 口径决案（2026-10-11 用户逐项确认，六项）

1. **欲望状态＝回合开始失血**：每层 1 伤、上限 4 层；净化＝清除全部层数＋本场负面免疫
   （把 UI 显示已久的「免疫负面状态（本场）」做成真——`sleep_immune` 泛化改名 `status_immune`
   并接线；原字段是死锁存器、从不被读）
2. **大炮阶段＝忠实拦截**：玩家攻击伤害全部被抵消（含 AOE）；开局手牌获赠「传送」＝唯一破局；
   防呆：阶段 1 玩家回合开始时若手牌无「传送」则补发
3. **遏制窗口＝终盘一次**：清完玩偶且阿斯莫德存活 → 她下一次攻击**打偏**（0 伤＋读白）→
   此后不再反击（瘫坐日志）；窗口开启后玩家对她的伤害 ×2 直到击杀
4. **L2 名录＝对齐正典重命名**：仅显示名；绑定键/数值/敌牌组/事件效果全不动（表见 §3）
5. **架构**：新显式 stage 键 `"phases": "l2_boss"` 触发（不与 `intro`/`outro` 键耦合）；
   三阶段常数与文本入 battle_config；赠送卡不入 CardPool/仓库/存档
6. **层主战清血后仍直入既有 OUTRO_A/B 收尾链**（round13 链零改动）

## 1. 三阶段机制设计（叙事一一映射）

```
层主战（阿斯莫德 · HP 24 · LAYER2_BOSS 加 "phases":"l2_boss"）
├─ 阶段 1 大炮拦截（boss_phase=1）
│   敌表＝阿斯莫德 24（kind boss）＋两门「大炮」6×2（kind cannon, inanimate）
│   敌牌组＝魔炮弹幕×4＋欲望低语×4
│   玩家攻击全被抵消（每次效果一条「莉维娅的魔炮将攻击抵消了！」）
│   开局赠送「传送」（teleport；每回合开局防呆补发）
│   └─ 打「传送」→ 传送破局：本体 −4（24→20）→「好疼！」/魔杖脱手 → 大炮散架
│        boss_phase=2 ＋ 敌牌组换装（玩偶扑袭×5＋欲望低语×3、手牌 4）
│        ＋ 玩偶×3 登场（6 血 inanimate）＋ 赠送「懒惰的权能」
├─ 阶段 2 玩偶军队（boss_phase=2）
│   正常战斗（普通伤害可直接打本体；玩偶由权能清扫）
│   └─ 打「懒惰的权能」→ 全部 inanimate 扫倒 → commit 批末武装窗口
├─ 阶段 3 遏制窗口（boss_phase=3）
│   下次敌方回合＝打偏一次（0 伤＋「魔力弹打偏了……轰倒了旁边的小屋。」
│   「「没打中我，为什么？」」）→ 此后每个敌方回合「莉维娅瘫坐在地，不再反击。」
│   窗口期玩家对她伤害 ×2（L2_WINDOW_MULTIPLIER）直到击杀
└─ 她清血 → 直入 ENDED → round13 OUTRO_A/B 收尾链（零改动）
```

- 胜判特例：`_all_enemies_dead() or (phases_id == L2_BOSS_PHASES and _boss_dead())`
  ——**本体死即胜，玩偶存活不阻塞**（叙事：她是本体，玩偶只是清场障碍）
- 节奏目标 ≈4–6 玩家回合（传送 4 伤＋窗口双倍收口）；全部旋钮＝battle_config 常数块
- 「故意打偏」＝遏制窗口的实装拍：收尾稿「我技高一筹」「趁现在我能控制住自己，快行动！」
  映射为 miss 读白两条；窗口开启时顺带清 `enemy_suppressed` 防悬挂

## 2. 欲望状态（净化克的实装）

- 施加：敌方「欲望低语」（1 伤＋`inflict_desire` 1）——敌牌不走 `_apply_effect`，在
  `_enemy_turn` 出牌循环的伤害累计处逐张扫效果结算
- 上限 4 层（满层再施加＝「欲望已经涨无可涨」日志，不加层）
- 回合开始失血：`_apply_desire_tick()` 直扣 `player_hp -= stacks`（**绕过格挡**）＋日志
  「欲望侵蚀——你失去 %d 点生命。（生命 %d）」；≤0 → `_handle_defeat()`（既有 DEFEAT 覆盖层）；
  `_start_player_turn` 判负后提前 return 防重复相位信号
- 净化：`status_immune = true`（本场负面免疫）＋清空全部层数＋「缠上来的欲望被冲散了。
  （清除 %d 层）」；此后耳语滑开——「「欲望低语」的耳语贴过来又滑开了——净化把你护在里面。」
- HUD：格挡行追加「欲望 %d 层」（>0 时）／「负面免疫」（status_immune 时）

## 3. 卡与文本

### 3.1 新卡 5 张（`data/cards/`）

| 文件 | 名 | kind | cost | 效果 | 备注 |
|---|---|---|---|---|---|
| teleport.tres | 传送 | 功能 | 0 | `teleport_strike` 4（无视拦截；阶段 1 破局／之后降级为普通 4 伤） | permanent＝战斗内赠送；不可与其它牌叠合；flavor「贝嘉，可以传送……」 |
| lazy_power.tres | 懒惰的权能 | 功能 | 2 | `sweep_inanimate`（摧毁所有没有意识的敌人） | permanent＝战斗内赠送；不可叠合；flavor「躺下，等等，躺下？」 |
| cannon_barrage.tres | 魔炮弹幕 | 敌方 | 1 | 2 伤 | 阶段 1 敌牌组 |
| desire_whisper.tres | 欲望低语 | 敌方 | 1 | 1 伤＋1 层欲望 | 两阶段敌牌组共用 |
| puppet_attack.tres | 玩偶扑袭 | 敌方 | 1 | 2 伤 | 阶段 2 敌牌组 |

赠送卡防泄漏（均核验）：`permanent=true` → 结算进 `collection` 不入弃牌堆；`collected_sin_ids`
只滤 `kind==SIN`（不进仓库）；不与任何牌叠合（`can_merge_with` 拦）；不入
DECK_COMPOSITION/WAREHOUSE_INITIAL/TEACHING_DECK/AMBUSH_DECK；cost-0「传送」被主动弃牌
得 gain=−1 有守卫不崩（阶段 1 补发兜底）。

### 3.2 文本（battle_config 新常量，全角标点）

阶段 1 开场两行（大炮架起／攻击会被拦下）；TELEPORT_GRANT「一股信息流入脑海——是菲戈蕾：
「贝嘉，可以传送……」」；INTERCEPT「莉维娅的魔炮将攻击抵消了！」；TELEPORT_STRIKE
「传送完成——你出现在莉维娅身后，魔力弹重重轰落。」；HURT「「好疼！」」；WAND_DROP
「她灰头土脸地跌在地上，手里的魔杖脱手滚了出去。」；CANNONS_FALL「两门大炮失去操控，
散架成一地零件。」；PUPPETS_APPEAR「「我生气了！」她小手一挥——小镇店铺里的玩偶和玩具
都动了起来，身形放大，化成一支军队。」；LAZY_GRANT「懒惰的权能浮上掌心——对没有意识的
死物，它几乎不费力气。」；LAZY_SWEEP/LAZY_NOOP；WINDOW_MISS_1/2；WINDOW_IDLE
「莉维娅瘫坐在地，不再反击。」；DESIRE_UP/IMMUNE/FULL/TICK；CLEANSE_DESIRE。

## 4. L2 名录对齐正典重命名（仅显示名）

| 现名（HP 不变） | 新名 | 依据 |
|---|---|---|
| 粉雾歌者（16） | 雾中残响 | 迷雾公路段——「挽留的演出」歌停之后的余响（层节奏保留） |
| 糖丝傀儡（18） | 橱窗巧偶 | 小镇橱窗里的孩子气玩具（「玩偶」词已被层主战阶段 2 占用，取「巧偶」避让） |
| 镜前舞者（20） | 橱窗舞影 | 橱窗里的可爱小裙子＝舞影 |
| 缠丝泡影（22） | 糖雾泡影 | 小镇糖意＋渐散的雾 |

- 事件名录：**核对后 5 条全部保留**——试衣镜（演出服/裙摆＝小裙子锚点）／糖果摊（糖果）／
  合唱席（「挽留的演出」节奏核心）／粉焰之墙（色欲粉焰＋「甜的挽留」）／献花台（楼梯转角＝
  上行城堡前段）——均有实景锚点
- 老存档 route 内旧名仅显示层残留，无数据破坏；测试夹具旧名引用全量同步

## 5. 实现接线（关键文件）

- `battle_config.gd`：L2 三阶段常量块（L2_BOSS_PHASES／L2_PHASE1_ENEMIES／L2_PHASE1_DECK／
  L2_PHASE2_DECK／L2_PHASE2_HAND 4／L2_PUPPET_NAME·HP 6·COUNT 3／L2_TELEPORT_DAMAGE 4／
  L2_WINDOW_MULTIPLIER 2／L2_GRANTED_CARDS／DESIRE_STACK_CAP 4）＋全套文本常量
- `battle_state.gd`：新成员 `phases_id/boss_phase/desire_stacks/_window_armed/_window_active`；
  `sleep_immune` → `status_immune` 改名；`_setup` STORY 分支读 phases 键（敌表/敌牌组覆盖＋
  boss_phase=1＋开场日志＋发传送）；拦截门（deal_damage 全路径含 AOE，`teleport_strike`
  独立 op 不经此门）；新 op `teleport_strike`/`sweep_inanimate`/`inflict_desire`；
  `_l2_teleport_breakthrough`（4 伤→炮清除→phase 2→换牌组→3 玩偶→发权能）；
  `_check_phase3_window`（commit_staged 效果循环后、胜判前）；`_enemy_turn` 打偏/瘫坐；
  `_damage_enemy` 窗口 boss×2；`_start_player_turn` 欲望 tick＋DEFEAT 提前 return＋传送补发；
  cleanse 接 status_immune＋清欲望；胜判特例；`_make_enemy` 第三参 extra（kind/inanimate）；
  `can_merge_with` 拦赠送卡
- `battle_screen.gd`：`_sync_ui` 格挡行追加「欲望 N 层」「负面免疫」（纯代码零 .tscn）
- `layer_config.gd`：LAYER2_BATTLES 重命名（§4 表）＋LAYER2_BOSS 增 `"phases":"l2_boss"`
  （intro/outro 键保留）；`_normalize_stage` 深拷贝使 phases 字符串键随存档原样往返
- 流程：胜 → `_end_story_stage()` → ENDED → `main_flow` OUTRO 派发（round13 链零改动）；
  L3–7 层主（phases_id 空）三阶段 STRIP 链/教程/教学/遭遇战/练习全隔离零影响

## 6. 测试（`tests/run_tutorial_test.gd`）

- 新助手 `_drive_l2_boss_victory`（打传送→打权能→循环 strike/guard 至 ENDED）——
  ⚠ 既有 `_press_strikes_until_over` 对阶段 1 拦截会死循环，L2 用例全部换用新助手
- 新增 7 用例：`test_l2_phase_data`（phases 键/5 新卡/赠送卡不入仓库组牌链）／
  `test_l2_boss_phases`（开场 3 敌＋发传送＋日志＋strike 与 AOE 均被抵消）／
  `test_l2_teleport`（破局链：−4/炮清除/3 玩偶/换牌组/发权能；阶段 2 降级 4 伤）／
  `test_l2_window_mechanics`（清扫→打偏 0 伤→瘫坐→×2→击杀 ENDED）／
  `test_l2_win_special_case`（玩偶存活杀 boss 直接 ENDED）／`test_l2_desire_system`
  （叠加/上限 4/回合失血/失血判负/净化清层＋免疫/免疫滑开）／`test_l2_boss_scene`
  （场景级敌表 3→4 行、格挡行含「欲望」、驱动胜利）
- 改造：`test_story_battle_boss`／`test_layer_bosses_complete`／`test_main_flow_layer2`
  层主段（E2E 换驱动＋phases 断言＋名单更新）；`sleep_immune` → `status_immune` 全量同步
- **测试 1978→2085 项全过（3 连跑）**

## 7. 走查截图（`.tmp/shot_round14.gd`，14 张全过目）

1. 第 2 层地图改名（雾中残响／橱窗巧偶／橱窗舞影／糖雾泡影）
2. 阶段 1 开场（3 敌＋两门大炮「笔筒与圆形橡皮拼接的炮口」＋发传送）
3. 拦截（「莉维娅的魔炮将攻击抵消了！」；本体 24 不掉血）
4. 传送拍（本体 −4→20/24；4 行敌表＋权能进手牌）
5. 炮散＋玩偶登场＋发权能（同一结算日志后段）
6. 欲望叠加（低语×2 → 欲望 2 层；回合开始再失血 2）
7. 权能摆出（未结算）
8. 权能清扫（玩偶已倒下×3 → 窗口武装）
9. 打偏开窗（miss 读白两条）
10. 双倍命中（窗口期攻击 2→4；欲望 2 层仍在）
11. 回合失血（窗口期敌回 IDLE＋「欲望侵蚀」再 −2）
12. 净化（清除 2 层＋HUD「负面免疫」＋免疫读白）
13. 胜后 OUTRO_A 首拍（与 round13 收尾链连通回归）
14. OUTRO_A 第二拍

状态打印核验：hp=16 stacks=2（欲望）→ boss_phase=3 active=true（窗口）→ boss_hp=16 hp=12
（双倍命中）→ hp=10（tick）→ stacks=0 immune=true hp=10（净化）。

## 8. 轻量杂项打包（本轮一并）

- **exe 重导＋完整包重建**：`七妄奇迹.exe`（2026-10-12 09:56，122.4 MB）＋桌面
  `七妄奇迹20261012.zip`（76.6 MB；计划文本写 20261011、执行跨天改 20261012）；启动抽查
  卡面样式正常（10-06 曾修「卡面只剩文字」）；包内无 assets/image、无凭据文件
- **战报「//」「#」记号清账**（open-decisions :42 尾注）：最终映射定案＝战斗行入战斗日志、
  剧情行入读白；「//」「#」不逐字呈现——不再列为遗留（无代码改动）
- **「她」系卡 flavor**（open-decisions :124）：归入定稿轮清账（全内容【测试内容】统一重写），
  本轮不动、补注记

## 9. 边界与遗留

- AOE 拦截＝每次效果一条日志（合成牌多次效果会多行，可接受）
- 玩偶存活杀 boss：胜判特例先行；`_check_phase3_window` 需 boss 存活（防幽灵武装）
- 阶段 2 中玩家伤害打「当前敌人」＝阿斯莫德本人（不拦截、正常伤；玩偶由权能清扫——
  「普通伤害可用」口径；权能非强制但有最优）
- 欲望失血判负走 `_handle_defeat` ─ DEFEAT 覆盖层既有；`_start_player_turn` 提前 return
  防重复相位信号
- 老存档 route 内旧名录仅显示层残留；`_normalize_stage` 深度拷贝保 phases 键往返
- 菲戈蕾传送边界（距离/次数/可用场合，open-decisions :71）仍待小组；贝嘉「懒惰权能」表述
  明文化（:72）留定稿轮
- open-decisions :49/:50/:61/:70 四处 L2 机制与名录条目已落「已决注记（design-round14）」
