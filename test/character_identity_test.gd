extends SceneTree

## internal gameplay key와 화면에 보이는 STARLINE 캐릭터 정체성의 분리를 검증한다.
##   godot --headless --path . --script res://test/character_identity_test.gd

var passed := 0
var failed := 0

const FORBIDDEN_DISPLAY_NAMES := [
	"양", "사수", "사자", "처녀", "황소", "염소",
	"쌍둥이", "천칭", "물병", "게", "물고기", "전갈",
]


func _initialize() -> void:
	_test_cast_contract()
	_test_identity_uniqueness()
	_test_internal_keys_stay_internal()
	print("\n결과: %d 통과 / %d 실패" % [passed, failed])
	quit(1 if failed > 0 else 0)


func ok(condition: bool, label: String, detail: String = "") -> void:
	if condition:
		passed += 1
		print("  [OK] %s" % label)
	else:
		failed += 1
		print("  [FAIL] %s %s" % [label, detail])


func _test_cast_contract() -> void:
	print("[STARLINE cast]")
	var table := UnitDB.table()
	var required := [
		"name", "epithet", "true_name", "gender", "motif", "faction",
		"personality", "silhouette", "weapon", "flavor", "ability",
	]
	var complete := true
	var female := 0
	var male := 0
	for id in table:
		var d: Dictionary = table[id]
		for key in required:
			complete = complete and d.has(key) and not String(d[key]).is_empty() if key != "ability" else complete and d.has(key)
		female += 1 if String(d["gender"]) == "female" else 0
		male += 1 if String(d["gender"]) == "male" else 0
	ok(table.size() == 12 and complete, "12명 모두 캐릭터·서사·실루엣 계약을 가진다")
	ok(female == 8 and male == 4, "캐스트는 여성 8명·남성 4명이다", "%d/%d" % [female, male])


func _test_identity_uniqueness() -> void:
	print("[identity uniqueness]")
	var names := {}
	var true_names := {}
	var epithets := {}
	var weapons := {}
	var abilities := {}
	for id in UnitDB.table():
		var d := UnitDB.get_def(id)
		names[d["name"]] = true
		true_names[d["true_name"]] = true
		epithets[d["epithet"]] = true
		weapons[d["weapon"]] = true
		abilities[d["ability"]["name"]] = true
	ok(names.size() == 12 and true_names.size() == 12, "표시명과 본명이 12명 모두 중복되지 않는다")
	ok(epithets.size() == 12 and weapons.size() == 12, "호칭과 주무기가 12명 모두 중복되지 않는다")
	ok(abilities.size() == 12, "고유 능력 표시명이 12명 모두 중복되지 않는다")


func _test_internal_keys_stay_internal() -> void:
	print("[display identity boundary]")
	var forbidden := false
	var motifs_present := true
	for id in UnitDB.table():
		var d := UnitDB.get_def(id)
		for old_name in FORBIDDEN_DISPLAY_NAMES:
			forbidden = forbidden or String(d["name"]) == old_name
		motifs_present = motifs_present and not String(d["motif"]).is_empty()
	ok(not forbidden, "별자리 원명은 캐릭터 표시명으로 노출되지 않는다")
	ok(motifs_present, "별자리 원형은 제작 metadata인 motif에만 보존된다")
