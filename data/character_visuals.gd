class_name CharacterVisuals
extends RefCounted

## STARLINE gameplay key와 migration 자산을 연결하는 presentation manifest.
## visible_bounds와 target_height로 canvas 여백과 원본 해상도에 무관한 체격을 보장한다.

const REQUIRED_BATTLE_ANIMATIONS := ["idle", "walk", "aim", "attack", "hit", "death"]

const _SPECS := {
	"aries": {
		"source_character": "",
		"sprite": "res://assets/sprites/raon_codex",
		"portrait": "res://assets/art/characters/raon/raon-face-v1.png",
		"card_art": "res://assets/art/characters/raon/raon-card-cutout-v1.png",
		"target_height": 2.25,
		"visible_bounds": Rect2i(24, 12, 214, 234),
		"ground_offset": 0.0,
		"face_scale": 1.0,
		"filtering": "linear",
		"migration_only": false,
		"battle_ready": true,
		"asset_blocked": false,
	},
	"sagittarius": {
		"source_character": "운구 소총수",
		"sprite": "res://assets/sprites/ungoo_rifle_pl",
		"portrait": "res://assets/art/ungoo_rifle_hero_v01.png",
		"card_art": "res://assets/art/ungoo_rifle_hero_v01.png",
		"target_height": 2.28,
		"visible_bounds": Rect2i(38, 21, 218, 224),
		"ground_offset": 0.0,
		"face_scale": 1.0,
		"filtering": "nearest",
		"migration_only": true,
		"battle_ready": true,
	},
	"leo": {
		"source_character": "사열 돌격수",
		"sprite": "res://assets/sprites/sayeol_striker_pl",
		"portrait": "",
		"card_art": "",
		"target_height": 2.38,
		"visible_bounds": Rect2i(7, 9, 245, 234),
		"ground_offset": 0.0,
		"face_scale": 1.02,
		"filtering": "nearest",
		"migration_only": true,
		"battle_ready": true,
	},
	"virgo": {
		"source_character": "집전 의무관",
		"sprite": "res://assets/sprites/jipjeon_medic_pl",
		"portrait": "",
		"card_art": "",
		"target_height": 2.22,
		"visible_bounds": Rect2i(23, 5, 83, 116),
		"ground_offset": 0.0,
		"face_scale": 1.0,
		"filtering": "nearest",
		"migration_only": true,
		"battle_ready": true,
		"missing_animations": ["hit", "death"],
	},
	"taurus": {
		"source_character": "납골 방패병",
		"sprite": "res://assets/sprites/napgol_defender_pl",
		"portrait": "",
		"card_art": "",
		"target_height": 2.48,
		"visible_bounds": Rect2i(34, 10, 102, 244),
		"ground_offset": 0.0,
		"face_scale": 1.0,
		"filtering": "nearest",
		"migration_only": true,
		"battle_ready": true,
	},
	"capricorn": {
		"source_character": "관지기",
		"sprite": "res://assets/sprites/gwanjigi_pl",
		"portrait": "res://assets/art/face_gwanjigi.png",
		"card_art": "res://assets/art/card_gwanjigi.png",
		"target_height": 2.52,
		"visible_bounds": Rect2i(43, 16, 160, 228),
		"ground_offset": 0.0,
		"face_scale": 1.0,
		"filtering": "nearest",
		"migration_only": true,
		"battle_ready": true,
	},
	"aquarius": {
		"source_character": "망종 중계사",
		"sprite": "res://assets/sprites/mangjong_relay_pl",
		"portrait": "",
		"card_art": "",
		"target_height": 2.30,
		"visible_bounds": Rect2i(38, 6, 169, 225),
		"ground_offset": 0.0,
		"face_scale": 1.0,
		"filtering": "nearest",
		"migration_only": true,
		"battle_ready": true,
	},
	"pisces": {
		"source_character": "소등사",
		"sprite": "res://assets/sprites/sodeungsa_pl",
		"portrait": "res://assets/art/face_sodeungsa.png",
		"card_art": "res://assets/art/card_sodeungsa.png",
		"target_height": 2.26,
		"visible_bounds": Rect2i(0, 46, 256, 184),
		"ground_offset": 0.0,
		"face_scale": 1.0,
		"filtering": "nearest",
		"migration_only": true,
		"battle_ready": true,
	},
	"gemini": {
		"source_character": "", "sprite": "", "portrait": "", "card_art": "",
		"target_height": 2.25, "visible_bounds": Rect2i(0, 0, 64, 96),
		"ground_offset": 0.0, "face_scale": 1.0, "filtering": "nearest",
		"migration_only": false, "battle_ready": false, "asset_blocked": true,
	},
	"libra": {
		"source_character": "", "sprite": "", "portrait": "", "card_art": "",
		"target_height": 2.28, "visible_bounds": Rect2i(0, 0, 64, 96),
		"ground_offset": 0.0, "face_scale": 1.0, "filtering": "nearest",
		"migration_only": false, "battle_ready": false, "asset_blocked": true,
	},
	"cancer": {
		"source_character": "", "sprite": "", "portrait": "", "card_art": "",
		"target_height": 2.42, "visible_bounds": Rect2i(0, 0, 64, 96),
		"ground_offset": 0.0, "face_scale": 1.0, "filtering": "nearest",
		"migration_only": false, "battle_ready": false, "asset_blocked": true,
	},
	"scorpio": {
		"source_character": "", "sprite": "", "portrait": "", "card_art": "",
		"target_height": 2.32, "visible_bounds": Rect2i(0, 0, 64, 96),
		"ground_offset": 0.0, "face_scale": 1.0, "filtering": "nearest",
		"migration_only": false, "battle_ready": false, "asset_blocked": true,
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
