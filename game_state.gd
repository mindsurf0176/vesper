extends Node
## 게임 전역 상태 — 진행/해금/편성/세이브. 오토로드 'GameState'.
## 전투(battle3d)는 여기서 스테이지 웨이브·적 정의·편성 덱을 읽어간다.

const SAVE_PATH := "user://vesper_save.json"
const SQUAD_MAX := 8
const ALLY_CORE_HP := 1000.0
const SHIP_CONTRACT := {
	"id": "lantern_ark",
	"name": "등불함",
	"hp": ALLY_CORE_HP,
	"leader_cost_discount": 1.0,
	"command_skill": {
		"label": "등불함 포격",
		"cooldown": 18.0,
		"damage": 48.0,
		"push": 0.0,
		"target_side_x": 0.0,
	},
	"last_stand": {
		"label": "최후 신호",
		"threshold": 0.25,
		"floor": 0.20,
		"auto_barrier": 2.5,
		"barrier": 4.0,
		"cooldown": 8.0,
		"damage": 28.0,
		"push": 4.2,
	},
}

const GACHA_PITY_LIMIT := 20
const GACHA_SINGLE_LUMEN := 160
const GACHA_TEN_LUMEN := 1600
const GACHA_POOL := [
	{ "id":"jin", "name":"진혼병", "rarity":"R", "weight":180 },
	{ "id":"rifle", "name":"운구 소총수", "rarity":"R", "weight":180 },
	{ "id":"medic", "name":"집전 의무관", "rarity":"R", "weight":180 },
	{ "id":"gwan", "name":"관지기", "rarity":"SR", "weight":90 },
	{ "id":"parade", "name":"사열 돌격수", "rarity":"SR", "weight":90 },
	{ "id":"relay", "name":"망종 중계사", "rarity":"SR", "weight":90 },
	{ "id":"sniper", "name":"소등사", "rarity":"SSR", "weight":30 },
	{ "id":"ossuary", "name":"납골 방패병", "rarity":"SSR", "weight":30 },
]
const SHOP_PACKS := [
	{ "id":"starter", "title":"초회 등불 보급", "price_label":"₩1,100 테스트", "limit":1,
	  "desc":"첫 결제 전환용 저가 팩 목업. 실제 결제 SDK는 미연동.",
	  "rewards": { "lumen":600, "recruit_tickets":3, "gold":5000 } },
	{ "id":"monthly", "title":"월정액 성가대 후원", "price_label":"₩5,900 테스트", "limit":1,
	  "desc":"30일 접속 리텐션 상품 목업. 현재는 즉시 보상만 지급.",
	  "rewards": { "lumen":1200, "recruit_tickets":5, "gold":12000 } },
	{ "id":"ad_supply", "title":"광고 보급 상자", "price_label":"광고 시청 목업", "limit":99,
	  "desc":"보상형 광고 수익 구조 목업. 실제 광고 SDK는 미연동.",
	  "rewards": { "recruit_tickets":1, "gold":1500 } },
]
const CHAT_SEED := [
	{ "speaker":"성가대", "text":"등불함 접속 확인. 오늘도 이름을 아껴라.", "system":true },
	{ "speaker":"관지기", "text":"전열이 무너지면 후열은 오래 못 버틴다.", "system":true },
	{ "speaker":"소등사", "text":"매듭의 빛이 흔들리는 순간을 기다린다.", "system":true },
]
const CHARACTER_MAX_LEVEL := 20
const BATTLE_PASS_XP_PER_LEVEL := 100
const MAIL_SEED := [
	{ "id":"launch_gift", "from":"성가대", "title":"출항 보급", "body":"첫 지휘실 개방 보상입니다. 모집과 성장을 한 번씩 만져볼 수 있게 지급합니다.",
	  "rewards": { "lumen":300, "gold":6000, "recruit_tickets":2 } },
	{ "id":"maintenance_001", "from":"등불함 정비반", "title":"회랑 안정화 보상", "body":"전투/메타 연결 테스트 보상입니다. 실제 서비스에서는 점검 보상 슬롯으로 사용합니다.",
	  "rewards": { "lumen":120, "gold":2500 } },
	{ "id":"director_letter", "from":"개발실", "title":"개발자 편지", "body":"현재 결제와 광고는 목업입니다. 출시 전 영수증 검증과 서버 권한 검증이 필요합니다.",
	  "rewards": { "brand_points":1, "account_xp":60 } },
]
const MISSION_DEFS := [
	{ "id":"daily_login", "category":"일일", "title":"등불함 점검", "desc":"오늘 출석 보상을 1회 수령", "kind":"daily_counter", "counter":"login", "target":1,
	  "rewards": { "gold":1200 }, "pass_xp":30, "account_xp":20 },
	{ "id":"daily_recruit", "category":"일일", "title":"망자 호출", "desc":"오늘 모집 1회 진행", "kind":"daily_counter", "counter":"gacha", "target":1,
	  "rewards": { "gold":1500 }, "pass_xp":35, "account_xp":20 },
	{ "id":"daily_chat", "category":"일일", "title":"회랑 통신", "desc":"오늘 채팅 메시지 1회 전송", "kind":"daily_counter", "counter":"chat", "target":1,
	  "rewards": { "lumen":40 }, "pass_xp":25, "account_xp":15 },
	{ "id":"daily_battle", "category":"일일", "title":"회랑 출격", "desc":"오늘 전투 결과 1회 기록", "kind":"daily_counter", "counter":"battle", "target":1,
	  "rewards": { "gold":2000 }, "pass_xp":40, "account_xp":25 },
	{ "id":"achieve_first_clear", "category":"업적", "title":"첫 문 개방", "desc":"스테이지 1개 클리어", "kind":"clear_count", "target":1,
	  "rewards": { "lumen":120, "brand_points":1 }, "pass_xp":60, "account_xp":40 },
	{ "id":"achieve_collect_6", "category":"업적", "title":"여섯 이름의 명단", "desc":"캐릭터 6명 보유", "kind":"owned_count", "target":6,
	  "rewards": { "recruit_tickets":2, "gold":3000 }, "pass_xp":80, "account_xp":60 },
	{ "id":"achieve_growth", "category":"업적", "title":"망자의 단련", "desc":"캐릭터 레벨업 1회", "kind":"upgrade_count", "target":1,
	  "rewards": { "lumen":80, "gold":2000 }, "pass_xp":60, "account_xp":40 },
	{ "id":"achieve_shop", "category":"업적", "title":"보급선 확인", "desc":"상점/광고 목업 보상 1회 수령", "kind":"shop_event_count", "target":1,
	  "rewards": { "lumen":60 }, "pass_xp":45, "account_xp":30 },
]
const BATTLE_PASS_TRACK := [
	{ "level":1, "title":"회랑 패스 1", "rewards": { "gold":3000 } },
	{ "level":2, "title":"회랑 패스 2", "rewards": { "lumen":120 } },
	{ "level":3, "title":"회랑 패스 3", "rewards": { "recruit_tickets":2 } },
	{ "level":4, "title":"회랑 패스 4", "rewards": { "gold":6000, "brand_points":1 } },
	{ "level":5, "title":"회랑 패스 5", "rewards": { "lumen":240, "recruit_tickets":3 } },
]
const TERMS_VERSION := "local-ops-001"
const DEFAULT_SETTINGS := {
	"master_volume": 1.0,
	"bgm_volume": 0.8,
	"sfx_volume": 0.9,
	"vibration": true,
	"reduced_motion": false,
	"fps_60": true,
	"safe_area": true,
}
const NOTICE_FEED := [
	{ "id":"notice_launch", "category":"공지", "title":"로컬 출시 후보 빌드",
	  "body":"현재 빌드는 전투, 모집, 상점, 채팅, 미션, 우편, 성장, 패스를 로컬 저장으로 검증합니다." },
	{ "id":"notice_iap_mock", "category":"중요", "title":"결제/광고 목업 안내",
	  "body":"상점의 가격과 광고 보상은 테스트 지급입니다. 실제 출시 전 결제 SDK, 광고 SDK, 영수증 검증, 서버 권한 검증이 필요합니다." },
	{ "id":"notice_balance", "category":"개발노트", "title":"밸런스는 후순위",
	  "body":"현재 목표는 게임 설계적 완성입니다. 세부 수치, 변종 난이도, PvP/랭킹은 이후 조정합니다." },
]
const TUTORIAL_TOPICS := [
	{ "id":"battle_core", "title":"전투 기본", "steps":[
		"좌측 등불함을 지키며 우측 매듭을 파괴하면 승리합니다.",
		"하단 카드로 망자를 배치하고, 코스트가 부족하면 기다리거나 소신을 사용합니다.",
		"ST4 이후에는 배치 가능 영역 안을 직접 눌러 전열 위치를 잡습니다.",
	] },
	{ "id":"orb_command", "title":"오브 커맨드", "steps":[
		"같은 색 인접 오브를 1/2/4개 선택해 해당 역할의 캐릭터 스킬을 발동합니다.",
		"많은 오브를 연결할수록 더 강한 스킬이 나가지만, 다음 패턴이 막힐 수 있습니다.",
	] },
	{ "id":"soshin", "title":"소신과 최후 신호", "steps":[
		"소신은 등불함 HP를 태워 코스트를 즉시 만듭니다.",
		"과도한 소신은 재의 사도를 부르므로 위기 탈출용으로 제한해야 합니다.",
		"등불함 HP가 낮으면 최후 신호로 보호막과 밀어내기를 사용할 수 있습니다.",
	] },
	{ "id":"mobile_meta", "title":"모바일 메타", "steps":[
		"출석, 모집, 상점, 채팅, 전투, 성장은 미션과 패스 XP에 연결됩니다.",
		"우편과 패스 보상은 중복 수령이 막히며 세이브에 저장됩니다.",
		"상점은 실제 결제가 아니라 수익 구조 검증용 목업입니다.",
	] },
]
const CREDITS := [
	{ "role":"기획/구현", "name":"베스퍼 회랑 로컬 프로토타입" },
	{ "role":"엔진", "name":"Godot 4.6" },
	{ "role":"게임 방향", "name":"카운터사이드식 라인 전투 + 스도리카식 오브 커맨드 융합" },
	{ "role":"현재 범위", "name":"실제 서버/결제/광고 없이 로컬 출시 후보 계약 검증" },
]
const FEEDBACK_EVENTS := {
	"navigate": { "label":"화면 전환", "freq":440.0, "ms":44, "color":Color(0.36, 0.86, 0.92, 0.18) },
	"ui_confirm": { "label":"확인", "freq":660.0, "ms":52, "color":Color(1.0, 0.74, 0.36, 0.18) },
	"reward": { "label":"보상", "freq":880.0, "ms":86, "color":Color(1.0, 0.82, 0.42, 0.24) },
	"battle_win": { "label":"승리", "freq":740.0, "ms":120, "color":Color(1.0, 0.74, 0.36, 0.26) },
	"battle_loss": { "label":"패배", "freq":220.0, "ms":150, "color":Color(0.52, 0.62, 0.72, 0.22) },
	"deploy": { "label":"배치", "freq":520.0, "ms":46, "color":Color(1.0, 0.74, 0.36, 0.12) },
	"attack_melee": { "label":"근접 타격", "freq":310.0, "ms":34, "color":Color(0.92, 0.47, 0.42, 0.10) },
	"attack_ranged": { "label":"원거리 사격", "freq":620.0, "ms":30, "color":Color(0.42, 0.82, 0.86, 0.10) },
	"attack_guard": { "label":"방패 타격", "freq":260.0, "ms":42, "color":Color(0.55, 0.62, 0.92, 0.10) },
	"combat_heal": { "label":"치유", "freq":780.0, "ms":58, "color":Color(0.58, 0.86, 0.56, 0.14) },
	"hit_heavy": { "label":"강타", "freq":180.0, "ms":72, "color":Color(1.0, 0.74, 0.36, 0.16) },
	"core_hit": { "label":"코어 피격", "freq":140.0, "ms":110, "color":Color(0.90, 0.25, 0.18, 0.20) },
	"unit_death": { "label":"유닛 소멸", "freq":190.0, "ms":92, "color":Color(0.72, 0.78, 0.82, 0.14) },
	"orb_cast": { "label":"오브 발동", "freq":700.0, "ms":76, "color":Color(0.72, 0.56, 0.88, 0.16) },
	"soshin": { "label":"소신", "freq":120.0, "ms":140, "color":Color(0.90, 0.22, 0.16, 0.20) },
	"ash_spawn": { "label":"재의 사도", "freq":150.0, "ms":130, "color":Color(0.82, 0.70, 0.62, 0.18) },
	"command_skill": { "label":"지휘기", "freq":500.0, "ms":110, "color":Color(1.0, 0.74, 0.36, 0.22) },
	"last_stand": { "label":"최후 신호", "freq":940.0, "ms":160, "color":Color(1.0, 0.90, 0.56, 0.26) },
	"retreat": { "label":"후퇴", "freq":240.0, "ms":96, "color":Color(0.52, 0.62, 0.72, 0.18) },
	"error": { "label":"오류", "freq":160.0, "ms":80, "color":Color(0.90, 0.25, 0.18, 0.20) },
}

