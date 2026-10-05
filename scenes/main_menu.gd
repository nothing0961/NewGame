extends Control

const MainFlowScript := preload("res://scripts/ui/main_flow.gd")

func _ready():
	# 强行用代码连接按钮信号，防止 UI 面板没连上；场景里已连过的跳过，避免重复连接报错
	if not $VBoxContainer/Button.pressed.is_connected(_on_button_pressed):
		$VBoxContainer/Button.pressed.connect(_on_button_pressed)
	if not $VBoxContainer/Button2.pressed.is_connected(_on_practice_pressed):
		$VBoxContainer/Button2.pressed.connect(_on_practice_pressed)
	if not $VBoxContainer/Button3.pressed.is_connected(_on_button_3_pressed):
		$VBoxContainer/Button3.pressed.connect(_on_button_3_pressed)

func _on_button_pressed():
	print("开始游戏！")
	MainFlowScript.open_practice_on_ready = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_practice_pressed():
	print("练习站！")
	MainFlowScript.open_practice_on_ready = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_button_3_pressed():
	print("退出游戏！")
	get_tree().quit()
