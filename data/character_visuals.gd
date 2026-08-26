class_name CharacterVisuals
extends RefCounted

## VESPER gameplay key와 migration 자산을 연결하는 presentation manifest.
## visible_bounds와 target_height로 canvas 여백과 원본 해상도에 무관한 체격을 보장한다.

const REQUIRED_BATTLE_ANIMATIONS := ["idle", "walk", "aim", "attack", "hit", "death"]

## 현재 제출 빌드에서 카드·초상화·6종 전투 모션까지 모두 갖춘 계약자만 노출한다.
const PLAYABLE_ROSTER := ["aries", "sagittarius", "capricorn", "pisces"]

const _SPECS := {
	"aries": {
		"source_character": "",
		"asset_provenance": "AssetForge: moa-ungoo-benchmark-clips-v9",
		"sprite": "res://assets/sprites/moa_pl",
		"portrait": "res://assets/art/characters/moa/moa-identity-v2-cutout.png",
		"card_art": "res://assets/art/characters/moa/moa-identity-v2-cutout.png",
		"target_height": 2.25,
		"visible_bounds": Rect2i(4, 4, 238, 240),
		"ground_offset": 0.0,
		"face_scale": 1.0,
		"filtering": "nearest",
		"migration_only": false,
		"battle_ready": true,
		"asset_blocked": false,
		# v9는 5개 정본 클립만 제공한다. 전투 대기 상태는 idle을 고정 재생한다.
		"animation_aliases": {"aim": "idle"},
		"animation_fps": {"idle": 8.0, "walk": 12.0, "attack": 14.0, "hit": 12.0, "death": 10.0},
	},
	"sagittarius": {
		"source_character": "운구 소총수",
		"sprite": "res://assets/sprites/ungoo_rifle_pl",
		"portrait": "res://assets/art/ungoo_rifle_hero_v01.png",
		"card_art": "res://assets/art/ungoo_rifle_hero_v01.png",
		# target_height는 유지하고, 캐릭터 전체 실루엣만 균일하게 5% 키운다.
		"target_height": 2.28,
		"visual_scale": 1.05,
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
		"source_character": "Douse",
		"sprite": "res://assets/sprites/sodeungsa_pl",
		"portrait": "res://assets/art/face_sodeungsa.png",
		"card_art": "res://assets/art/card_sodeungsa.png",
		# 장총의 가로 실루엣이 크게 읽히므로 Vigil보다 작게 잡아 전열과 비율을 맞춘다.
		"target_height": 1.85,
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


static func playable_roster() -> Array[String]:
	var roster: Array[String] = []
	for def_id in PLAYABLE_ROSTER:
		roster.append(def_id)
	return roster


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


static func animation_frame_texture(def_id: String, animation: String, frame: int = 0) -> Texture2D:
	var folder := sprite_folder(def_id)
	if folder.is_empty():
		return null
	var source_animation := animation_source(def_id, animation)
	var path := "%s/%s_%d.png" % [folder, source_animation, frame]
	if not ResourceLoader.exists(path):
		return null
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path] as Texture2D


static func render_width(def_id: String, star: int = 1) -> float:
	var cache_key := "render_width:%s:%d" % [def_id, star]
	if _cache.has(cache_key):
		return float(_cache[cache_key])
	var visual := spec(def_id)
	var bounds := visual.get("visible_bounds", Rect2i(0, 0, 64, 96)) as Rect2i
	var visible_height := maxf(float(bounds.size.y), 1.0)
	var target_height := float(visual.get("target_height", 2.28))
	var frame := animation_frame_texture(def_id, "idle")
	var canvas_width := float(frame.get_width()) if frame != null else float(bounds.size.x)
	var star_scale := 1.0 + 0.08 * float(maxi(star - 1, 0))
	var width := canvas_width * target_height / visible_height \
		* star_scale * float(visual.get("visual_scale", 1.0))
	_cache[cache_key] = width
	return width


static func animation_frame_count(def_id: String, animation: String) -> int:
	var folder := sprite_folder(def_id)
	if folder.is_empty():
		return 0
	var source_animation := animation_source(def_id, animation)
	var count := 0
	while count < 64 and ResourceLoader.exists("%s/%s_%d.png" % [folder, source_animation, count]):
		count += 1
	return count


static func animation_source(def_id: String, animation: String) -> String:
	var aliases := spec(def_id).get("animation_aliases", {}) as Dictionary
	return String(aliases.get(animation, animation))


static func animation_fps(def_id: String, animation: String, fallback: float) -> float:
	var rates := spec(def_id).get("animation_fps", {}) as Dictionary
	return float(rates.get(animation, fallback))


static func missing_battle_animations(def_id: String) -> Array[String]:
	var out: Array[String] = []
	for animation in REQUIRED_BATTLE_ANIMATIONS:
		if animation_frame_count(def_id, animation) == 0:
			out.append(animation)
	return out