enum { STRIKER, RANGER, DEFENDER, SNIPER, SUPPORT }  # battle3d와 동일 순서

const TYPE_BATTLE_VISUALS := {
	STRIKER: { "mark":"S", "shape":"blade", "primary":Color(0.92, 0.47, 0.42), "accent":Color(1.0, 0.74, 0.36), "weapon":0.68, "height":1.62 },
	RANGER: { "mark":"R", "shape":"rifle", "primary":Color(0.42, 0.82, 0.86), "accent":Color(0.80, 0.92, 1.0), "weapon":0.95, "height":1.52 },
	DEFENDER: { "mark":"D", "shape":"shield", "primary":Color(0.55, 0.62, 0.92), "accent":Color(0.90, 0.88, 1.0), "weapon":0.44, "height":1.78 },
	SNIPER: { "mark":"N", "shape":"sniper", "primary":Color(0.92, 0.68, 0.98), "accent":Color(0.52, 0.96, 0.90), "weapon":1.28, "height":1.55 },
	SUPPORT: { "mark":"+", "shape":"relic", "primary":Color(0.58, 0.86, 0.56), "accent":Color(0.96, 1.0, 0.72), "weapon":0.52, "height":1.56 },
}
const CHARACTER_BATTLE_VISUALS := {
	"진혼병": { "mark":"I", "shape":"blade", "primary":Color(0.92, 0.47, 0.42), "accent":Color(1.0, 0.74, 0.36), "weapon":0.72, "height":1.58 },
	"운구 소총수": { "mark":"R", "shape":"rifle", "primary":Color(0.42, 0.82, 0.86), "accent":Color(0.84, 0.94, 1.0), "weapon":1.02, "height":1.50 },
	"관지기": { "mark":"D", "shape":"shield", "primary":Color(0.66, 0.72, 0.96), "accent":Color(1.0, 0.74, 0.36), "weapon":0.36, "height":1.82 },
	"소등사": { "mark":"N", "shape":"sniper", "primary":Color(0.92, 0.68, 0.98), "accent":Color(0.52, 0.96, 0.90), "weapon":1.35, "height":1.54 },
	"집전 의무관": { "mark":"+", "shape":"relic", "primary":Color(0.58, 0.86, 0.56), "accent":Color(0.96, 1.0, 0.72), "weapon":0.50, "height":1.52 },
	"사열 돌격수": { "mark":"F", "shape":"banner", "primary":Color(0.96, 0.42, 0.36), "accent":Color(1.0, 0.82, 0.42), "weapon":0.86, "height":1.68 },
	"납골 방패병": { "mark":"O", "shape":"ossuary", "primary":Color(0.70, 0.76, 0.96), "accent":Color(0.88, 0.92, 1.0), "weapon":0.42, "height":1.92 },
	"망종 중계사": { "mark":"W", "shape":"relay", "primary":Color(0.54, 0.86, 0.72), "accent":Color(0.92, 0.98, 0.72), "weapon":0.68, "height":1.58 },
}
const ENEMY_BATTLE_VISUALS := {
	"급조 항체": { "mark":"!", "shape":"claw", "primary":Color(0.70, 0.80, 0.84), "accent":Color(0.36, 0.86, 0.92), "weapon":0.56, "height":1.40 },
	"확산체": { "mark":"*", "shape":"spore", "primary":Color(0.46, 0.82, 0.78), "accent":Color(0.80, 1.0, 0.94), "weapon":0.40, "height":1.34 },
	"만성 염증체": { "mark":"T", "shape":"tank", "primary":Color(0.62, 0.70, 0.82), "accent":Color(0.36, 0.86, 0.92), "weapon":0.50, "height":1.95 },
	"재의 사도": { "mark":"A", "shape":"ash", "primary":Color(0.82, 0.70, 0.62), "accent":Color(1.0, 0.54, 0.38), "weapon":0.86, "height":1.70 },
}

