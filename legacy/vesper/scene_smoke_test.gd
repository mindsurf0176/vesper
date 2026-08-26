extends Node
## 출시 후보 씬 스모크 테스트. 주요 진입 씬이 모두 생성되는지 확인한다.

func _ready() -> void:
	GameState.test_mode_no_save = true
	GameState.new_game()
	GameState.brand_points = 2
	GameState.run_records = [
		{ "stage_id":"s1", "stage_name":"격리 구획", "win":true, "rules":["소환 훈련"] },
		{ "stage_id":"s2", "stage_name":"포자 온상", "win":false, "rules":["손패 순환"] },
	]

	var scenes := [
		"res://legacy/vesper/title.tscn",
		"res://legacy/vesper/home.tscn",
		"res://legacy/vesper/stagemap.tscn",
		"res://legacy/vesper/squad.tscn",
		"res://legacy/vesper/roster.tscn",
		"res://legacy/vesper/gacha.tscn",
		"res://legacy/vesper/shop.tscn",
		"res://legacy/vesper/chat.tscn",
		"res://legacy/vesper/missions.tscn",
		"res://legacy/vesper/mail.tscn",
		"res://legacy/vesper/growth.tscn",
		"res://legacy/vesper/settings.tscn",
		"res://legacy/vesper/notice.tscn",
		"res://legacy/vesper/guide.tscn",
		"res://legacy/vesper/credits.tscn",
		"res://legacy/vesper/battle3d.tscn",
	]
	for path in scenes:
		var packed: PackedScene = load(path)
		assert(packed != null, "%s 로드 실패" % path)
		var inst = packed.instantiate()
		add_child(inst)
		await get_tree().process_frame
		assert(is_instance_valid(inst), "%s 인스턴스 생성 실패" % path)
		if path == "res://legacy/vesper/title.tscn":
			inst._open_help()
			await get_tree().process_frame
		inst.queue_free()
		await get_tree().process_frame

	GameState.test_mode_no_save = false
	print("PASS scene_smoke major scenes")
	get_tree().quit()
