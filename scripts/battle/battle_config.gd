class_name BattleConfig
extends RefCounted

# 文案现状：【测试内容】。初幕与新手教程已按小组脚本（2026-10-05【正典】）对齐：
# 初幕演出 → 蜗牛教学战 → 教学说明 → 练习站 → 追及段 → 层主战·贝尔芬格 → 净化 → 收下 → 三问 → 同行。
# 双名制：初幕白发少女＝菲戈蕾（人身）；被懒惰之力彻底污染后＝贝尔芬格（战斗形态）；净化后恢复菲戈蕾同行。
# 读白使用全角标点。告知边界：净化前的所有文本只说「打倒／清空血量」，不解释「怎么救」。

const PLAYER_MAX_HP := 10
const PLAYER_MAX_COST := 12
# 层主战为短局：玩家打贝尔芬格时手里还没有罪卡（收下发生在战斗之后），8 回合保底的拉长无意义
const ENEMY_MAX_HP := 16
const ENEMY_NAME := "贝尔芬格"
const HAND_SIZE := 5
const HAND_LIMIT := 8
const PLAY_ZONE_SIZE := 5
const TURN_TIME_LIMIT := 45.0
const DECK_SIZE := 8
# 默认卡组（组卡缺省回退用）：红攻×5＋蓝防×2＋金功能×1
const DECK_COMPOSITION := {
	"strike": 4,
	"heavy_strike": 1,
	"guard": 2,
	"heal": 1,
}
# 仓库初始卡池（20 张）：四色体系（红攻／蓝防／金功能／紫核心）＋增幅类，总量 > 卡组 8，组卡为真取舍
const WAREHOUSE_INITIAL := {
	"strike": 4,
	"heavy_strike": 2,
	"guard": 3,
	"strong_guard": 2,
	"call": 2,
	"shift": 1,
	"heal": 1,
	"cleanse": 1,
	"greed_shot": 1,
	"quench": 1,
	"surge": 1,
	"bulwark": 1,
}
# 堆叠：把一张牌叠到出牌区同类已摆牌上，合成牌费用＝各原牌费用之和＋每多一张收 STACK_FEE
const STACK_FEE := 1
# 一轮结束（玩家回合＋敌人回合都结束）后，双方各从各自牌组摸三张；供给不足时能摸几张是几张
const ROUND_GAIN := 3
const ENEMY_DECK_COMPOSITION := {
	"enemy_strike": 8,
}

const PRACTICE_ENEMY_NAME := "木桩"
const PRACTICE_ENEMY_HP := 48

# —— 蜗牛教学战（小组脚本新手教程段）——
# 单位制仅此一战：魔力总量 4；教学牌组钉死（不洗牌）；过完教学战恢复 Cost 12 体系
const TEACHING_MAX_COST := 4
const TEACHING_PLAYER_HP := 8
const TEACHING_TURN_TIME_LIMIT := 90.0
# 波 1 五血＝两发魔弹打剩一口气，让它有机会照脚本出手一次（防御卡正好挡下）
const TEACHING_WAVES := [
	{"name": "蜗牛怪物", "hp": 5},
	{"name": "蜗牛群怪", "hp": 3, "count": 3},
]
const TEACHING_ENEMY_DECK := {
	"snail_bite": 3,
}
# 钉死节拍：数组顺序＝摸牌顺序（代码反向入堆配合 pop_back）
# 开局手＝普通防御＋普通魔弹×2＋治疗术＋普通魔弹；牌堆＝净化＋强欲魔弹＋普通魔弹
const TEACHING_DECK := ["guard", "strike", "strike", "heal", "strike", "cleanse", "greed_shot", "strike"]
# 波 2 登场后，睡意倒计时＝当前回合 + 2：到时仍未免疫则跳过一个回合（一次），走完即解
const TEACHING_SLEEP_DELAY := 2

# 罪卡规则（design/design-round1.md §1）：任务达成或第 SIN_ROUND_FALLBACK 回合保底解锁；每场战斗仅出现并使用一次
# 任务/保底参数按卡配置（design/design-round3.md §6：按牌组中的罪卡逐卡检定）
const SIN_CARD_ID := "wrath"
const SIN_ROUND_FALLBACK := 8
const SIN_TASK_ATTACK := "attack_plays"
const SIN_TASK_CONFIG := {
	"wrath": {"task": SIN_TASK_ATTACK, "count": 3},
	"lust": {"task": SIN_TASK_ATTACK, "count": 2},  # 【测试内容】占位，随第二层设计轮替换
}
const TEXT_SIN_TASK := "本场战斗中累计打出 %d 张攻击牌"
const TEXT_SIN_PROGRESS := "（%d/%d）"
const TEXT_SIN_UNLOCKED := "「%s」的封印解开了——它现在可以打出了。"
const TEXT_SIN_USED := "「%s」已经用过了。这一场，它不会再回来。"
const TEXT_SIN_BLOCKED := "「%s」被封印着——%s%s，或撑到第 %d 回合，它才会醒。"  # 4 参数：牌名、任务文案、进度、保底回合