# 전 캐릭터 카탈로그 (순서 = 카드 순서). battle3d.DECK로 넘어감.
const ALL_CHARS := [
	{ "name": "진혼병", "type": STRIKER, "cost": 2, "hp": 78, "dmg": 13, "aspd": 1.5, "range": 0.85, "move": 1.5, "cd": 1.2, "ps": 0.060,
	  "true_name":"유현", "epithet":"첫 번째 관을 멘 자", "rarity":"R", "faction":"장송 선봉대",
	  "asset_pipeline":"pixellab_combat_state", "asset_pipeline_slug":"jinhonbyeong", "asset_pipeline_stage":"ready",
	  "sprite": "res://assets/sprites/jinhonbyeong_pl", "sps": 0.0081, "tightsprite": true,
	  "role": "스트라이커 · 근접 돌격", "lore": "가장 먼저 달려나가 가장 먼저 스러지는 망자. 생전에는 회랑 진입로를 표시하던 구조대원이었고, 지금도 길이 막히면 몸으로 먼저 문을 연다.",
	  "quote":"내 이름은 뒤에 불러. 길부터 열어야 하니까.",
	  "bond_lines":["좋아하는 것: 아직 따뜻한 손난로.", "싫어하는 것: 문 앞에서 망설이는 발소리."],
	  "visual_brief":"그을린 장송 코트, 번트오렌지 완장, 짧은 검은 머리, 팔뚝에 관 끈을 감은 근접 선봉. 무광·검댕·마른 붓터치." },
	{ "name": "운구 소총수", "type": RANGER, "cost": 3, "hp": 46, "dmg": 11, "aspd": 1.1, "range": 4.0, "move": 1.1, "cd": 1.4, "ps": 0.058,
	  "true_name":"백이현", "epithet":"관총의 운반자", "rarity":"R", "faction":"운구 소대",
	  "asset_pipeline":"pixellab_combat_state", "asset_pipeline_slug":"ungoo_rifle", "asset_pipeline_stage":"ready",
	  "sprite": "res://assets/sprites/ungoo_rifle_pl", "sps": 0.0074, "tightsprite": true,
	  "role": "레인저 · 중거리 사격", "lore": "관을 나르던 손으로 이제 방아쇠를 당긴다. 말수가 적고, 탄창을 갈 때마다 관 뚜껑을 닫듯 잠깐 눈을 내리깐다.",
	  "quote":"운구는 끝까지 가는 일이다. 사격도 같다.",
	  "bond_lines":["좋아하는 것: 빈 탄피를 줄 맞춰 놓기.", "싫어하는 것: 이름 없는 관."],
	  "visual_brief":"무광 올리브 운구복, 긴 소총, 관 손잡이를 닮은 슬링, 낮은 모자챙, 피로한 눈. 카키·올리브·어두운 황토." },
	{ "name": "관지기", "type": DEFENDER, "cost": 3, "hp": 215, "dmg": 6, "aspd": 0.9, "range": 0.95, "move": 0.95, "cd": 3.0, "ps": 0.072,
	  "true_name":"문가온", "epithet":"봉문자", "rarity":"SR", "faction":"봉문 기사단",
	  "art": "res://assets/art/face_gwanjigi.png", "card_art":"res://assets/art/card_gwanjigi.png", "sprite": "res://assets/sprites/gwanjigi_pl", "sps": 0.0072, "tightsprite": true,
	  "role": "디펜더 · 전열 방패", "lore": "회랑의 문을 지키는 자. 코어에서 떼어낸 동결 결정판을 방패 삼는다. 가장 무겁고, 가장 오래 버틴다.",
	  "quote":"문은 열 때보다 닫을 때 더 많은 이름을 구한다.",
	  "bond_lines":["좋아하는 것: 조용한 문지방.", "싫어하는 것: 뒤에서 들리는 비명."],
	  "visual_brief":"실버 머리, 슬레이트블루 장갑, 코어 결정 방패, 넓은 어깨와 낮은 자세. 차갑고 무광인 얼음 금속." },
	{ "name": "소등사", "type": SNIPER, "cost": 5, "hp": 40, "dmg": 40, "aspd": 0.42, "range": 6.2, "move": 0.9, "cd": 5.0, "ps": 0.058,
	  "true_name":"서리안", "epithet":"불씨를 끄는 눈", "rarity":"SSR", "faction":"소등 의식반",
	  "art": "res://assets/art/face_sodeungsa.png", "card_art":"res://assets/art/card_sodeungsa.png", "sprite": "res://assets/sprites/sodeungsa_pl", "sps": 0.0076, "tightsprite": true,
	  "role": "스나이퍼 · 원거리 처형", "lore": "매듭의 빛을 한 발에 끄는 자. 가장 또렷이 깨어 있어 가장 사람에 가까운 망자지만, 오래 조준할수록 자신이 누구였는지 기억해버린다.",
	  "quote":"불은 끄면 끝나. 이름은, 끈 뒤에 남아.",
	  "bond_lines":["좋아하는 것: 렌즈에 낀 먼지를 닦는 시간.", "싫어하는 것: 너무 밝은 곳."],
	  "visual_brief":"어번 다크레드 머리, 장거리 소총, 낮은 숨, 멜랑콜리한 눈. 따뜻한 어스톤과 어두운 레드, 무광 총열." },
	{ "name": "집전 의무관", "type": SUPPORT, "cost": 4, "hp": 58, "dmg": 0, "heal": 15, "aspd": 0.8, "range": 2.8, "move": 1.1, "cd": 4.0, "ps": 0.058,
	  "true_name":"한세라", "epithet":"잔등의 집전자", "rarity":"R", "faction":"집전 의무대",
	  "asset_pipeline":"pixellab_combat_state", "asset_pipeline_slug":"jipjeon_medic", "asset_pipeline_stage":"ready",
	  "sprite": "res://assets/sprites/jipjeon_medic_pl", "sps": 0.0063, "tightsprite": true,
	  "role": "서포터 · 후열 치유", "lore": "꺼져가는 등불에 기름을 붓는 손. 살리는 법보다 마지막 말을 덜 아프게 듣는 법을 먼저 배웠다.",
	  "quote":"살릴 수 없다면, 적어도 혼자 꺼지게 두진 않아.",
	  "bond_lines":["좋아하는 것: 깨끗한 붕대 냄새.", "싫어하는 것: 치료보다 빠른 명령."],
	  "visual_brief":"본화이트 의무복, 세이지민트 숄, 작은 등유 성물, 피 묻은 장갑. 부드러운 표정이지만 눈은 또렷함." },
	{ "name": "사열 돌격수", "type": STRIKER, "cost": 4, "hp": 118, "dmg": 18, "aspd": 1.0, "range": 0.9, "move": 1.35, "cd": 3.8, "ps": 0.066,
	  "true_name":"류단", "epithet":"재의 기수", "rarity":"SR", "faction":"사열대",
	  "asset_pipeline":"pixellab_combat_state", "asset_pipeline_slug":"sayeol_striker", "asset_pipeline_stage":"ready",
	  "sprite": "res://assets/sprites/sayeol_striker_pl", "sps": 0.0072, "tightsprite": true,
	  "role": "스트라이커 · 고비용 돌파", "lore": "묘비 사이로 깃발을 들고 전선을 밀어붙인다. 사열 구호를 외우지 못해도, 깃발이 기울어지는 방향만큼은 한 번도 틀린 적이 없다.",
	  "quote":"줄 맞춰. 무덤도, 돌격도.",
	  "bond_lines":["좋아하는 것: 군화 밑창을 같은 각도로 놓기.", "싫어하는 것: 흐트러진 행렬."],
	  "visual_brief":"낡은 사열 깃발, 재색 장교 코트, 번트레드 장식끈, 짧은 창검. 전진하는 삼각 실루엣." },
	{ "name": "납골 방패병", "type": DEFENDER, "cost": 5, "hp": 330, "dmg": 8, "aspd": 0.72, "range": 0.9, "move": 0.72, "cd": 5.6, "ps": 0.088,
	  "true_name":"오서린", "epithet":"유골 성채", "rarity":"SSR", "faction":"납골 성벽대",
	  "asset_pipeline":"pixellab_combat_state", "asset_pipeline_slug":"napgol_defender", "asset_pipeline_stage":"ready",
	  "sprite": "res://assets/sprites/napgol_defender_pl", "sps": 0.0068, "tightsprite": true,
	  "role": "디펜더 · 중장 저지", "lore": "이름 없는 유골함을 방패 안쪽에 품은 방어병. 말은 느리지만, 한 번 선 자리는 회랑 지형처럼 바뀐다.",
	  "quote":"나는 무겁지 않아. 내가 든 이름들이 무거운 거야.",
	  "bond_lines":["좋아하는 것: 이름표를 닦는 일.", "싫어하는 것: 가벼운 약속."],
	  "visual_brief":"대형 납골함 방패, 본화이트와 슬레이트 금속, 느린 거인 같은 자세, 방패 안쪽의 작은 이름표들." },
	{ "name": "망종 중계사", "type": SUPPORT, "cost": 3, "hp": 64, "dmg": 6, "heal": 7, "aspd": 0.95, "range": 3.4, "move": 1.0, "cd": 3.2, "ps": 0.058,
	  "true_name":"차미루", "epithet":"마지막 종소리", "rarity":"SR", "faction":"망종 통신반",
	  "asset_pipeline":"pixellab_combat_state", "asset_pipeline_slug":"mangjong_relay", "asset_pipeline_stage":"ready",
	  "sprite": "res://assets/sprites/mangjong_relay_pl", "sps": 0.0063, "tightsprite": true,
	  "role": "서포터 · 보조 사격", "lore": "끊긴 통신을 이어 망자의 진군을 동기화한다. 언제나 한 박자 늦게 대답하지만, 가장 먼 곳의 구조 신호를 제일 먼저 듣는다.",
	  "quote":"들려. 아직 끊기지 않은 이름이 있어.",
	  "bond_lines":["좋아하는 것: 잡음 속에서 사람 목소리를 찾기.", "싫어하는 것: 완전한 정적."],
	  "visual_brief":"낡은 중계기 백팩, 세이지와 머스터드 톤 케이블, 작은 종 모양 안테나, 한쪽 귀에 과한 리시버." },
]

const ORB_SKILLS := {
	"진혼병": {
		"1": { "label":"장송 찌르기", "kind":"damage_front", "amount":22.0 },
		"2": { "label":"재돌파", "kind":"damage_front", "amount":42.0, "push":0.25 },
		"4": { "label":"회랑 돌격", "kind":"damage_front", "amount":92.0, "push":1.1 },
	},
	"운구 소총수": {
		"1": { "label":"운구 사격", "kind":"damage_weakest", "amount":18.0 },
		"2": { "label":"철갑 송별", "kind":"damage_weakest", "amount":44.0 },
		"4": { "label":"관뚜껑 저격", "kind":"execute_weakest", "amount":78.0, "execute":0.35 },
	},
	"관지기": {
		"1": { "label":"문막기", "kind":"guard_push", "guard":1.0, "push":0.25 },
		"2": { "label":"봉문", "kind":"guard_push", "guard":1.8, "push":0.65 },
		"4": { "label":"철문 장례", "kind":"guard_push", "guard":3.2, "push":1.45, "damage":24.0 },
	},
	"소등사": {
		"1": { "label":"불씨 조준", "kind":"damage_weakest", "amount":30.0 },
		"2": { "label":"꺼진 시야", "kind":"damage_weakest", "amount":64.0 },
		"4": { "label":"마지막 탄환", "kind":"execute_weakest", "amount":122.0, "execute":0.45 },
	},
	"집전 의무관": {
		"1": { "label":"응급 집전", "kind":"heal_weakest", "amount":24.0 },
		"2": { "label":"회광", "kind":"heal_weakest", "amount":48.0, "guard":0.7 },
		"4": { "label":"임종 집전", "kind":"heal_weakest", "amount":96.0, "guard":1.6, "cost":1.0 },
	},
	"사열 돌격수": {
		"1": { "label":"사열 전진", "kind":"damage_front", "amount":28.0, "push":0.15 },
		"2": { "label":"깃발 돌격", "kind":"damage_front", "amount":58.0, "push":0.55 },
		"4": { "label":"재의 기수", "kind":"damage_front", "amount":118.0, "push":1.25 },
	},
	"납골 방패병": {
		"1": { "label":"납골 방패", "kind":"guard_push", "guard":1.2, "push":0.15 },
		"2": { "label":"골벽", "kind":"guard_push", "guard":2.2, "push":0.45 },
		"4": { "label":"유골 성채", "kind":"guard_push", "guard":4.0, "push":1.1, "damage":18.0 },
	},
	"망종 중계사": {
		"1": { "label":"중계 신호", "kind":"heal_weakest", "amount":14.0, "cost":0.35 },
		"2": { "label":"장송 파형", "kind":"damage_weakest", "amount":36.0, "cost":0.55 },
		"4": { "label":"망종 동기화", "kind":"heal_weakest", "amount":62.0, "guard":1.0, "cost":1.4 },
	},
}

