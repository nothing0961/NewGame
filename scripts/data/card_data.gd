class_name CardData
extends Resource

enum Kind { PLAYER, SIN }

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.PLAYER
@export var cost: int = 1
@export var text: String = ""
@export var flavor: String = ""
@export var permanent: bool = false
@export var effects: Array[Dictionary] = []
