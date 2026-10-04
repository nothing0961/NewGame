class_name CardData
extends Resource

# AMPLIFY 追加为 5：.tres 里 kind 存整数，旧牌重编号会全盘错位
enum Kind { ATTACK, DEFENSE, UTILITY, ENEMY, SIN, AMPLIFY }

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.ATTACK
@export var cost: int = 1
@export var text: String = ""
@export var flavor: String = ""
@export var permanent: bool = false
@export var effects: Array[Dictionary] = []
# 仅「弃牌区主动弃掉」触发；强制弃牌（手牌超限）不触发
@export var discard_effects: Array[Dictionary] = []

# 堆叠合成牌的构成（原始牌，逐张排放）；非空即为合成牌
var parts: Array[CardData] = []


func is_merged() -> bool:
	return not parts.is_empty()


func kind_label() -> String:
	match kind:
		Kind.ATTACK:
			return "攻击"
		Kind.DEFENSE:
			return "防御"
		Kind.UTILITY:
			return "功能"
		Kind.ENEMY:
			return "敌方"
		Kind.SIN:
			return "罪"
		Kind.AMPLIFY:
			return "增幅"
	return ""