# ★각인 계약 — 캐릭터마다 한 슬롯을 해금하고 두 상황형 효과 중 하나를 선택한다.
# 최초 스테이지 클리어마다 각인재 +1. 슬롯 해금에 1개를 쓰며, 해금 뒤 선택 교체는 무료.
const IMPRINTS := {
	"진혼병": [
		{ "id":"funeral_charge", "label":"장례 돌파", "desc":"레인저에게 주는 피해 +25%", "kind":"counter", "target":RANGER, "bonus":0.25 },
		{ "id":"last_ember", "label":"마지막 잔불", "desc":"등불 50% 이하에서 피해 ×1.4", "kind":"low_core_damage", "threshold":0.50, "mult":1.40 },
	],
	"운구 소총수": [
		{ "id":"armor_farewell", "label":"철갑 송별", "desc":"디펜더에게 주는 피해 +25%", "kind":"counter", "target":DEFENDER, "bonus":0.25 },
		{ "id":"behind_the_bier", "label":"관 뒤의 사수", "desc":"아군 디펜더 생존 중 피해 ×1.2", "kind":"defender_aura_damage", "mult":1.20 },
	],
	"관지기": [
		{ "id":"sealed_gate", "label":"봉문", "desc":"아군 코어 근처에서 받는 피해 35% 감소", "kind":"near_core_guard", "max_x":-3.5, "mult":0.65 },
		{ "id":"plague_return", "label":"역병 반사", "desc":"스트라이커에게 주는 피해 +35%", "kind":"counter", "target":STRIKER, "bonus":0.35 },
	],
	"소등사": [
		{ "id":"last_round", "label":"마지막 탄환", "desc":"HP 35% 이하 적에게 피해 ×1.5", "kind":"execute", "threshold":0.35, "mult":1.50 },
		{ "id":"extinguished_sight", "label":"꺼진 시야", "desc":"등불 50% 이하에서 공격 간격 30% 감소", "kind":"low_core_haste", "threshold":0.50, "mult":0.70 },
	],
	"집전 의무관": [
		{ "id":"afterglow", "label":"회광", "desc":"등불 50% 이하에서 치유 ×1.5", "kind":"low_core_heal", "threshold":0.50, "mult":1.50 },
		{ "id":"last_rites", "label":"임종 집전", "desc":"HP 30% 이하 아군 치유 ×1.45", "kind":"critical_heal", "threshold":0.30, "mult":1.45 },
	],
	"사열 돌격수": [
		{ "id":"parade_break", "label":"사열 돌파", "desc":"레인저에게 주는 피해 +25%", "kind":"counter", "target":RANGER, "bonus":0.25 },
		{ "id":"flag_of_ashes", "label":"재의 기수", "desc":"등불 50% 이하에서 피해 ×1.3", "kind":"low_core_damage", "threshold":0.50, "mult":1.30 },
	],
	"납골 방패병": [
		{ "id":"ossuary_wall", "label":"납골 장벽", "desc":"아군 코어 근처에서 받는 피해 30% 감소", "kind":"near_core_guard", "max_x":-3.0, "mult":0.70 },
		{ "id":"bone_counter", "label":"골편 반격", "desc":"스트라이커에게 주는 피해 +25%", "kind":"counter", "target":STRIKER, "bonus":0.25 },
	],
	"망종 중계사": [
		{ "id":"relay_prayer", "label":"중계 기도", "desc":"등불 50% 이하에서 치유 ×1.35", "kind":"low_core_heal", "threshold":0.50, "mult":1.35 },
		{ "id":"funeral_signal", "label":"장송 신호", "desc":"디펜더에게 주는 피해 +20%", "kind":"counter", "target":DEFENDER, "bonus":0.20 },
	],
}

const ENEMY_DEFS := {
	"rusher": { "name": "급조 항체", "type": STRIKER, "hp": 56, "dmg": 11, "aspd": 1.3, "range": 0.8, "move": 1.7, "ps": 0.056 },
	"spore": { "name": "확산체", "type": RANGER, "hp": 42, "dmg": 10, "aspd": 1.0, "range": 2.8, "move": 1.05, "ps": 0.058 },
	"tank": { "name": "만성 염증체", "type": DEFENDER, "hp": 260, "dmg": 22, "aspd": 0.7, "range": 0.9, "move": 0.66, "ps": 0.090 },
	"ashen": { "name": "재의 사도", "type": STRIKER, "hp": 90, "dmg": 18, "aspd": 1.2, "range": 0.85, "move": 1.5, "ps": 0.066 },
}

# 선형 회랑 — 스테이지. 클리어하면 다음 해금 + unlock 캐릭터 획득.
# 밸런스: 적 코어 HP 완곡화(후반 밀 수 있게) + 웨이브 밀도↑(아군 코어 위협 → 소신 활성).
const STAGES := [
	{ "id": "s1", "name": "격리 구획", "sub": "회랑의 첫 문", "enemy_hp": 280.0, "unlock": "소등사",
	  "rule_tags": ["소환 훈련", "기본 웨이브"],
	  "tutorial": { "title": "ST1 · 소환", "hint": "카드를 눌러 망자를 전선에 세우세요.", "hand_cycle": false, "orbs": false, "deploy_position": false, "soshin": false, "command": false, "last_stand": false },
	  "waves": [ {"t":2.0,"id":"rusher","n":2}, {"t":7.0,"id":"rusher","n":2}, {"t":12.0,"id":"spore","n":2},
		{"t":18.0,"id":"rusher","n":3}, {"t":25.0,"id":"tank","n":1}, {"t":31.0,"id":"spore","n":2}, {"t":37.0,"id":"rusher","n":3} ] },
	{ "id": "s2", "name": "포자 온상", "sub": "확산체의 둥지", "enemy_hp": 500.0, "unlock": "사열 돌격수",
	  "rule_tags": ["손패 순환", "원거리 압박"],
	  "tutorial": { "title": "ST2 · 손패 순환", "hint": "쓴 카드는 뒤로 빠지고 다음 계약이 손패에 들어옵니다.", "hand_cycle": true, "orbs": false, "deploy_position": false, "soshin": false, "command": false, "last_stand": false },
	  "waves": [ {"t":2.0,"id":"spore","n":1}, {"t":5.0,"id":"rusher","n":2}, {"t":12.0,"id":"spore","n":2},
		{"t":14.0,"id":"tank","n":1}, {"t":28.0,"id":"rusher","n":2}, {"t":36.0,"id":"spore","n":1} ] },
	{ "id": "s3", "name": "염증 회랑", "sub": "굳은 살의 벽", "enemy_hp": 450.0, "unlock": "납골 방패병",
	  "rule_tags": ["오브 커맨드", "디펜더 압박"],
	  "tutorial": { "title": "ST3 · 오브 발동", "hint": "같은 색 인접 오브를 1/2/4개 골라 캐릭터 스킬을 발동하세요.", "hand_cycle": true, "orbs": true, "deploy_position": false, "soshin": false, "command": false, "last_stand": false },
	  "waves": [ {"t":2.0,"id":"rusher","n":3}, {"t":6.0,"id":"tank","n":1}, {"t":11.0,"id":"spore","n":3},
		{"t":17.0,"id":"rusher","n":3}, {"t":23.0,"id":"tank","n":1}, {"t":29.0,"id":"spore","n":3},
		{"t":35.0,"id":"rusher","n":4}, {"t":41.0,"id":"tank","n":2}, {"t":48.0,"id":"spore","n":3} ] },
	{ "id": "s4", "name": "재의 계단", "sub": "돌아선 자들", "enemy_hp": 560.0, "unlock": "망종 중계사",
	  "rule_tags": ["위치 배치", "재의 사도"],
	  "tutorial": { "title": "ST4 · 배치 영역", "hint": "카드를 고른 뒤 빛 영역 안을 클릭해 원하는 위치에 배치하세요.", "hand_cycle": true, "orbs": true, "deploy_position": true, "soshin": false, "command": false, "last_stand": false },
	  "waves": [ {"t":2.0,"id":"rusher","n":3}, {"t":6.0,"id":"spore","n":3}, {"t":11.0,"id":"ashen","n":1},
		{"t":15.0,"id":"tank","n":1}, {"t":21.0,"id":"rusher","n":4}, {"t":27.0,"id":"ashen","n":2},
		{"t":33.0,"id":"spore","n":3}, {"t":39.0,"id":"tank","n":2}, {"t":45.0,"id":"ashen","n":2}, {"t":51.0,"id":"rusher","n":4} ] },
	{ "id": "s5", "name": "매듭의 핵", "sub": "회랑의 끝", "enemy_hp": 600.0, "unlock": "",
	  "rule_tags": ["소신", "등불함 지휘기", "최후 신호"],
	  "tutorial": { "title": "ST5 · 소신과 최후 신호", "hint": "소신으로 코스트를 만들고, 위기에는 등불함 지휘기로 전선을 밀어내세요.", "hand_cycle": true, "orbs": true, "deploy_position": true, "soshin": true, "command": true, "last_stand": true },
	  "waves": [ {"t":2.0,"id":"rusher","n":3}, {"t":6.0,"id":"spore","n":3}, {"t":10.0,"id":"tank","n":1},
		{"t":15.0,"id":"ashen","n":2}, {"t":21.0,"id":"rusher","n":3}, {"t":27.0,"id":"tank","n":1},
		{"t":33.0,"id":"spore","n":3}, {"t":39.0,"id":"ashen","n":2}, {"t":45.0,"id":"tank","n":2} ] },
]

