extends Control
## 회랑의 망자들 — 캐릭터 도감/카드 화면.
## 캐릭터 원본은 GameState.ALL_CHARS. 도감은 데이터 계약을 읽어 자동 구성한다.

const AMBER := Color(1.0, 0.74, 0.36)
const COLD := Color(0.36, 0.86, 0.92)
const WHITE := Color(0.95, 0.93, 0.88)
const MUTED := Color(0.66, 0.72, 0.76)
const LOCKED := Color(0.28, 0.31, 0.35)

var font: Font
var roster: Array = []

func _ready() -> void:
	font = load("res://assets/Galmuri11.ttf")
	roster = _build_roster()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.082, 0.10, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_label("회랑의 망자들 · 캐릭터 도감", Vector2(0, 30), 1280, 30, AMBER, HORIZONTAL_ALIGNMENT_CENTER, 500)
	_label("전투명 · 본명 · 소속 · 대사 · 일러스트 브리프까지 런타임 계약으로 관리", Vector2(0, 70), 1280, 15, Color(0.7, 0.78, 0.82), HORIZONTAL_ALIGNMENT_CENTER)

	var found := 0
	for r in roster:
		if not bool(r["locked"]):
			found += 1
	_label("수집 %d / %d" % [found, roster.size()], Vector2(0, 92), 1280, 16, Color(0.78, 0.82, 0.84), HORIZONTAL_ALIGNMENT_CENTER)

	var cols := 4
	var cw := 270.0
	var ch := 250.0
	var gap_x := 24.0
	var gap_y := 22.0
	var total_w := float(cols) * cw + float(cols - 1) * gap_x
	var sx := (1280.0 - total_w) * 0.5
	var sy := 122.0
	for i in roster.size():
		var col_idx := i % cols
		var row_idx := int(i / cols)
		_make_card(roster[i], Vector2(sx + float(col_idx) * (cw + gap_x), sy + float(row_idx) * (ch + gap_y)), Vector2(cw, ch))

	var close := Button.new()
	close.text = "닫기"
	close.position = Vector2(1280 - 130, 28)
	close.size = Vector2(100, 44)
	_btn_style(close, Color(0.2, 0.28, 0.32))
	close.pressed.connect(_on_close)
	add_child(close)

	if "--shot" in OS.get_cmdline_user_args():
		_shoot()

func _build_roster() -> Array:
	var out := []
	for c in GameState.all_chars_list():
		var cname := str(c.get("name", ""))
		var visual: Dictionary = c.get("visual", {})
		var col: Color = visual.get("primary", AMBER)
		var tex := str(c.get("card_art", ""))
		if tex == "" or not ResourceLoader.exists(tex):
			tex = ""
		out.append({
			"name": cname,
			"true_name": str(c.get("true_name", cname)),
			"epithet": str(c.get("epithet", "")),
			"sub": str(c.get("epithet", "")),
			"type": _type_label(int(c.get("type", GameState.STRIKER))),
			"rarity": str(c.get("rarity", _rarity_for(cname))),
			"faction": str(c.get("faction", "")),
			"col": col,
			"accent": visual.get("accent", COLD),
			"mark": str(visual.get("mark", "?")),
			"shape": str(visual.get("shape", "")),
			"lore": str(c.get("lore", "")),
			"role": str(c.get("role", "")),
			"cost": int(c.get("cost", 0)),
			"skill": _skill_summary(cname),
			"quote": str(c.get("quote", "")),
			"bond_lines": c.get("bond_lines", []),
			"visual_brief": str(c.get("visual_brief", "")),
			"tex": tex,
			"locked": not GameState.unlocked.has(cname),
		})
	return out

func _rarity_for(cname: String) -> String:
	for item in GameState.GACHA_POOL:
		if str(item.get("name", "")) == cname:
			return str(item.get("rarity", "R"))
	return "R"

func _type_label(t: int) -> String:
	match t:
		GameState.STRIKER:
			return "스트라이커"
		GameState.RANGER:
			return "레인저"
		GameState.DEFENDER:
			return "디펜더"
		GameState.SNIPER:
			return "스나이퍼"
		GameState.SUPPORT:
			return "서포터"
	return "미상"

