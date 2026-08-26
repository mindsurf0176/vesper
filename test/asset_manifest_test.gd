extends SceneTree

## Vesper 이식 자산의 사실성을 검증한다. 미완성 캐릭터를 fallback으로 숨기지 않는다.
##   godot --headless --path . --script res://test/asset_manifest_test.gd

var passed := 0
var failed := 0


func _initialize() -> void:
	_test_manifest_shape()
	_test_vertical_slice()
	_test_completeness_is_explicit()
	_test_normalized_scale_contract()
	_test_raon_final_contract()
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	quit(1 if failed > 0 else 0)


func ok(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % label)
	else:
		failed += 1
		print("  [FAIL] %s %s" % [label, detail])


func _test_manifest_shape() -> void:
	print("[STARLINE visual manifest]")
	var ids := UnitDB.table().keys()
	var all_present := true
	for id in ids:
		all_present = all_present and CharacterVisuals.has_character(id)
	ok(ids.size() == 12 and all_present, "열두 별자리에 visual entry가 있다")

	var source_names := {}
	for id in ids:
		var source := String(CharacterVisuals.spec(id).get("source_character", ""))
		if not source.is_empty():
			source_names[source] = id
	ok(source_names.size() == 7, "Vesper migration 캐릭터 7명을 중복 없이 연결한다", str(source_names))


func _test_vertical_slice() -> void:
	print("[STARLINE 8인 vertical slice]")
	var ready := 0
	var sprite_paths_ok := true
	for id in UnitDB.table():
		if not CharacterVisuals.battle_ready(id):
			continue
		ready += 1
		var folder := CharacterVisuals.sprite_folder(id)
		sprite_paths_ok = sprite_paths_ok and not folder.is_empty()
		sprite_paths_ok = sprite_paths_ok and ResourceLoader.exists("%s/idle_0.png" % folder)
		sprite_paths_ok = sprite_paths_ok and ResourceLoader.exists("%s/walk_0.png" % folder)
		sprite_paths_ok = sprite_paths_ok and ResourceLoader.exists("%s/attack_0.png" % folder)
	ok(ready == 8 and sprite_paths_ok, "라온 final과 migration 7명이 runtime sprite를 load한다")

	var full_contract := 0
	for id in UnitDB.table():
		if CharacterVisuals.battle_ready(id) \
				and CharacterVisuals.missing_battle_animations(id).is_empty():
			full_contract += 1
	ok(full_contract == 7, "7명은 전투 6상태 계약을 완성했다", str(full_contract))
	ok(CharacterVisuals.missing_battle_animations("virgo") == ["hit", "death"],
		"처녀의 누락 clip은 hit/death로 명시된다",
		str(CharacterVisuals.missing_battle_animations("virgo")))


func _test_completeness_is_explicit() -> void:
	print("[asset completion gate]")
	var blocked := 0
	var accidental_portraits := 0
	for id in UnitDB.table():
		if CharacterVisuals.asset_blocked(id):
			blocked += 1
		if CharacterVisuals.texture(id, "portrait") != null:
			accidental_portraits += 1
	ok(blocked == 4, "미제작 4명은 asset_blocked로 남긴다", str(blocked))
	ok(accidental_portraits == 4, "실제로 존재하는 portrait만 4개 연결한다", str(accidental_portraits))


func _test_normalized_scale_contract() -> void:
	print("[normalized sprite scale]")
	var specs_complete := true
	var ready_height_in_range := true
	var foot_alignment_ok := true
	for id in UnitDB.table():
		var spec := CharacterVisuals.spec(id)
		specs_complete = specs_complete and spec.has("target_height") \
			and spec.has("visible_bounds") and spec.has("ground_offset") \
			and spec.has("face_scale") and spec.has("filtering") \
			and spec.has("migration_only")
		var bounds := spec.get("visible_bounds", Rect2i()) as Rect2i
		foot_alignment_ok = foot_alignment_ok and bounds.size.x > 0 and bounds.size.y > 0 \
			and absf(float(spec.get("ground_offset", 99.0))) <= 0.05
		if CharacterVisuals.battle_ready(id):
			var height := float(spec["target_height"])
			ready_height_in_range = ready_height_in_range and height >= 2.20 and height <= 2.55
	ok(specs_complete, "12개 visual spec이 bounds·height·foot·provenance 계약을 가진다")
	ok(ready_height_in_range, "battle-ready 인물 높이가 의도한 2.20~2.55m 범위다")
	ok(foot_alignment_ok, "모든 visual bounds가 유효하고 공통 발 기준선 오차가 작다")

	var actor_heights := []
	var runtime_foot_alignment_ok := true
	for id in UnitDB.table():
		if not CharacterVisuals.battle_ready(id):
			continue
		var d := UnitDB.get_def(id)
		var state := {
			"uid": actor_heights.size(), "def_id": id, "team": 0, "star": 1,
			"hp": d["hp"], "max_hp": d["hp"], "shield": 0.0, "engaged": false,
		}
		var actor := BattleActor3D.new()
		root.add_child(actor)
		actor.setup(state, Vector3.ZERO)
		actor_heights.append(actor.visual_height)
		var spec := CharacterVisuals.spec(id)
		var bounds := spec["visible_bounds"] as Rect2i
		var first := actor._sprite.sprite_frames.get_frame_texture("idle", 0)
		var canvas_height := float(first.get_height())
		var visible_bottom_from_center := float(bounds.end.y) - canvas_height * 0.5
		var runtime_foot_y := actor._sprite.position.y \
			- visible_bottom_from_center * actor._sprite.pixel_size
		runtime_foot_alignment_ok = runtime_foot_alignment_ok and absf(runtime_foot_y) <= 0.01
		actor.queue_free()
	var min_height: float = actor_heights.min()
	var max_height: float = actor_heights.max()
	ok(max_height / min_height <= 1.16, "runtime actor가 crop 차이 대신 설계된 체격 차이만 유지한다",
		str(actor_heights))
	ok(runtime_foot_alignment_ok, "runtime sprite의 불투명 하단이 공통 지면에 정렬된다")


func _test_raon_final_contract() -> void:
	print("[Raon final sprite]")
	var spec := CharacterVisuals.spec("aries")
	ok(not bool(spec.get("migration_only", true))
			and not bool(spec.get("asset_blocked", true))
			and String(spec.get("filtering", "")) == "linear",
		"라온은 migration이 아닌 linear-filtered final asset이다")
	var expected := {"idle": 4, "walk": 8, "aim": 4, "attack": 6, "hit": 4, "death": 6}
	var frame_counts_ok := true
	for animation in expected:
		frame_counts_ok = frame_counts_ok \
			and CharacterVisuals.animation_frame_count("aries", animation) == int(expected[animation])
	ok(frame_counts_ok, "라온은 idle 4·walk 8·aim 4·attack 6·hit 4·death 6 frame을 가진다")
	var bounds := spec["visible_bounds"] as Rect2i
	ok(bounds == Rect2i(24, 12, 214, 234),
		"라온 32 frame alpha union bounds가 정본과 일치한다", str(bounds))
	ok(CharacterVisuals.texture("aries", "portrait") != null
			and CharacterVisuals.texture("aries", "card_art") != null,
		"라온 approved face와 card cutout을 load한다")