const START_UNLOCKED := ["진혼병", "운구 소총수", "관지기", "집전 의무관"]

var cleared: Array = []       # 클리어한 스테이지 id
var unlocked: Array = []      # 해금 캐릭터 이름
var squad: Array = []         # 다음 전투 편성(이름)
var current_stage := 0        # 진입할 스테이지 인덱스
var brand_points := 0         # 미사용 각인재
var imprint_unlocked: Array = []
var imprint_choices: Dictionary = {}  # 캐릭터 이름 -> 각인 id
var last_win := false
var last_unlocked_name := ""  # 직전 전투에서 새로 해금된 캐릭터
var last_brand_reward := false
var last_result_record: Dictionary = {}
var run_records: Array = []
var challenge_seed := 0
var test_mode_no_save := false
var lumen := 600
var gold := 10000
var recruit_tickets := 3
var gacha_pity := 0
var gacha_history: Array = []
var character_shards: Dictionary = {}
var shop_claims: Dictionary = {}
var monetization_events: Array = []
var chat_messages: Array = []
var last_daily_claim := ""
var player_name := "집전관"
var account_level := 1
var account_xp := 0
var character_levels: Dictionary = {}
var mailbox: Array = []
var claimed_missions: Array = []
var battle_pass_xp := 0
var battle_pass_claimed: Array = []
var daily_activity: Dictionary = {}
var user_settings: Dictionary = {}
var notice_reads: Array = []
var tutorial_views: Array = []
var accepted_terms_version := ""
var last_battle_feedback: Dictionary = {}
var feedback_log: Array = []
var transition_active := false

func _ready() -> void:
	load_game()

func new_game() -> void:
	cleared = []
	unlocked = START_UNLOCKED.duplicate()
	squad = []
	current_stage = 0
	brand_points = 0
	imprint_unlocked = []
	imprint_choices = {}
	run_records = []
	challenge_seed = 0
	lumen = 600
	gold = 10000
	recruit_tickets = 3
	gacha_pity = 0
	gacha_history = []
	character_shards = {}
	shop_claims = {}
	monetization_events = []
	chat_messages = CHAT_SEED.duplicate(true)
	last_daily_claim = ""
	player_name = "집전관"
	account_level = 1
	account_xp = 0
	character_levels = {}
	for cname in unlocked:
		character_levels[str(cname)] = 1
	mailbox = []
	claimed_missions = []
	battle_pass_xp = 0
	battle_pass_claimed = []
	daily_activity = _default_daily_activity()
	user_settings = DEFAULT_SETTINGS.duplicate(true)
	notice_reads = []
	tutorial_views = []
	accepted_terms_version = ""
	last_battle_feedback = {}
	feedback_log = []
	transition_active = false
	ensure_mailbox(false)
	save_game()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_game() -> void:
	if not has_save():
		unlocked = START_UNLOCKED.duplicate()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		unlocked = START_UNLOCKED.duplicate(); return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) == TYPE_DICTIONARY:
		cleared = data.get("cleared", [])
		unlocked = data.get("unlocked", START_UNLOCKED.duplicate())
		current_stage = int(data.get("current_stage", 0))
		imprint_unlocked = data.get("imprint_unlocked", [])
		imprint_choices = data.get("imprint_choices", {})
		run_records = data.get("run_records", [])
		challenge_seed = int(data.get("challenge_seed", 0))
		lumen = int(data.get("lumen", 600))
		gold = int(data.get("gold", 10000))
		recruit_tickets = int(data.get("recruit_tickets", 3))
		gacha_pity = int(data.get("gacha_pity", 0))
		gacha_history = data.get("gacha_history", [])
		character_shards = data.get("character_shards", {})
		shop_claims = data.get("shop_claims", {})
		monetization_events = data.get("monetization_events", [])
		chat_messages = data.get("chat_messages", CHAT_SEED.duplicate(true))
		last_daily_claim = str(data.get("last_daily_claim", ""))
		player_name = str(data.get("player_name", "집전관"))
		account_level = int(data.get("account_level", 1))
		account_xp = int(data.get("account_xp", 0))
		character_levels = data.get("character_levels", {})
		mailbox = data.get("mailbox", [])
		claimed_missions = data.get("claimed_missions", [])
		battle_pass_xp = int(data.get("battle_pass_xp", 0))
		battle_pass_claimed = data.get("battle_pass_claimed", [])
		daily_activity = data.get("daily_activity", {})
		user_settings = data.get("user_settings", DEFAULT_SETTINGS.duplicate(true))
		notice_reads = data.get("notice_reads", [])
		tutorial_views = data.get("tutorial_views", [])
		accepted_terms_version = str(data.get("accepted_terms_version", ""))
		last_battle_feedback = data.get("last_battle_feedback", {})
		# 구버전 세이브는 이미 깬 스테이지 수만큼 각인재를 소급 지급한다.
		brand_points = int(data.get("brand_points", cleared.size()))
	if unlocked.is_empty():
		unlocked = START_UNLOCKED.duplicate()
	for cname in unlocked:
		if not character_levels.has(str(cname)):
			character_levels[str(cname)] = 1
	_ensure_daily_activity()
	_normalize_settings()
	ensure_mailbox(false)

func save_game() -> void:
	if test_mode_no_save:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"cleared": cleared, "unlocked": unlocked, "current_stage": current_stage,
		"brand_points": brand_points, "imprint_unlocked": imprint_unlocked,
		"imprint_choices": imprint_choices, "run_records": run_records,
		"challenge_seed": challenge_seed, "lumen": lumen, "gold": gold,
		"recruit_tickets": recruit_tickets, "gacha_pity": gacha_pity,
		"gacha_history": gacha_history, "character_shards": character_shards,
		"shop_claims": shop_claims, "monetization_events": monetization_events,
		"chat_messages": chat_messages, "last_daily_claim": last_daily_claim,
		"player_name": player_name, "account_level": account_level,
		"account_xp": account_xp, "character_levels": character_levels,
		"mailbox": mailbox, "claimed_missions": claimed_missions,
		"battle_pass_xp": battle_pass_xp, "battle_pass_claimed": battle_pass_claimed,
		"daily_activity": daily_activity,
		"user_settings": user_settings, "notice_reads": notice_reads,
		"tutorial_views": tutorial_views, "accepted_terms_version": accepted_terms_version,
		"last_battle_feedback": last_battle_feedback,
	}))
	f.close()

# ---------- 조회 ----------
func char_def(cname: String) -> Dictionary:
	for c in ALL_CHARS:
		if c["name"] == cname:
			return _with_imprint(c)
	return {}

func all_chars_list() -> Array:
	var out := []
	for c in ALL_CHARS:
		out.append(_with_imprint(c))
	return out

func unlocked_defs() -> Array:
	var out := []
	for c in ALL_CHARS:
		if unlocked.has(c["name"]):
			out.append(_with_imprint(c))
	return out

func squad_defs() -> Array:
	var out := []
	for i in squad.size():
		var c := char_def(str(squad[i]))
		if c.is_empty():
			continue
		c["leader"] = i == 0
		out.append(c)
	return out

func ship_contract() -> Dictionary:
	return SHIP_CONTRACT.duplicate(true)

func imprint_options(cname: String) -> Array:
	return IMPRINTS.get(cname, []).duplicate(true)

func selected_imprint(cname: String) -> Dictionary:
	var selected_id := str(imprint_choices.get(cname, ""))
	for imp in IMPRINTS.get(cname, []):
		if imp["id"] == selected_id:
			return imp.duplicate(true)
	return {}

func _with_imprint(base_def: Dictionary) -> Dictionary:
	var out := base_def.duplicate(true)
	var cname: String = str(base_def["name"])
	out["visual"] = battle_visual_for(cname, int(base_def.get("type", STRIKER)), false)
	var level := character_level(cname)
	out["level"] = level
	if level > 1:
		var growth_mult := 1.0 + float(level - 1) * 0.04
		for stat in ["hp", "dmg", "heal"]:
			if out.has(stat):
				out[stat] = float(out[stat]) * growth_mult
		out["growth_mult"] = growth_mult
	if ORB_SKILLS.has(cname):
		out["orb_skills"] = ORB_SKILLS[cname].duplicate(true)
	var imp := selected_imprint(str(base_def["name"]))
	if not imp.is_empty():
		out["imprint"] = imp
	return out

func battle_visual_for(unit_name: String, unit_type: int, enemy := false) -> Dictionary:
	var source := ENEMY_BATTLE_VISUALS if enemy else CHARACTER_BATTLE_VISUALS
	var visual: Dictionary = source.get(unit_name, TYPE_BATTLE_VISUALS.get(unit_type, TYPE_BATTLE_VISUALS[STRIKER])).duplicate(true)
	if enemy:
		visual["enemy"] = true
	else:
		visual["enemy"] = false
	return visual

