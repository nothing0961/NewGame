extends Control

func _ready():
	# 强行用代码连接按钮信号，防止 UI 面板没连上；场景里已连过的跳过，避免重复连接报错
	if not $VBoxContainer/Button.pressed.is_connected(_on_button_pressed):
		$VBoxContainer/Button.pressed.connect(_on_button_pressed)
	if not $VBoxContainer/Button2.pressed.is_connected(_on_button_2_pressed):
		$VBoxContainer/Button2.pressed.connect(_on_button_2_pressed)
	if not $VBoxContainer/Button3.pressed.is_connected(_on_button_3_pressed):
		$VBoxContainer/Button3.pressed.connect(_on_button_3_pressed)

func _on_button_pressed():
	print("开始游戏按钮被点击了！")
	# ⚠️ 注意：下面这行括号里的路径，要改成你刚才复制的真实路径！
	# 比如你的对话场景叫 main.tscn，在根目录就是 "res://main.tscn"
	# 在 scenes 文件夹里就是 "res://scenes/main.tscn"
	get_tree().change_scene_to_file("res://scenes/main.tscn") 

func _on_button_2_pressed():
	print("选项被点击了！")

func _on_button_3_pressed():
	print("退出游戏！")
	get_tree().quit()