func _skill_summary(cname: String) -> String:
	var skills: Dictionary = GameState.ORB_SKILLS.get(cname, {})
	if skills.is_empty():
		return "오브 스킬 미등록"
	var parts := []
	for key in ["1", "2", "4"]:
		if skills.has(key):
			parts.append("%s오브 · %s" % [key, str(skills[key].get("label", ""))])
	return " / ".join(parts)

func _on_close() -> void:
	var p := get_parent()
	if p is CanvasLayer:
		p.queue_free()
	else:
		queue_free()

func _label(text: String, pos: Vector2, w: float, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, weight := -1) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = Vector2(w, fs + 8)
	l.horizontal_alignment = align
	if weight > 0:
		l.add_theme_constant_override("outline_size", 0)
	add_child(l)
	return l

func _make_card(def: Dictionary, pos: Vector2, size: Vector2) -> void:
	var col: Color = def["col"]
	var locked: bool = def["locked"]

	var panel := Panel.new()
	panel.position = pos
	panel.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.13, 0.16) if not locked else Color(0.07, 0.09, 0.11)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = col if not locked else Color(0.2, 0.23, 0.26)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var strip := ColorRect.new()
	strip.color = Color(col.r, col.g, col.b, 0.85 if not locked else 0.25)
	strip.position = Vector2(2, 2)
	strip.size = Vector2(size.x - 4, 6)
	panel.add_child(strip)

	var art_h := size.y - 92.0
	var holder := Control.new()
	holder.position = Vector2(8, 12)
	holder.size = Vector2(size.x - 16, art_h)
	holder.clip_contents = true
	panel.add_child(holder)

	_draw_card_art(holder, def, locked)

	var name_l := Label.new()
	name_l.text = "???" if locked else str(def["true_name"])
	name_l.add_theme_font_override("font", font)
	name_l.add_theme_font_size_override("font_size", 21)
	name_l.add_theme_color_override("font_color", WHITE if not locked else Color(0.5, 0.53, 0.57))
	name_l.position = Vector2(14, size.y - 76)
	name_l.size = Vector2(size.x - 28, 28)
	panel.add_child(name_l)

	var badge := _badge("%s · %s" % [str(def["rarity"]), str(def["type"])], col if not locked else Color(0.3, 0.33, 0.36))
	badge.position = Vector2(14, size.y - 46)
	badge.add_theme_font_size_override("font_size", 12)
	panel.add_child(badge)

	var sub := Label.new()
	sub.text = "미발견" if locked else "%s · %s" % [str(def["name"]), str(def["epithet"])]
	sub.add_theme_font_override("font", font)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.65, 0.7, 0.74) if not locked else Color(0.38, 0.42, 0.46))
	sub.position = Vector2(112, size.y - 43)
	sub.size = Vector2(size.x - 126, 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(sub)

	if not locked:
		var hit := Button.new()
		hit.flat = true
		hit.position = Vector2.ZERO
		hit.size = size
		hit.pressed.connect(_show_detail.bind(def))
		panel.add_child(hit)

func _draw_card_art(holder: Control, def: Dictionary, locked: bool) -> void:
	var col: Color = def["col"]
	var accent: Color = def.get("accent", COLD)
	if not locked and str(def["tex"]) != "" and ResourceLoader.exists(str(def["tex"])):
		var tr := TextureRect.new()
		tr.texture = load(str(def["tex"]))
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(tr)
		return

	var bg := ColorRect.new()
	bg.color = Color(col.r * 0.18, col.g * 0.18, col.b * 0.18, 0.88) if not locked else Color(0.075, 0.09, 0.105, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)

	var halo := ColorRect.new()
	halo.color = Color(accent.r, accent.g, accent.b, 0.20 if not locked else 0.08)
	halo.position = Vector2(holder.size.x * 0.18, holder.size.y * 0.18)
	halo.size = Vector2(holder.size.x * 0.64, holder.size.y * 0.64)
	holder.add_child(halo)

	var mark := Label.new()
	mark.text = "?" if locked else str(def["mark"])
	mark.add_theme_font_override("font", font)
	mark.add_theme_font_size_override("font_size", 72)
	mark.add_theme_color_override("font_color", Color(col.r, col.g, col.b, 0.72) if not locked else LOCKED)
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(mark)

	if not locked:
		var shape := Label.new()
		shape.text = str(def["shape"]).to_upper()
		shape.add_theme_font_override("font", font)
		shape.add_theme_font_size_override("font_size", 13)
		shape.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.75))
		shape.position = Vector2(12, holder.size.y - 28)
		shape.size = Vector2(holder.size.x - 24, 20)
		shape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(shape)