# 잠긴 슬롯이면 각인재 1개로 해금+첫 선택, 이미 열렸으면 두 선택을 순환한다.
func cycle_imprint(cname: String, persist := true) -> bool:
	if not unlocked.has(cname):
		return false
	var options: Array = IMPRINTS.get(cname, [])
	if options.is_empty():
		return false
	if not imprint_unlocked.has(cname):
		if brand_points <= 0:
			return false
		brand_points -= 1
		imprint_unlocked.append(cname)
		imprint_choices[cname] = options[0]["id"]
	else:
		var current_id := str(imprint_choices.get(cname, options[0]["id"]))
		var next_idx := 0
		for i in options.size():
			if options[i]["id"] == current_id:
				next_idx = (i + 1) % options.size()
				break
		imprint_choices[cname] = options[next_idx]["id"]
	if persist:
		save_game()
	return true

func current_stage_def() -> Dictionary:
	if current_stage >= STAGES.size() and all_cleared():
		return challenge_stage_def(challenge_seed)
	return STAGES[clampi(current_stage, 0, STAGES.size() - 1)]

func challenge_stage_def(seed: int) -> Dictionary:
	var base: Dictionary = STAGES[STAGES.size() - 1].duplicate(true)
	var tag_sets := [
		["변종", "스나이퍼 우세", "짧은 웨이브"],
		["변종", "디펜더 압박", "장기전"],
		["변종", "오브 숙련", "재의 사도"],
	]
	base["id"] = "loop_%03d" % seed
	base["name"] = "변종 회랑 %02d" % (seed + 1)
	base["sub"] = "완주 후 반복 도전"
	base["rule_tags"] = tag_sets[seed % tag_sets.size()]
	base["tutorial"] = { "title": "변종 도전", "hint": "모든 규칙이 열린 상태로 결과를 기록합니다.", "hand_cycle": true, "orbs": true, "deploy_position": true, "soshin": true, "command": true, "last_stand": true }
	return base

func stage_open(idx: int) -> bool:
	if idx == STAGES.size():
		return all_cleared()
	if idx <= 0:
		return true
	if idx >= STAGES.size():
		return false
	return cleared.has(STAGES[idx - 1]["id"])

func stage_cleared(idx: int) -> bool:
	return idx >= 0 and idx < STAGES.size() and cleared.has(STAGES[idx]["id"])

func all_cleared() -> bool:
	return cleared.size() >= STAGES.size()

# ---------- 모바일 메타 / 라이브옵스 목업 ----------
func _default_daily_activity() -> Dictionary:
	return {
		"date": today_key(),
		"login": 0,
		"gacha": 0,
		"chat": 0,
		"shop": 0,
		"battle": 0,
		"battle_win": 0,
		"upgrade": 0,
	}

func _ensure_daily_activity() -> void:
	var today := today_key()
	if str(daily_activity.get("date", "")) != today:
		daily_activity = {
			"date": today,
			"login": 0,
			"gacha": 0,
			"chat": 0,
			"shop": 0,
			"battle": 0,
			"battle_win": 0,
			"upgrade": 0,
		}

func _bump_daily_activity(counter: String, amount := 1) -> void:
	_ensure_daily_activity()
	daily_activity[counter] = int(daily_activity.get(counter, 0)) + amount

func _normalize_settings() -> void:
	if typeof(user_settings) != TYPE_DICTIONARY:
		user_settings = DEFAULT_SETTINGS.duplicate(true)
	for key in DEFAULT_SETTINGS.keys():
		if not user_settings.has(key):
			user_settings[key] = DEFAULT_SETTINGS[key]
	for key in ["master_volume", "bgm_volume", "sfx_volume"]:
		user_settings[key] = clampf(float(user_settings.get(key, DEFAULT_SETTINGS[key])), 0.0, 1.0)
	for key in ["vibration", "reduced_motion", "fps_60", "safe_area"]:
		user_settings[key] = bool(user_settings.get(key, DEFAULT_SETTINGS[key]))

func settings_copy() -> Dictionary:
	_normalize_settings()
	return user_settings.duplicate(true)

func set_setting(key: String, value) -> Dictionary:
	if not DEFAULT_SETTINGS.has(key):
		return { "ok": false, "message": "없는 설정입니다." }
	user_settings[key] = value
	_normalize_settings()
	save_game()
	return { "ok": true, "message": "설정 저장: %s" % key }

func toggle_setting(key: String) -> Dictionary:
	if not DEFAULT_SETTINGS.has(key):
		return { "ok": false, "message": "없는 설정입니다." }
	return set_setting(key, not bool(user_settings.get(key, DEFAULT_SETTINGS[key])))

func cycle_volume_setting(key: String) -> Dictionary:
	if not ["master_volume", "bgm_volume", "sfx_volume"].has(key):
		return { "ok": false, "message": "볼륨 설정이 아닙니다." }
	var current := float(settings_copy().get(key, 1.0))
	var next := 1.0
	if current >= 0.95:
		next = 0.5
	elif current >= 0.45:
		next = 0.0
	else:
		next = 1.0
	return set_setting(key, next)

func reset_settings() -> Dictionary:
	user_settings = DEFAULT_SETTINGS.duplicate(true)
	save_game()
	return { "ok": true, "message": "설정을 기본값으로 돌렸습니다." }

func terms_needed() -> bool:
	return accepted_terms_version != TERMS_VERSION

func accept_terms() -> Dictionary:
	accepted_terms_version = TERMS_VERSION
	save_game()
	return { "ok": true, "message": "로컬 테스트 약관 확인 완료" }

func notice_list() -> Array:
	var out := []
	for notice_def in NOTICE_FEED:
		var notice: Dictionary = notice_def.duplicate(true)
		notice["read"] = notice_reads.has(str(notice.get("id", "")))
		out.append(notice)
	return out

func unread_notice_count() -> int:
	var count := 0
	for notice in notice_list():
		if not bool(notice.get("read", false)):
			count += 1
	return count

func mark_notice_read(notice_id: String) -> Dictionary:
	var exists := false
	for notice in NOTICE_FEED:
		if str(notice.get("id", "")) == notice_id:
			exists = true
			break
	if not exists:
		return { "ok": false, "message": "없는 공지입니다." }
	if not notice_reads.has(notice_id):
		notice_reads.append(notice_id)
		save_game()
	return { "ok": true, "message": "공지 읽음 처리 완료" }

func mark_all_notices_read() -> Dictionary:
	for notice in NOTICE_FEED:
		var id := str(notice.get("id", ""))
		if not notice_reads.has(id):
			notice_reads.append(id)
	save_game()
	return { "ok": true, "message": "모든 공지를 읽음 처리했습니다." }

func tutorial_topics() -> Array:
	var out := []
	for topic_def in TUTORIAL_TOPICS:
		var topic: Dictionary = topic_def.duplicate(true)
		topic["viewed"] = tutorial_views.has(str(topic.get("id", "")))
		out.append(topic)
	return out

func tutorial_topic(topic_id: String) -> Dictionary:
	for topic in TUTORIAL_TOPICS:
		if str(topic.get("id", "")) == topic_id:
			return topic.duplicate(true)
	return {}

func tutorial_viewed(topic_id: String) -> bool:
	return tutorial_views.has(topic_id)

func mark_tutorial_viewed(topic_id: String) -> Dictionary:
	if tutorial_topic(topic_id).is_empty():
		return { "ok": false, "message": "없는 가이드입니다." }
	if not tutorial_views.has(topic_id):
		tutorial_views.append(topic_id)
		save_game()
	return { "ok": true, "message": "가이드 확인 완료" }

func credits_list() -> Array:
	return CREDITS.duplicate(true)

func emit_feedback(event_id: String, payload := {}) -> Dictionary:
	var event: Dictionary = FEEDBACK_EVENTS.get(event_id, FEEDBACK_EVENTS["ui_confirm"]).duplicate(true)
	feedback_log.append({
		"id": event_id,
		"label": event.get("label", event_id),
		"payload": payload,
		"tick": Time.get_ticks_msec(),
	})
	if feedback_log.size() > 40:
		feedback_log = feedback_log.slice(feedback_log.size() - 40, feedback_log.size())
	_play_feedback_tone(event)
	return { "ok": true, "message": "피드백: %s" % str(event.get("label", event_id)) }

func _play_feedback_tone(event: Dictionary) -> void:
	_normalize_settings()
	if DisplayServer.get_name() == "headless":
		return
	var master := float(user_settings.get("master_volume", 1.0))
	var sfx := float(user_settings.get("sfx_volume", 1.0))
	if master <= 0.01 or sfx <= 0.01:
		return
	var mix_rate := 22050
	var duration_ms := int(event.get("ms", 60))
	var sample_count := maxi(32, int(float(mix_rate) * float(duration_ms) / 1000.0))
	var freq := float(event.get("freq", 440.0))
	var amp := int(42.0 * master * sfx)
	var data := PackedByteArray()
	data.resize(sample_count)
	for i in range(sample_count):
		var fade := 1.0 - (float(i) / float(sample_count))
		var sample := 128 + int(sin(TAU * freq * float(i) / float(mix_rate)) * float(amp) * fade)
		data[i] = clampi(sample, 0, 255)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	var player := AudioStreamPlayer.new()
	player.stream = wav
	player.volume_db = -6.0
	add_child(player)
	player.finished.connect(func(): player.queue_free())
	player.play()

func feedback_screen_flash(event_id: String) -> void:
	if bool(settings_copy().get("reduced_motion", false)):
		return
	var event: Dictionary = FEEDBACK_EVENTS.get(event_id, FEEDBACK_EVENTS["ui_confirm"])
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = event.get("color", Color(1, 1, 1, 0.16))
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func(): layer.queue_free())

