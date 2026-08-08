extends Node
## 캐릭터 계약 회귀 테스트.
## 모든 플레이어블 캐릭터가 전투/도감/아트 생산에 필요한 정체성 필드를 갖는지 확인한다.

func _ready() -> void:
	GameState.test_mode_no_save = true
	GameState.new_game()

	var defs := GameState.all_chars_list()
	assert(defs.size() == 8, "플레이어블 캐릭터는 8명이어야 함")

	var required_strings := ["name", "true_name", "epithet", "rarity", "faction", "role", "lore", "quote", "visual_brief"]
	var names := {}
	var gacha_names := {}
	for item in GameState.GACHA_POOL:
		gacha_names[str(item.get("name", ""))] = true
	var pixellab_manifest_file := FileAccess.open("res://assets/pipeline/pixellab/manifest.json", FileAccess.READ)
	assert(pixellab_manifest_file != null, "PixelLab manifest 누락")
	var pixellab_manifest_raw = JSON.parse_string(pixellab_manifest_file.get_as_text())
	assert(typeof(pixellab_manifest_raw) == TYPE_DICTIONARY, "PixelLab manifest JSON 파싱 실패")
	var pixellab_manifest: Dictionary = pixellab_manifest_raw
	assert(str(pixellab_manifest.get("pipeline", "")) == "pixellab_combat_state", "PixelLab manifest pipeline 불일치")
	var pixellab_queue := {}
	for item in pixellab_manifest.get("characters", []):
		var slug := str(item.get("slug", ""))
		assert(not slug.strip_edges().is_empty(), "PixelLab manifest slug 누락")
		pixellab_queue[slug] = item

	for c in defs:
		var cname := str(c.get("name", ""))
		assert(not cname.strip_edges().is_empty(), "캐릭터 name 누락")
		assert(not names.has(cname), "%s 중복 등록" % cname)
		names[cname] = true
		assert(gacha_names.has(cname), "%s 모집 풀 누락" % cname)
		assert(GameState.ORB_SKILLS.has(cname), "%s 오브 스킬 누락" % cname)
		assert(GameState.IMPRINTS.has(cname), "%s 각인 누락" % cname)

		for key in required_strings:
			assert(c.has(key), "%s 필드 누락: %s" % [cname, key])
			assert(not str(c.get(key, "")).strip_edges().is_empty(), "%s 필드 비어 있음: %s" % [cname, key])

		var bonds: Array = c.get("bond_lines", [])
		assert(bonds.size() >= 2, "%s bond_lines는 최소 2개 필요" % cname)
		for line in bonds:
			assert(not str(line).strip_edges().is_empty(), "%s 빈 bond line" % cname)

		var skills: Dictionary = GameState.ORB_SKILLS[cname]
		for orb_count in ["1", "2", "4"]:
			assert(skills.has(orb_count), "%s %s오브 누락" % [cname, orb_count])
			assert(not str(skills[orb_count].get("label", "")).strip_edges().is_empty(), "%s %s오브 라벨 누락" % [cname, orb_count])

		var visual: Dictionary = c.get("visual", {})
		for key in ["mark", "shape", "primary", "accent", "weapon", "height", "enemy"]:
			assert(visual.has(key), "%s visual.%s 누락" % [cname, key])
		assert(str(visual.get("mark", "")).length() >= 1, "%s visual mark 비어 있음" % cname)

		if c.has("art") or c.has("card_art"):
			var face_path := str(c.get("art", ""))
			var card_path := str(c.get("card_art", ""))
			assert(ResourceLoader.exists(face_path), "%s 얼굴 에셋 없음: %s" % [cname, face_path])
			assert(ResourceLoader.exists(card_path), "%s 카드 에셋 없음: %s" % [cname, card_path])
			var face_tex: Texture2D = load(face_path)
			var card_tex: Texture2D = load(card_path)
			assert(face_tex != null and face_tex.get_width() >= 200 and face_tex.get_height() >= 200, "%s 얼굴 에셋 크기 부족" % cname)
			assert(card_tex != null and card_tex.get_width() >= 480 and card_tex.get_height() >= 780, "%s 카드 에셋 크기 부족" % cname)
		else:
			assert(str(c.get("asset_pipeline", "")) == "pixellab_combat_state", "%s 최종 에셋이 없으면 PixelLab 전투상태 파이프라인 계약이 필요" % cname)
			var slug := str(c.get("asset_pipeline_slug", ""))
			assert(not slug.strip_edges().is_empty(), "%s asset_pipeline_slug 누락" % cname)
			var stage := str(c.get("asset_pipeline_stage", ""))
			assert(["base_needed", "base_processing", "state_needed", "state_processing", "animation_needed", "animation_processing", "ready"].has(stage), "%s PixelLab 파이프라인 상태가 올바르지 않음: %s" % [cname, stage])
			assert(pixellab_queue.has(slug), "%s PixelLab manifest 큐 누락: %s" % [cname, slug])
			var queued: Dictionary = pixellab_queue[slug]
			assert(str(queued.get("name", "")) == cname, "%s PixelLab manifest 캐릭터명 불일치" % cname)
			assert(str(queued.get("stage", "")) == stage, "%s PixelLab manifest stage 불일치" % cname)
			assert(str(queued.get("output", "")) == "res://assets/sprites/%s_pl" % slug, "%s PixelLab output 경로 불일치" % cname)
			assert(str(queued.get("spec_template", "")).ends_with("%s.template.json" % slug), "%s PixelLab spec 템플릿 경로 불일치" % cname)

	var packed: PackedScene = load("res://roster.tscn")
	assert(packed != null, "roster.tscn 로드 실패")
	var inst = packed.instantiate()
	add_child(inst)
	await get_tree().process_frame
	assert(is_instance_valid(inst), "roster.tscn 인스턴스 생성 실패")
	var roster_data: Array = inst.get("roster")
	assert(roster_data.size() == defs.size(), "도감은 전체 캐릭터를 표시해야 함")
	var unlocked_count := 0
	for item in roster_data:
		if not bool(item.get("locked", true)):
			unlocked_count += 1
	assert(unlocked_count == GameState.START_UNLOCKED.size(), "새 게임 도감 해금 수가 START_UNLOCKED와 같아야 함")
	inst.queue_free()

	GameState.test_mode_no_save = false
	print("PASS character_identity roster contracts")
	get_tree().quit()
