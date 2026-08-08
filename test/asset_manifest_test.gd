extends SceneTree

## Vesper 이식 자산의 사실성을 검증한다. 미완성 캐릭터를 fallback으로 숨기지 않는다.
##   godot --headless --path . --script res://test/asset_manifest_test.gd

var passed := 0
var failed := 0


func _initialize() -> void:
	_test_manifest_shape()
	_test_vertical_slice()
	_test_completeness_is_explicit()
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
	ok(source_names.size() == 8, "Vesper 캐릭터 8명을 중복 없이 연결한다", str(source_names))


func _test_vertical_slice() -> void:
	print("[8인 Vesper vertical slice]")
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
	ok(ready == 8 and sprite_paths_ok, "8명은 idle/walk/attack runtime sprite를 load한다")

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