func _btn_style(b: Button, base: Color) -> void:
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = base
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	var sh := sb.duplicate()
	sh.bg_color = base.lightened(0.12)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.93))

func _show_detail(def: Dictionary) -> void:
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.08, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(bg)

	var col: Color = def["col"]
	var art_panel := Panel.new()
	art_panel.position = Vector2(36, 34)
	art_panel.size = Vector2(540, 652)
	var aps := StyleBoxFlat.new()
	aps.bg_color = Color(0.07, 0.10, 0.12)
	aps.set_corner_radius_all(16)
	aps.set_border_width_all(2)
	aps.border_color = col
	art_panel.add_theme_stylebox_override("panel", aps)
	ov.add_child(art_panel)

	var art_holder := Control.new()
	art_holder.position = Vector2(18, 18)
	art_holder.size = Vector2(504, 616)
	art_holder.clip_contents = true
	art_panel.add_child(art_holder)
	_draw_card_art(art_holder, def, false)

	var rx := 628.0
	var bar := ColorRect.new()
	bar.color = col
	bar.position = Vector2(rx, 58)
	bar.size = Vector2(6, 88)
	ov.add_child(bar)

	_d(ov, str(def["true_name"]), Vector2(rx + 22, 48), 580, 42, WHITE)
	_d(ov, "%s · %s" % [str(def["name"]), str(def["epithet"])], Vector2(rx + 24, 104), 580, 18, MUTED)
	_d(ov, str(def["faction"]), Vector2(rx + 24, 130), 580, 16, Color(0.70, 0.75, 0.78))

	var badge := _badge("%s · %s" % [str(def["rarity"]), str(def["type"])], col)
	badge.position = Vector2(rx + 24, 166)
	ov.add_child(badge)
	_d(ov, "코스트 %d" % int(def.get("cost", 0)), Vector2(rx + 194, 170), 200, 16, COLD)

	_para(ov, "“%s”" % str(def.get("quote", "")), Vector2(rx + 24, 212), 580, 17, Color(0.88, 0.86, 0.78), 54)
	_d(ov, "전투 역할", Vector2(rx + 24, 282), 200, 16, col)
	_para(ov, str(def.get("role", "")), Vector2(rx + 24, 306), 580, 16, Color(0.84, 0.87, 0.88), 42)

	_d(ov, "기록", Vector2(rx + 24, 360), 200, 16, col)
	_para(ov, str(def.get("lore", "")), Vector2(rx + 24, 384), 580, 15, Color(0.78, 0.82, 0.85), 86)

	_d(ov, "오브 스킬", Vector2(rx + 24, 482), 200, 16, col)
	_para(ov, str(def.get("skill", "")), Vector2(rx + 24, 506), 580, 15, Color(0.82, 0.86, 0.88), 42)

	_d(ov, "일러스트 브리프", Vector2(rx + 24, 558), 200, 16, col)
	_para(ov, str(def.get("visual_brief", "")), Vector2(rx + 24, 582), 580, 14, Color(0.74, 0.78, 0.80), 58)

	var bonds: Array = def.get("bond_lines", [])
	if not bonds.is_empty():
		_para(ov, " / ".join(bonds), Vector2(rx + 24, 646), 420, 13, Color(0.66, 0.72, 0.75), 38)

	var back := Button.new()
	back.text = "← 뒤로"
	back.position = Vector2(1104, 626)
	back.size = Vector2(128, 46)
	_btn_style(back, Color(0.2, 0.28, 0.32))
	back.pressed.connect(ov.queue_free)
	ov.add_child(back)

func _d(parent: Node, text: String, pos: Vector2, w: float, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = Vector2(w, fs + 12)
	parent.add_child(l)
	return l

func _para(parent: Node, text: String, pos: Vector2, w: float, fs: int, col: Color, h := 120.0) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.size = Vector2(w, h)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)

func _badge(text: String, col: Color) -> Label:
	var b := Label.new()
	b.text = "  " + text + "  "
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color(0.06, 0.09, 0.11))
	var bs := StyleBoxFlat.new()
	bs.bg_color = col
	bs.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", bs)
	b.size = Vector2(160, 26)
	return b

func _shoot() -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("/tmp/vesper_roster.png")
	get_tree().quit()
