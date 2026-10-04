class_name BattleConfig
extends RefCounted

# 文案现状：【测试内容】。结构已按 2026-10-03 新流程（召唤告知 → 教学 → 转化 → 打净 → 剥离 → 收下 → 三问 → 同行）改写，
# 非正典；定稿后按 design/setting/open-decisions.md 的清账项重写。读白使用全角标点。
# 告知边界：剥离前的所有文本只说「打倒／清空血量」，不得出现「剥离」「收下」「救」。

const PLAYER_MAX_HP := 10
const PLAYER_MAX_COST := 12
# 教程战为短局：玩家打小默时手里还没有罪卡（收下发生在战斗之后），8 回合保底的拉长无意义
const ENEMY_MAX_HP := 16
const ENEMY_NAME := "小默"
const HAND_SIZE := 5
const HAND_LIMIT := 8
const PLAY_ZONE_SIZE := 5
const TURN_TIME_LIMIT := 45.0
const DECK_SIZE := 8
const DECK_COMPOSITION := {
	"strike": 5,
	"guard": 2,
	"call": 1,
}
# 仓库初始卡池：三分类（攻击/防御/功能）各强弱两档＋增幅类四张，总量 20 > 卡组 8，组卡为真取舍
const WAREHOUSE_INITIAL := {
	"strike": 5,
	"heavy_strike": 2,
	"guard": 3,
	"strong_guard": 2,
	"call": 2,
	"shift": 2,
	"quench": 2,
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

# 罪卡规则（design/design-round1.md §1）：任务达成或第 SIN_ROUND_FALLBACK 回合保底解锁；每场战斗仅出现并使用一次
const SIN_CARD_ID := "wrath"
const SIN_ROUND_FALLBACK := 8
const SIN_TASK_ATTACK_PLAYS := 3
const TEXT_SIN_TASK := "本场战斗中累计打出 %d 张攻击牌"
const TEXT_SIN_PROGRESS := "（%d/%d）"
const TEXT_SIN_UNLOCKED := "「%s」的封印解开了——它现在可以打出了。"
const TEXT_SIN_USED := "「%s」已经用过了。这一场，它不会再回来。"
const TEXT_SIN_BLOCKED := "「%s」被封印着——%s%s，或撑到第 %d 回合，它才会醒。"  # 4 参数：牌名、任务文案、进度、保底回合

const TEXT_INTRO := [
	"你在一阵耳鸣里睁开眼。这里不该有天空，可它倒挂着一片花园。",
	"「醒啦。」一个睡眼惺忪的少女蹲在你旁边，声音很轻。「对不起——是我把你叫来的。」",
	"「这里是你的世界的『隔壁』。整整八层，每一层都被一种罪缠住了；最上面，还坐着一个源头。」",
	"「想回家，就一层一层打上去：把每一层的家伙打倒，把血条清空。路会自己亮起来。」",
	"「还有件事，得先告诉你。」她低头看了看自己的指尖——那里已经透出一点白色的火。「我快撑不住了。再过不久，我就会变成这一层的东西。」",
	"「所以趁我还认得你——先学会怎么打。跟我来。」",
]

const TEXT_TEACH := [
	"小默把你领到练习站，把三张牌摊开在你面前。「这一路，你只会用到三种动作。」",
	"「『打击』——把挡路的东西打停。『护住』——挡下它甩过来的一切。」",
	"「『呼喊』——喊它一声。听见了，它就会愣住一回合，这一回合就不会打你。」",
	"「仓库里的牌都归你。挑八张，组一副顺手的卡组，在这儿随便打——打木桩，打到顺手为止。」",
	"「准备好了，就来台阶那边找我。」",
]

const TEXT_TRANSFORM := [
	"台阶前，小默忽然停住了。",
	"她低头看着自己的手——指尖已经翻成一张一张的牌面，正顺着手腕往上爬。",
	"「啊。原来这么快。」睡意第一次从她脸上掉光了。「别慌，就按练习里教的打。」",
	"「趁我还认得你——打倒我。把这条血条，清空。」",
]

const TEXT_STRIP := [
	"「……够了。」她忽然笑了。",
	"一团滚烫的白火，从她胸口被拽出来，悬在你们中间。",
	"它想缩回去——做不到。它盯着你。",
]

const TEXT_PURIFY := [
	"小默喘着气坐了起来，指尖一点点回了血色。",
	"「听见了吗？剥下来的罪不会消失。」她盯着你手里那张牌。「它得去个地方。刚才——它去了你那儿。」",
	"她站起来，拍了拍裙子上的灰，睡眼又回来了。「我跟你一起走。上面每一层，都还有这样的家伙在等着。」",
	"「走吧。这一层，已经打完了。」",
]

const TEXT_DEBRIEF := [
	"「她归零的那一下，到底发生了什么？」",
	"「这张牌现在摆在你面前。什么感觉？」",
	"「路上还有更多这样的人。想继续吗？为什么？」",
]

const TEXT_ENDING := [
	"底层到这里就结束了。通往上层的台阶上，多了一串脚步声——你的，和小默的。",
	"「走啦走啦。」她打了个哈欠，「上面那层的家伙，比我麻烦多了。到时候别手软。」",
]

const TEXT_DISCARD := "手里的牌超出了上限（最多 %d 张）——选牌弃掉，还差 %d 张。"
const TEXT_PRACTICE_START := "练习开始——对面是木桩。"
const TEXT_PRACTICE_IDLE := "木桩纹丝不动。"
const TEXT_PRACTICE_END := "木桩倒下了。"
const TEXT_REVIVE := "法阵亮了一下，把你拽了回来。"
const TEXT_SUPPRESSED := "她没有打你，只是小声说：「……对不起。」"
const TEXT_ENEMY_IDLE := "%s没有出牌。"
const TEXT_ENEMY_DOMINANT := "「它」占上风。"
const TEXT_ENEMY_RESISTING := "「她」还在挣，用很轻的声音说：「……对不起。」"
const TEXT_ROUND_GAIN_PLAYER := "新的一轮——你获得 %d 张牌。"
const TEXT_ROUND_GAIN_ENEMY := "%s也获得 %d 张牌。"
const TEXT_END := "教程战到此结束。"
