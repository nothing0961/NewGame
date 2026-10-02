class_name BattleConfig
extends RefCounted

const PLAYER_MAX_HP := 10
const ENEMY_MAX_HP := 12
const ENEMY_NAME := "召唤者"
const HAND_SIZE := 5
const DECK_COMPOSITION := {
	"strike": 3,
	"guard": 1,
	"call": 1,
}
const COIN_HEADS_DAMAGE := 2
const COIN_TAILS_DAMAGE := 1

# 读白使用全角标点；内容与纸原型逐句一致
const TEXT_INTRO := [
	"你在一阵耳鸣里睁开眼。这里不该有天空，可它倒挂着一片花园。",
	"法阵中央钉着一个人。他的手指正在一张一张地变成扑克牌。",
	"他不认识你——你也不知道他为什么能把你叫来。",
	"「快……」他说，「我快整个变成它们了。打我，别问。打到我停下来为止。」",
]

const TEXT_STRIP := [
	"「……够了。」他忽然笑了。",
	"一团滚烫的白火，从他的胸口被拽出来，悬在你们中间。",
	"它想缩回去——做不到。它盯着你。",
]

const TEXT_PURIFY := [
	"召唤者喘着气坐了起来，指尖一点点回了血色。",
	"「听见了吗？剥下来的罪不会消失。」他盯着你手里那张牌。「它得去个地方。刚才——它去了你那儿。」",
	"「你是法阵叫来的。叫来的，都是最恨它的人。……抱歉。」",
	"他抬手指向远处一座发亮的法阵。「我回那边守着。我的位置，已经亮了。往后你每救回一个人，就再亮一个。等齐了——你能回家。」",
	"「去吧。还有人在等。」",
]

const TEXT_DEBRIEF := [
	"「他归零的那一下，到底发生了什么？」",
	"「这张牌现在摆在你面前。什么感觉？」",
	"「路上还有更多这样的人。想继续吗？为什么？」",
]

const TEXT_REVIVE := "法阵亮了一下，把你拽了回来。"
const TEXT_SUPPRESSED := "他没有打你，只是小声说：「……对不起。」"
const TEXT_END := "教程战到此结束。"
