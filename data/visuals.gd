class_name StarVisuals
extends RefCounted

## 준비 화면과 전투 화면이 공유하는 계통·역할 비주얼 레지스트리.

const STAR_LINE := {
	"aries": preload("res://assets/stars/aries_line.png"),
	"taurus": preload("res://assets/stars/taurus_line.png"),
	"gemini": preload("res://assets/stars/gemini_line.png"),
	"cancer": preload("res://assets/stars/cancer_line.png"),
	"leo": preload("res://assets/stars/leo_line.png"),
	"virgo": preload("res://assets/stars/virgo_line.png"),
	"libra": preload("res://assets/stars/libra_line.png"),
	"scorpio": preload("res://assets/stars/scorpio_line.png"),
	"sagittarius": preload("res://assets/stars/sagittarius_line.png"),
	"capricorn": preload("res://assets/stars/capricorn_line.png"),
	"aquarius": preload("res://assets/stars/aquarius_line.png"),
	"pisces": preload("res://assets/stars/pisces_line.png"),
}

const STAR_NODE := {
	"aries": preload("res://assets/stars/aries_node.png"),
	"taurus": preload("res://assets/stars/taurus_node.png"),
	"gemini": preload("res://assets/stars/gemini_node.png"),
	"cancer": preload("res://assets/stars/cancer_node.png"),
	"leo": preload("res://assets/stars/leo_node.png"),
	"virgo": preload("res://assets/stars/virgo_node.png"),
	"libra": preload("res://assets/stars/libra_node.png"),
	"scorpio": preload("res://assets/stars/scorpio_node.png"),
	"sagittarius": preload("res://assets/stars/sagittarius_node.png"),
	"capricorn": preload("res://assets/stars/capricorn_node.png"),
	"aquarius": preload("res://assets/stars/aquarius_node.png"),
	"pisces": preload("res://assets/stars/pisces_node.png"),
}

const ELEMENT_ICON := {
	Defs.Element.FIRE: preload("res://assets/icons/elem_fire.png"),
	Defs.Element.EARTH: preload("res://assets/icons/elem_earth.png"),
	Defs.Element.AIR: preload("res://assets/icons/elem_air.png"),
	Defs.Element.WATER: preload("res://assets/icons/elem_water.png"),
}

const ROLE_ICON := {
	Defs.Role.STRIKER: preload("res://assets/icons/role_striker.png"),
	Defs.Role.RANGER: preload("res://assets/icons/role_ranger.png"),
	Defs.Role.DEFENDER: preload("res://assets/icons/role_defender.png"),
	Defs.Role.SUPPORT: preload("res://assets/icons/role_support.png"),
}

const TEAM_COLOR := [Color("6ec8f0"), Color("f2909f")]
const ELEMENT_COLOR := {
	Defs.Element.FIRE: Color("ff9a6c"),
	Defs.Element.EARTH: Color("9dd6a0"),
	Defs.Element.AIR: Color("c9b6f5"),
	Defs.Element.WATER: Color("7fd4e8"),
}

const ROLE_SHADE := {
	Defs.Role.STRIKER: 1.0,
	Defs.Role.RANGER: 0.82,
	Defs.Role.DEFENDER: 0.66,
	Defs.Role.SUPPORT: 1.15,
}


static func tier_color(tier: int) -> Color:
	match tier:
		1: return Color("7380a8")
		2: return Color("72c79c")
		3: return Color("9a85e8")
		_: return Color("e9bd68")