func compose_battle_feedback(win: bool, metrics := {}) -> Dictionary:
	var elapsed_sec := float(metrics.get("elapsed", 0.0))
	var soshin_used := int(metrics.get("soshin", 0))
	var burned := int(metrics.get("burned", 0))
	var ally_max := maxf(1.0, float(metrics.get("ally_hp_max", ALLY_CORE_HP)))
	var ally_pct := clampf(float(metrics.get("ally_hp", ally_max)) / ally_max, 0.0, 1.0)
	var cause := str(metrics.get("cause", ""))
	var grade := "D"
	var grade_desc := "재정비 필요"
	if win:
		if soshin_used == 0 and ally_pct >= 0.95 and elapsed_sec <= 45.0:
			grade = "S"
			grade_desc = "완전 장송"
		elif soshin_used <= 1 and ally_pct >= 0.75:
			grade = "A"
			grade_desc = "안정 돌파"
		elif ally_pct >= 0.45:
			grade = "B"
			grade_desc = "전선 유지"
		else:
			grade = "C"
			grade_desc = "위기 돌파"
	var lines := []
	if win:
		lines.append("전술 평가 %s · %s" % [grade, grade_desc])
		lines.append("생존 %.0f%% · 소신 %d회 · 망자 %d 소실" % [ally_pct * 100.0, soshin_used, burned])
	else:
		lines.append("전술 평가 %s · %s" % [grade, grade_desc])
		lines.append("패인 분석 · %s" % cause)
	var xp_line := "계정 XP +%d · 패스 XP +%d" % [80 if win else 20, 40 if win else 10]
	return {
		"win": win,
		"grade": grade,
		"grade_desc": grade_desc,
		"ally_pct": ally_pct,
		"elapsed": elapsed_sec,
		"soshin": soshin_used,
		"burned": burned,
		"cause": cause,
		"lines": lines,
		"xp_line": xp_line,
	}

func currency_text() -> String:
	return "루멘 %d   골드 %d   모집권 %d" % [lumen, gold, recruit_tickets]

func today_key() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

func account_xp_required(level: int) -> int:
	return 120 + max(0, level - 1) * 40

func grant_account_xp(amount: int, persist := true) -> Dictionary:
	if amount <= 0:
		return { "level": account_level, "leveled": 0 }
	account_xp += amount
	var leveled := 0
	while account_xp >= account_xp_required(account_level):
		account_xp -= account_xp_required(account_level)
		account_level += 1
		leveled += 1
		gold += 1000 + account_level * 200
	if persist:
		save_game()
	return { "level": account_level, "leveled": leveled }

func account_text() -> String:
	return "계정 Lv.%d  XP %d/%d" % [account_level, account_xp, account_xp_required(account_level)]

func character_level(cname: String) -> int:
	if unlocked.has(cname) and not character_levels.has(cname):
		character_levels[cname] = 1
	return int(character_levels.get(cname, 1))

func character_upgrade_cost(cname: String) -> int:
	return character_level(cname) * 500

func upgrade_character(cname: String) -> Dictionary:
	if not unlocked.has(cname):
		return { "ok": false, "message": "아직 합류하지 않은 캐릭터입니다." }
	var level := character_level(cname)
	if level >= CHARACTER_MAX_LEVEL:
		return { "ok": false, "message": "이미 최대 레벨입니다." }
	var cost := character_upgrade_cost(cname)
	if gold < cost:
		return { "ok": false, "message": "골드가 부족합니다. 필요 골드 %d" % cost }
	gold -= cost
	character_levels[cname] = level + 1
	_bump_daily_activity("upgrade", 1)
	grant_account_xp(20, false)
	emit_feedback("reward", { "source": "upgrade", "character": cname })
	save_game()
	return { "ok": true, "message": "%s Lv.%d 달성" % [cname, level + 1] }

func _upgrade_count() -> int:
	var total := 0
	for cname in character_levels.keys():
		total += max(0, int(character_levels[cname]) - 1)
	return total

func rewards_text(rewards: Dictionary) -> String:
	var parts := []
	if int(rewards.get("lumen", 0)) > 0:
		parts.append("루멘 +%d" % int(rewards["lumen"]))
	if int(rewards.get("gold", 0)) > 0:
		parts.append("골드 +%d" % int(rewards["gold"]))
	if int(rewards.get("recruit_tickets", 0)) > 0:
		parts.append("모집권 +%d" % int(rewards["recruit_tickets"]))
	if int(rewards.get("brand_points", 0)) > 0:
		parts.append("각인재 +%d" % int(rewards["brand_points"]))
	if int(rewards.get("account_xp", 0)) > 0:
		parts.append("계정 XP +%d" % int(rewards["account_xp"]))
	if int(rewards.get("pass_xp", 0)) > 0:
		parts.append("패스 XP +%d" % int(rewards["pass_xp"]))
	return " · ".join(parts) if not parts.is_empty() else "보상 없음"

func ensure_mailbox(persist := true) -> Array:
	if mailbox.is_empty():
		for seed_mail in MAIL_SEED:
			var mail: Dictionary = seed_mail.duplicate(true)
			mail["claimed"] = false
			mailbox.append(mail)
		if persist:
			save_game()
	return mailbox.duplicate(true)

func mail_list() -> Array:
	return ensure_mailbox(false)

func claim_mail(mail_id: String) -> Dictionary:
	ensure_mailbox(false)
	for i in range(mailbox.size()):
		var mail: Dictionary = mailbox[i]
		if str(mail.get("id", "")) != mail_id:
			continue
		if bool(mail.get("claimed", false)):
			return { "ok": false, "message": "이미 받은 우편입니다." }
		var rewards: Dictionary = mail.get("rewards", {})
		mail["claimed"] = true
		mailbox[i] = mail
		grant_rewards(rewards)
		emit_feedback("reward", { "source": "mail", "id": mail_id })
		save_game()
		return { "ok": true, "message": "%s 수령: %s" % [str(mail.get("title", "")), rewards_text(rewards)] }
	return { "ok": false, "message": "없는 우편입니다." }

func claim_all_mail() -> Dictionary:
	ensure_mailbox(false)
	var count := 0
	var total_rewards := {}
	for i in range(mailbox.size()):
		var mail: Dictionary = mailbox[i]
		if bool(mail.get("claimed", false)):
			continue
		var rewards: Dictionary = mail.get("rewards", {})
		_merge_rewards(total_rewards, rewards)
		mail["claimed"] = true
		mailbox[i] = mail
		grant_rewards(rewards)
		count += 1
	if count <= 0:
		return { "ok": false, "message": "수령할 우편이 없습니다." }
	emit_feedback("reward", { "source": "mail_all", "count": count })
	save_game()
	return { "ok": true, "message": "우편 %d개 수령: %s" % [count, rewards_text(total_rewards)] }

func _merge_rewards(into: Dictionary, rewards: Dictionary) -> void:
	for key in rewards.keys():
		into[key] = int(into.get(key, 0)) + int(rewards[key])

func mission_defs() -> Array:
	return MISSION_DEFS.duplicate(true)

func _mission_def(mission_id: String) -> Dictionary:
	for mission in MISSION_DEFS:
		if str(mission.get("id", "")) == mission_id:
			return mission.duplicate(true)
	return {}

func mission_claim_key(mission: Dictionary) -> String:
	if str(mission.get("category", "")) == "일일":
		return "%s@%s" % [str(mission.get("id", "")), today_key()]
	return str(mission.get("id", ""))

func mission_progress(mission: Dictionary) -> Dictionary:
	var target := int(mission.get("target", 1))
	var value := _mission_value(mission)
	var key := mission_claim_key(mission)
	return {
		"value": min(value, target),
		"target": target,
		"complete": value >= target,
		"claimed": claimed_missions.has(key),
		"key": key,
	}

func _mission_value(mission: Dictionary) -> int:
	match str(mission.get("kind", "")):
		"daily_counter":
			_ensure_daily_activity()
			return int(daily_activity.get(str(mission.get("counter", "")), 0))
		"clear_count":
			return cleared.size()
		"owned_count":
			return unlocked.size()
		"upgrade_count":
			return _upgrade_count()
		"shop_event_count":
			return monetization_events.size()
		_:
			return 0

func claim_mission(mission_id: String) -> Dictionary:
	var mission := _mission_def(mission_id)
	if mission.is_empty():
		return { "ok": false, "message": "없는 미션입니다." }
	var progress := mission_progress(mission)
	if bool(progress.get("claimed", false)):
		return { "ok": false, "message": "이미 받은 미션입니다." }
	if not bool(progress.get("complete", false)):
		return { "ok": false, "message": "아직 완료되지 않았습니다." }
	claimed_missions.append(str(progress.get("key", "")))
	if claimed_missions.size() > 200:
		claimed_missions = claimed_missions.slice(claimed_missions.size() - 200, claimed_missions.size())
	var rewards: Dictionary = mission.get("rewards", {})
	grant_rewards(rewards)
	var pass_gain := int(mission.get("pass_xp", 0))
	battle_pass_xp += pass_gain
	grant_account_xp(int(mission.get("account_xp", 0)), false)
	emit_feedback("reward", { "source": "mission", "id": mission_id })
	save_game()
	var extra := []
	if pass_gain > 0:
		extra.append("패스 XP +%d" % pass_gain)
	if int(mission.get("account_xp", 0)) > 0:
		extra.append("계정 XP +%d" % int(mission.get("account_xp", 0)))
	var reward_line := rewards_text(rewards)
	if not extra.is_empty():
		reward_line += " · " + " · ".join(extra)
	return { "ok": true, "message": "%s 완료: %s" % [str(mission.get("title", "")), reward_line] }

func battle_pass_level() -> int:
	var earned := 1 + int(floor(float(battle_pass_xp) / float(BATTLE_PASS_XP_PER_LEVEL)))
	var cap := int(BATTLE_PASS_TRACK[BATTLE_PASS_TRACK.size() - 1].get("level", 1))
	return clampi(earned, 1, cap)

func battle_pass_track() -> Array:
	return BATTLE_PASS_TRACK.duplicate(true)

