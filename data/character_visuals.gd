class_name CharacterVisuals
extends RefCounted

## STARLINE 별자리와 Vesper 제작 자산을 연결하는 presentation manifest.
## battle_ready와 portrait/card completeness를 분리해 미완성 자산을 final로 오인하지 않는다.

const REQUIRED_BATTLE_ANIMATIONS := ["idle", "walk", "aim", "attack", "hit", "death"]

const _SPECS := {
	"aries": {
		"source_character": "진혼병",
		"sprite": "res://assets/sprites/jinhonbyeong_pl",
		"portrait": "res://assets/art/jinhonbyeong_hero_v01.png",
		"card_art": "res://assets/art/jinhonbyeong_hero_v01.png",
		"sps": 0.0081,
		"tight": true,
		"battle_ready": true,
	},
	"sagittarius": {
		"source_character": "운구 소총수",
		"sprite": "res://assets/sprites/ungoo_rifle_pl",
		"portrait": "res://assets/art/ungoo_rifle_hero_v01.png",
		"card_art": "res://assets/art/ungoo_rifle_hero_v01.png",
		"sps": 0.0081,
		"tight": true,
		"battle_ready": true,
	},
	"leo": {
		"source_character": "사열 돌격수",
		"sprite": "res://assets/sprites/sayeol_striker_pl",
		"portrait": "",
		"card_art": "",
		"sps": 0.0081,
		"tight": true,
		"battle_ready": true,
	},
	"virgo": {
		"source_character": "집전 의무관",
		"sprite": "res://assets/sprites/jipjeon_medic_pl",
		"portrait": "",
		"card_art": "",
		"sps": 0.0063,
		"tight": true,
		"battle_ready": true,
		"missing_animations": ["hit", "death"],
	},
	"taurus": {
		"source_character": "납골 방패병",
		"sprite": "res://assets/sprites/napgol_defender_pl",
		"portrait": "",
		"card_art": "",
		"sps": 0.0081,
		"tight": true,
		"battle_ready": true,
	},
	"capricorn": {
		"source_character": "관지기",
		"sprite": "res://assets/sprites/gwanjigi_pl",
		"portrait": "res://assets/art/face_gwanjigi.png",
		"card_art": "res://assets/art/card_gwanjigi.png",
		"sps": 0.0266,
		"tight": false,
		"battle_ready": true,
	},
	"aquarius": {
		"source_character": "망종 중계사",
		"sprite": "res://assets/sprites/mangjong_relay_pl",
		"portrait": "",
		"card_art": "",
		"sps": 0.0081,
		"tight": true,
		"battle_ready": true,
	},
	"pisces": {
		"source_character": "소등사",
		"sprite": "res://assets/sprites/sodeungsa_pl",
		"portrait": "res://assets/art/face_sodeungsa.png",
		"card_art": "res://assets/art/card_sodeungsa.png",
		"sps": 0.0266,
		"tight": false,
		"battle_ready": true,
	},
	"gemini": {
		"source_character": "",
		"sprite": "",
		"portrait": "",
		"card_art": "",
		"battle_ready": false,
		"asset_blocked": true,
	},
	"libra": {
		"source_character": "",
		"sprite": "",
		"portrait": "",
		"card_art": "",
		"battle_ready": false,
		"asset_blocked": true,
	},
	"cancer": {
		"source_character": "",
		"sprite": "",
		"portrait": "",
		"card_art": "",
		"battle_ready": false,
		"asset_blocked": true,
	},
	"scorpio": {
		"source_character": "",
		"sprite": "",
		"portrait": "",
		"card_art": "",
		"battle_ready": false,
		"asset_blocked": true,
	},
}

static var _cache: Dictionary = {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	for id in UnitDB.table():
		out.append(id)
	return out


static func has_character(def_id: String) -> bool:
	return _SPECS.has(def_id)


static func spec(def_id: String) -> Dictionary:
	assert(_SPECS.has(def_id), "unknown visual: %s" % def_id)
	var out: Dictionary = _SPECS[def_id].duplicate(true)
	out["def_id"] = def_id
	out["element"] = UnitDB.get_def(def_id)["element"]
	out["role"] = UnitDB.get_def(def_id)["role"]
	return out


static func battle_ready(def_id: String) -> bool:
	return bool(spec(def_id).get("battle_ready", false))


static func asset_blocked(def_id: String) -> bool:
	return bool(spec(def_id).get("asset_blocked", false))


static func sprite_folder(def_id: String) -> String:
	return String(spec(def_id).get("sprite", ""))


static func texture(def_id: String, key: String) -> Texture2D:
	var path := String(spec(def_id).get(key, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path] as Texture2D


static func animation_frame_count(def_id: String, animation: String) -> int:
	var folder := sprite_folder(def_id)
	if folder.is_empty():
		return 0
	var count := 0
	while count < 64 and ResourceLoader.exists("%s/%s_%d.png" % [folder, animation, count]):
		count += 1
	return count


static func missing_battle_animations(def_id: String) -> Array[String]:
	var out: Array[String] = []
	for animation in REQUIRED_BATTLE_ANIMATIONS:
		if animation_frame_count(def_id, animation) == 0:
			out.append(animation)
	return out