# —— 教学战提示（莉维娅引导语注入战斗日志；_setup/_spawn_wave/_start_player_turn 三处发）——
const TEXT_TEACHING_START := [
	"莉维娅：「先认识你的四种颜色——蓝的防御，红的攻击，金的功能，紫的核心。」",
	"莉维娅：「魔力按单位算，牌左上角的数字就是花费。你现在有 4 个单位的魔力。」",
	"莉维娅：「敌人要发起攻击了——先把蓝色防御卡拖进出牌区，一张就够了。」",
]
const TEXT_TEACHING_TURN_KILL := "莉维娅：「它只剩一口气了——再补一张红的攻击牌。」"
const TEXT_TEACHING_FIRST_FELL := "第一只蜗牛怪物倒下了——又有三只蜗牛怪物涌了上来。"
const TEXT_TEACHING_SLEEP_EVENT := "森林深处传来一股力量——你和怪物，都想要沉睡。"
const TEXT_TEACHING_SLEEP_HINT := "莉维娅：「那是懒惰的力量。先用金色的净化，来免疫这种负面状态。」"
const TEXT_TEACHING_TURN_WAVE2 := "莉维娅：「先净化免疫睡意，再用紫色核心牌『强欲魔弹』——3 个单位的群体攻击，对沉睡的敌人追加伤害。」"
const TEXT_TEACHING_WIN := "三只蜗牛怪物都倒下了。森林重新安静下来。"

const TEXT_ENEMY_SLEEPING := "%s沉在睡意里，没有动作。"
const TEXT_SLEEP_SKIP := "睡意漫了上来——这一回合，你动不了。"
const TEXT_CLEANSE_SLEEP := "睡意被挡在身体外面——净化生效了。"
const TEXT_CLEANSE := "净化生效了。本场战斗中，负面状态不会再找上你。"

# 教学说明（蜗牛教学战后→练习站；练习站为既有结构，非脚本内容）
const TEXT_TEACH := [
	"蜗牛群安静了下去。莉维娅的声音重新从水晶里浮出来：「基础的战斗方式，你已经会了。」",
	"「还差一点手感——前面不远有一处练习站。在那儿重新配一副卡组，打到顺手为止。」",
	"「里面的牌都归你，挑八张。接下来的战斗里，魔力会放开到十二个单位。」",
	"「准备好了，就顺着森林往深处走——菲戈蕾还在等着我们。」",
]

# 追及段（向菲戈蕾方向前进→遭遇异化的贝尔芬格形态）
const TEXT_TRANSFORM := [
	"你们顺着菲戈蕾留下的气息往森林深处追。越往里，雾气越沉，像有什么更重的东西把一整片林子按住了。",
	"空地中央站着一个白色的身影。白发垂了下来，遮住半张脸；她脚边，蜗牛怪物卷成一团一动不动。",
	"「菲戈蕾……」你刚要开口，她抬起了脸——那双丁香紫的眼睛里，正翻涌着不属于她的东西。",
	"「趁我还认得你——」声音很轻，像从很远的地方传来。「打倒我。把这条血条，清空。」",
]

const TEXT_STRIP := [
	"「……够了。」她忽然笑了，笑得很轻。",
	"一团沉沉的白雾，从她胸口被拽出来，悬在你们中间。",
	"它想缩回去——做不到。它盯着你。",
]

const TEXT_PURIFY := [
	"白雾散尽。她撑着膝盖喘匀了气，再抬起头时，那双丁香紫的眼睛已经清亮起来。",
	"「听见了吗？净化不会让罪消失。」她盯着你手里那张牌。「它得去个地方。刚才——它去了你那儿。」",
	"她拍了拍裙子上的灰，恢复成面无表情的样子：「我是菲戈蕾。接下来，我跟你一起走。」",
	"「走吧。这一层，已经打完了。」",
]

const TEXT_DEBRIEF := [
	"「她归零的那一下，到底发生了什么？」",
	"「这张牌现在摆在你面前。什么感觉？」",
	"「路上还有更多这样的人。想继续吗？为什么？」",
]

const TEXT_ENDING := [
	"底层到这里就结束了。通往上层的台阶上，多了一串脚步声——你的，和菲戈蕾的。",
	"「走啦走啦。」她面无表情地打了个小小的呵欠，「上面那层比我麻烦多了。到时候别手软。」",
]

const TEXT_DISCARD := "手里的牌超出了上限（最多 %d 张）——选牌弃掉，还差 %d 张。"
const TEXT_PRACTICE_START := "练习开始——对面是木桩。"
const TEXT_PRACTICE_IDLE := "木桩纹丝不动。"
const TEXT_PRACTICE_END := "木桩倒下了。"
const TEXT_PRACTICE_DEFEAT := "你倒下了。练习到此结束。"  # 训练场不参与死亡规则：失败即结束，无惩罚
# 死亡规则（design/design-round3.md §5）：生命归零＝判负；层战回层首，教程层回追及段（design-round6.md）
const TEXT_DEFEAT := "你倒下了。手里的牌散了一地——这一层，得从头再来。"  # 【测试内容】层战
const TEXT_DEFEAT_BUTTON := "重新开始本层"
const TEXT_DEFEAT_TEACHING := "你倒下了。唔——没关系，站起来，再来一次。"  # 【测试内容】教学战/层主战
const TEXT_DEFEAT_RETRY := "再来一次"
const TEXT_STAGE_WIN := "挡路的东西倒了下去。前路清楚了一些。"  # 【测试内容】层内小怪战胜利
const TEXT_SUPPRESSED := "她没有打你，只是小声说：「……对不起。」"
const TEXT_ENEMY_IDLE := "%s没有出牌。"
const TEXT_ENEMY_DOMINANT := "「它」占上风。"
const TEXT_ENEMY_RESISTING := "「她」还在挣，用很轻的声音说：「……对不起。」"
const TEXT_ROUND_GAIN_PLAYER := "新的一轮——你获得 %d 张牌。"
const TEXT_ROUND_GAIN_ENEMY := "%s也获得 %d 张牌。"
const TEXT_END := "这一场，到此结束。"