func claim_battle_pass(level: int) -> Dictionary:
	var key := str(level)
	if battle_pass_claimed.has(key):
		return { "ok": false, "message": "이미 받은 패스 보상입니다." }
	if level > battle_pass_level():
		return { "ok": false, "message": "아직 도달하지 않은 패스 레벨입니다." }
	for reward_def in BATTLE_PASS_TRACK:
		if int(reward_def.get("level", 0)) != level:
			continue
		var rewards: Dictionary = reward_def.get("rewards", {})
		battle_pass_claimed.append(key)
		grant_rewards(rewards)
		emit_feedback("reward", { "source": "battle_pass", "level": level })
		save_game()
		return { "ok": true, "message": "%s 수령: %s" % [str(reward_def.get("title", "")), rewards_text(rewards)] }
	return { "ok": false, "message": "없는 패스 보상입니다." }

func claim_daily_reward() -> Dictionary:
	var today := today_key()
	if last_daily_claim == today:
		return { "ok": false, "message": "오늘 출석 보상을 이미 받았습니다." }
	last_daily_claim = today
	grant_rewards({ "lumen": 80, "gold": 2500, "recruit_tickets": 1 })
	_bump_daily_activity("login", 1)
	emit_feedback("reward", { "source": "daily" })
	save_game()
	return { "ok": true, "message": "출석 보상: 루멘 80 · 골드 2500 · 모집권 1" }

func grant_rewards(rewards: Dictionary) -> void:
	lumen += int(rewards.get("lumen", 0))
	gold += int(rewards.get("gold", 0))
	recruit_tickets += int(rewards.get("recruit_tickets", 0))
	brand_points += int(rewards.get("brand_points", 0))
	battle_pass_xp += int(rewards.get("pass_xp", 0))
	grant_account_xp(int(rewards.get("account_xp", 0)), false)

func spend_gacha_cost(count: int) -> bool:
	if recruit_tickets >= count:
		recruit_tickets -= count
		return true
	var cost_lumen := GACHA_SINGLE_LUMEN * count
	if count >= 10:
		cost_lumen = GACHA_TEN_LUMEN
	if lumen >= cost_lumen:
		lumen -= cost_lumen
		return true
	return false

func draw_gacha(count: int) -> Dictionary:
	if count != 1 and count != 10:
		return { "ok": false, "message": "모집은 1회 또는 10회만 가능합니다.", "results": [] }
	if not spend_gacha_cost(count):
		return { "ok": false, "message": "모집권 또는 루멘이 부족합니다.", "results": [] }
	var results := []
	var has_sr_or_better := false
	for i in count:
		var min_rarity := ""
		if count == 10 and i == count - 1 and not has_sr_or_better:
			min_rarity = "SR"
		var forced_ssr := gacha_pity + 1 >= GACHA_PITY_LIMIT
		var item := _roll_gacha("SSR" if forced_ssr else min_rarity)
		gacha_pity += 1
		if str(item["rarity"]) == "SSR":
			gacha_pity = 0
		if _rarity_rank(str(item["rarity"])) >= _rarity_rank("SR"):
			has_sr_or_better = true
		var grant := _grant_character_from_gacha(str(item["name"]), str(item["rarity"]))
		grant["rarity"] = item["rarity"]
		grant["name"] = item["name"]
		results.append(grant)
		_append_gacha_history(grant)
	_bump_daily_activity("gacha", count)
	emit_feedback("reward", { "source": "gacha", "count": count })
	save_game()
	return { "ok": true, "message": "%d회 모집 완료" % count, "results": results }

func _roll_gacha(min_rarity := "") -> Dictionary:
	var pool := []
	for item in GACHA_POOL:
		if min_rarity != "" and _rarity_rank(str(item["rarity"])) < _rarity_rank(min_rarity):
			continue
		pool.append(item)
	if pool.is_empty():
		pool = GACHA_POOL.duplicate(true)
	var total := 0
	for item in pool:
		total += int(item["weight"])
	var roll := randi_range(1, total)
	var acc := 0
	for item in pool:
		acc += int(item["weight"])
		if roll <= acc:
			return item.duplicate(true)
	return pool[0].duplicate(true)

func _grant_character_from_gacha(cname: String, rarity: String) -> Dictionary:
	var duplicate := unlocked.has(cname)
	var shard_gain := _duplicate_shards(rarity) if duplicate else 0
	if duplicate:
		character_shards[cname] = int(character_shards.get(cname, 0)) + shard_gain
		gold += shard_gain * 40
	else:
		unlocked.append(cname)
		character_levels[cname] = 1
	return { "duplicate": duplicate, "shards": shard_gain }

func _duplicate_shards(rarity: String) -> int:
	match rarity:
		"SSR":
			return 50
		"SR":
			return 20
		_:
			return 5

func _rarity_rank(rarity: String) -> int:
	match rarity:
		"SSR":
			return 3
		"SR":
			return 2
		_:
			return 1

func _append_gacha_history(entry: Dictionary) -> void:
	gacha_history.append({
		"name": entry.get("name", ""),
		"rarity": entry.get("rarity", ""),
		"duplicate": entry.get("duplicate", false),
		"shards": entry.get("shards", 0),
	})
	if gacha_history.size() > 30:
		gacha_history = gacha_history.slice(gacha_history.size() - 30, gacha_history.size())

func gacha_rates_text() -> String:
	var total := 0
	var rarity_weights := { "R": 0, "SR": 0, "SSR": 0 }
	for item in GACHA_POOL:
		total += int(item["weight"])
		var rarity := str(item["rarity"])
		rarity_weights[rarity] = int(rarity_weights.get(rarity, 0)) + int(item["weight"])
	var parts := []
	for rarity in ["SSR", "SR", "R"]:
		var pct := 100.0 * float(rarity_weights[rarity]) / float(total)
		parts.append("%s %.1f%%" % [rarity, pct])
	return " / ".join(parts) + "   ·   SSR 천장 %d회" % GACHA_PITY_LIMIT

func buy_shop_pack(pack_id: String) -> Dictionary:
	for pack in SHOP_PACKS:
		if pack["id"] != pack_id:
			continue
		var bought := int(shop_claims.get(pack_id, 0))
		var limit := int(pack.get("limit", 99))
		if bought >= limit:
			return { "ok": false, "message": "구매 제한에 도달했습니다." }
		shop_claims[pack_id] = bought + 1
		grant_rewards(pack.get("rewards", {}))
		monetization_events.append({ "pack": pack_id, "price_label": pack.get("price_label", ""), "test": true })
		if monetization_events.size() > 30:
			monetization_events = monetization_events.slice(monetization_events.size() - 30, monetization_events.size())
		_bump_daily_activity("shop", 1)
		emit_feedback("reward", { "source": "shop", "pack": pack_id })
		save_game()
		return { "ok": true, "message": "%s 지급 완료" % pack["title"] }
	return { "ok": false, "message": "없는 상품입니다." }

func chat_list() -> Array:
	if chat_messages.is_empty():
		chat_messages = CHAT_SEED.duplicate(true)
	return chat_messages.duplicate(true)

func send_chat_message(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean == "":
		return { "ok": false, "message": "빈 메시지는 보낼 수 없습니다." }
	if clean.length() > 80:
		clean = clean.substr(0, 80)
	chat_messages.append({ "speaker": "집전관", "text": clean, "system": false })
	if chat_messages.size() > 40:
		chat_messages = chat_messages.slice(chat_messages.size() - 40, chat_messages.size())
	_bump_daily_activity("chat", 1)
	emit_feedback("ui_confirm", { "source": "chat" })
	save_game()
	return { "ok": true, "message": "전송 완료" }

# ---------- 진행 갱신 ----------
func on_battle_end(win: bool, metrics := {}) -> void:
	last_win = win
	last_unlocked_name = ""
	last_brand_reward = false
	_bump_daily_activity("battle", 1)
	last_battle_feedback = compose_battle_feedback(win, metrics)
	emit_feedback("battle_win" if win else "battle_loss", last_battle_feedback)
	if win:
		_bump_daily_activity("battle_win", 1)
		battle_pass_xp += 40
		grant_account_xp(80, false)
	else:
		battle_pass_xp += 10
		grant_account_xp(20, false)
	var st := current_stage_def()
	last_result_record = {
		"stage_id": st.get("id", ""),
		"stage_name": st.get("name", ""),
		"win": win,
		"rules": st.get("rule_tags", []),
		"grade": last_battle_feedback.get("grade", "D"),
		"elapsed": float(metrics.get("elapsed", 0.0)),
		"soshin": int(metrics.get("soshin", 0)),
	}
	run_records.append(last_result_record)
	if run_records.size() > 20:
		run_records = run_records.slice(run_records.size() - 20, run_records.size())
	if not win:
		save_game()
		return
	if str(st.get("id", "")).begins_with("loop_"):
		challenge_seed += 1
		save_game()
		return
	if not cleared.has(st["id"]):
		cleared.append(st["id"])
		brand_points += 1
		last_brand_reward = true
	var reward: String = st.get("unlock", "")
	if reward != "" and not unlocked.has(reward):
		unlocked.append(reward)
		character_levels[reward] = 1
		last_unlocked_name = reward
	# 다음 스테이지로 진행 포인터 이동
	if current_stage + 1 < STAGES.size():
		current_stage += 1
	save_game()

# ---------- 씬 이동 ----------
func goto(scene_path: String) -> void:
	emit_feedback("navigate", { "scene": scene_path })
	if bool(settings_copy().get("reduced_motion", false)) or transition_active:
		get_tree().change_scene_to_file(scene_path)
		return
	transition_active = true
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.015, 0.025, 0.03, 1.0)
	rect.modulate.a = 0.0
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 1.0, 0.14)
	tw.tween_callback(func(): get_tree().change_scene_to_file(scene_path))
	tw.tween_property(rect, "modulate:a", 0.0, 0.18)
	tw.tween_callback(func():
		transition_active = false
		layer.queue_free())
