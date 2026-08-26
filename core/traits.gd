class_name Traits
extends RefCounted

## 분대 연계. 플레이어가 기억할 규칙은 한 줄이다 —
## **같은 전술 계통을 모으면 세진다. 셋을 다 모으면 연계가 완성된다.**
##
## 역할(근접·원거리·방어·지원)은 상성만 담당하고 시너지에는 관여하지 않는다.
## 둘 다 시너지를 주면 효과가 겹쳐서 규칙만 늘고 이해할 것이 두 배가 된다.
##
## 같은 계약자는 한 계통으로만 센다.
## 계통당 계약자가 셋이므로 최대 단계는 3이다.

const TRINE := 3

const ELEMENT_TIERS := {
	Defs.Element.FIRE: [
		{"n": 2, "atk_mult": 1.18},
		{"n": 3, "atk_mult": 1.40},
	],
	Defs.Element.EARTH: [
		{"n": 2, "hp_mult": 1.18, "armor_add": 22.0},
		{"n": 3, "hp_mult": 1.40, "armor_add": 50.0},
	],
	Defs.Element.AIR: [
		{"n": 2, "as_mult": 1.22},
		{"n": 3, "as_mult": 1.48},
	],
	Defs.Element.WATER: [
		{"n": 2, "team_regen": 0.012},
		{"n": 3, "team_regen": 0.025},
	],
}

var element_counts: Dictionary = {}  ## Element -> 고유 계약자 수
var active: Array = []               ## [{key, name, count, tier_n, is_trine, effects}]
var team_regen: float = 0.0
var gold_bonus: int = 0              ## 지금은 쓰지 않는다. 정산 쪽 호환을 위해 남긴다.

var _element_eff: Dictionary = {}    ## Element -> effects


## placements: [{def_id, star, order}] — 출격 큐에 올라간 계약자만 넘길 것.
static func evaluate(placements: Array) -> Traits:
	var t := Traits.new()
	var seen := {}
	for p in placements:
		var def_id: String = p["def_id"]
		if seen.has(def_id):
			continue
		seen[def_id] = true
		var e: int = UnitDB.get_def(def_id)["element"]
		t.element_counts[e] = int(t.element_counts.get(e, 0)) + 1

	for e in t.element_counts:
		var count: int = t.element_counts[e]
		var eff := _highest_tier(ELEMENT_TIERS.get(e, []), count)
		if eff.is_empty():
			continue
		t._element_eff[e] = eff
		t.team_regen += float(eff.get("team_regen", 0.0))
		t.active.append({
			"key": e, "name": Defs.ELEMENT_NAMES[e], "count": count,
			"tier_n": eff["n"], "is_trine": int(eff["n"]) >= TRINE, "effects": eff,
		})
	t.active.sort_custom(func(a, b): return int(a["count"]) > int(b["count"]))
	return t


static func _highest_tier(tiers: Array, count: int) -> Dictionary:
	var best := {}
	for tier in tiers:
		if count >= int(tier["n"]):
			best = tier
	return best


## 계약자 한 명에게 적용될 최종 보정치. sim이 생성 시 한 번 호출한다.
func mods_for(def_id: String) -> Dictionary:
	var e: int = UnitDB.get_def(def_id)["element"]
	var eff: Dictionary = _element_eff.get(e, {})
	return {
		"atk_mult": float(eff.get("atk_mult", 1.0)),
		"as_mult": float(eff.get("as_mult", 1.0)),
		"hp_mult": float(eff.get("hp_mult", 1.0)),
		"armor_add": float(eff.get("armor_add", 0.0)),
	}


func describe() -> String:
	if active.is_empty():
		return "아직 연계된 계통이 없다"
	var parts: PackedStringArray = []
	for a in active:
		if bool(a["is_trine"]):
			parts.append("%s 연계 완성" % a["name"])
		else:
			parts.append("%s %d" % [a["name"], a["count"]])
	return ", ".join(parts)
