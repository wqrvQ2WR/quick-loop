extends Node3D

const SAVE_PATH := "user://quickloop_save.cfg"
var start_time := 60.0
const REACH_DIST := 8.0
const GOAL := 1000000.0
const COLD_PAY := 0.001
const CRASH_PAY := 100.0
const SPECIAL_EVERY := 5
const SPECIAL_PAY := 60000.0
const SPECIAL_DAMAGE_COST := 15000.0
const TIME_FLOOR := -120.0
var leg_time := 60.0
const LEG_TIME_MIN := 30.0
const LEG_DECAY := 1.5

enum State { TITLE, STORY, PLAY, MENU, RESULT }

var state: State = State.TITLE
var city: City
var car: Car
var cam: Camera3D

var time_left := 60.0
var score := 0.0
var combo := 0
var deliveries := 0
var crashes := 0
var bumps := 0
var cold_deliveries := 0
var elapsed := 0.0
var was_cold := false
var special_order := false
var special_damage := 0
var special_done := 0
var upgrade_levels := {}
var achieved := {}
var goal_reached := false
var horn_cooldown := 0.0
var horns := 0
var was_honking := false
var pickup_at := 0.0
var best_leg := 0.0
var leg_grant := 60.0
var leg_mod: Dictionary = {}
var tips_total := 0.0
var stunt_total := 0.0
var drift_total := 0.0
var drift_boosts := 0
var best_drift := 0.0
var drift_bar: ColorRect
var drift_bg: ColorRect
var drift_label: Label
var crash_total := 0.0
var air_bonuses := 0
var near_cooldown := 0.0
var _break_shape: BoxShape3D = null
var _break_query: PhysicsShapeQueryParameters3D = null
var things_flattened := 0
var was_airborne := false
var tutorial_step := -1
var tutorial_done := false
var debug_events := false
var debug_no_save := false
var cows_hit := 0
var top_speed := 0.0
var has_package := false
var target_pos := Vector3.ZERO
var best_score := 0.0
var career_earnings := 0.0
var selected_district := 0
var rival_kills := 0
var rivals: Array[RivalCar] = []
var money_drops: Array[MoneyDrop] = []
var shoot_cooldown := 0.0
var player_hit_cooldown := 0.0
var times_shot := 0
var times_punched := 0
var player_hp := 140.0


func max_hp() -> float:
	return BASE_PLAYER_HP + float(upgrade_levels.get("armor", 0)) * ARMOR_HP_PER_LV
var deaths := 0
var seen_unlock_cutscene := {}
var cut_root: Control
var cut_title: Label
var cut_name: Label
var cut_line: Label
var cut_art: Control
var cut_timer := 0.0
var pending_cutscenes: Array[int] = []
var no_damage_time := 0.0
const BASE_PLAYER_HP := 140.0
const ARMOR_HP_PER_LV := 35.0
const DEATH_MONEY_LOSS := 0.07
const HP_REGEN := 7.0        # 안전구역에서 초당 회복
const ZONE_DPS := 9.0        # 자기장 밖 초당 피해
const GUN_DAMAGE := 7.0
const PUNCH_DAMAGE := 11.0
var ram_cooldown := 0.0
var punch_cooldown := 0.0
var punches_landed := 0
var bluezone_active := false
var macho_active := false
var bluezone_radius := 0.0
var bluezone_center := Vector3.ZERO
var bluezone_mesh: MeshInstance3D
var bluezone_warning_cooldown := 0.0
var debug_bz_radius := -1.0
var debug_freecam := false   # 켜면 카메라가 차를 안 따라간다(촬영용)
# 시점 전환. V 로 돌린다.
enum CamMode { CHASE, HOOD, FIRST, TOP, SIDE, TRIP }
const CAM_NAMES := ["기본 추격", "본넷", "운전석 1인칭", "탑뷰", "시네마 측면", "무지개 환각"]
const CAM_LINES := [
	"어깨 너머로 보는 기본 시점입니다",
	"본넷 위. 속도감은 좋은데 앞이 좁습니다",
	"운전석입니다. 핸들과 계기판이 보입니다",
	"위에서 내려다봅니다. 지도 같아서 길이 잘 보입니다",
	"영화처럼 옆에서 잡습니다. 운전은 알아서 하십시오",
	"뭘 드셨습니까. 카메라가 빙빙 돌고 세상이 무지개입니다",
]
var trip_rect: TextureRect
var trip_rect2: TextureRect
var trip_t := 0.0
var cam_mode := 0
var cam_switched := false   # 튜토리얼에서 V 를 눌렀는지
# 자기장은 가운데로만 줄지 않는다. 배그처럼 다음 원이 현재 원 안쪽 아무 데나 잡히고,
# 대기 -> 수축 을 반복하면서 중심이 통째로 이동한다.
const ZONE_MIN_RADIUS := 130.0
const ZONE_WAIT := 17.0        # 다음 원이 표시되고 수축까지 기다리는 시간
const ZONE_SHRINK := 21.0      # 수축에 걸리는 시간
var zone_wait := 0.0
var zone_shrink_left := 0.0
var zone_from_center := Vector3.ZERO
var zone_from_radius := 0.0
var zone_next_center := Vector3.ZERO
var zone_next_radius := 0.0
var zone_phase := 0
var supply_crate: Node3D
var supplies_taken := 0

var shake := 0.0
var botplay := false
var bot_speed := 55.0
var cam_pos := Vector3(0, 12, 24)
var arrow: Node3D
var marker: Node3D
var marker_ring: MeshInstance3D
var marker_pillar: MeshInstance3D

# UI
var ui: CanvasLayer
var title_root: Control
var hud_root: Control
var result_root: Control
var lbl_time: Label
var lbl_score: Label
var lbl_combo: Label
var lbl_speed: Label
var lbl_dist: Label
var lbl_task: Label
var toast_slots: Array[Label] = []
var toast_ages: Array[float] = [99.0, 99.0, 99.0]
var _last_line := ""
var _bags := {}
var lbl_pop: Label
var boost_bar: ColorRect
var hp_bar: ColorRect
var hp_bg: ColorRect
var hp_label: Label
var goal_bar: ColorRect
var lbl_goal: Label
var crosshair: Label
var scope: Scope
var aiming := false
var aim_t := 0.0        # 0 = 평소, 1 = 완전 줌
var aim_yaw := 0.0      # 조준 중 마우스로 돌린 좌우 각 (차 기준)
var aim_pitch := 0.0
var _aim_hid_body := false
const AIM_FOV := 48.0   # 레드닷. 기본 70 대비 약 1.5배. 배율경이 아니라 시야가 살아야 한다
const AIM_SENS := 0.0022
const AIM_YAW_LIMIT := 1.45    # 약 83도. 목이 돌아가는 한계
const AIM_PITCH_LIMIT := 0.55
var minimap: Minimap
var menu: GameMenu
var world_env: Environment
var world_sky: ProceduralSkyMaterial
var world_sun: DirectionalLight3D
var day_t := 0.0
var debug_day := -1.0
var debug_theme := -1
var tut_root: Control
var tut_label: Label
var tut_sub: Label
var ach_root: Control
var ach_panel: Control
var ach_name: Label
var ach_desc: Label
var ach_queue: Array = []
var ach_timer := 0.0
var story_root: Control
var story_label: Label
var story_index := 0
var result_body: Label
var result_title: Label
var result_rating: Label
var result_comment: Label
var pop_timer := 0.0

const UPGRADES := [
	{"key": "engine", "name": "터보 엔진", "desc": "최고속 +5 · 부스터 최고속 +7", "extra": "스포일러가 달린다", "cost": [12000, 28000, 60000]},
	{"key": "boost", "name": "치킨 파워 부스터", "desc": "연료 회복 +6 · 소모 -20% · 부스터 최고속 +5", "extra": "네온 언더글로우", "cost": [12000, 28000, 60000]},
	{"key": "tire", "name": "광폭 타이어", "desc": "조향 속도 +0.45", "extra": "바퀴가 굵어진다", "cost": [10000, 24000, 50000]},
	{"key": "rocket", "name": "로켓 노즐", "desc": "로켓 점프력 +4.5", "extra": "후미에 노즐이 달린다", "cost": [8000, 20000, 40000]},
	{"key": "pack", "name": "에어백 과다 장착", "desc": "충돌 시간 손해 -30% · RTX 파손비 -30%", "extra": "앞뒤 범퍼가 붙는다", "cost": [14000, 34000, 70000]},
	{"key": "warm", "name": "핵융합 보온가방", "desc": "구간 제한시간 +6초", "extra": "배달통이 커진다", "cost": [14000, 34000, 70000]},
	{"key": "armor", "name": "방탄 강판", "desc": "최대 체력 +35 (마초·배그 구역 전용)", "extra": "차체에 철판이 덧대진다", "cost": [20000, 48000, 100000]},
	{"key": "pay", "name": "단골 명단", "desc": "배달 보수 +18%", "extra": "배달통에 별점 스티커가 붙는다", "cost": [18000, 42000, 90000, 170000]},
]

const ACHIEVEMENTS := [
	{"key": "first", "name": "첫 배달", "desc": "배달 1건 완료"},
	{"key": "combo10", "name": "단골 확보", "desc": "연속 배달 10건"},
	{"key": "cow10", "name": "음메", "desc": "소 10마리 접촉"},
	{"key": "scratch50", "name": "도색 전문가", "desc": "긁힘 50회"},
	{"key": "gta", "name": "GTA 하십니까?", "desc": "대형사고 20회"},
	{"key": "cold5", "name": "냉동창고", "desc": "식은 배달 5건"},
	{"key": "brick", "name": "벽돌 제조업자", "desc": "RTX를 3번 이상 파손하고 배달"},
	{"key": "perfect_rtx", "name": "무사고 배송", "desc": "RTX를 무파손으로 배달"},
	{"key": "fast", "name": "과속 단속 카메라", "desc": "200 km/h 돌파"},
	{"key": "air", "name": "우주여행", "desc": "공중에 2초 이상 체류"},
	{"key": "tuned", "name": "튜닝의 끝은 순정", "desc": "업그레이드 총 6레벨"},
	{"key": "horn30", "name": "빵빵", "desc": "경적 30회"},
	{"key": "iceage", "name": "아이스 에이지!", "desc": "식은 배달 10건"},
	{"key": "speedrun", "name": "스피드러너", "desc": "픽업 후 10초 안에 배달"},
	{"key": "acrobat", "name": "곡예 배달", "desc": "에어타임 보너스 10회"},
	{"key": "drifter", "name": "옆으로 배달", "desc": "드리프트 부스터 15회"},
	{"key": "tiprich", "name": "팁 부자", "desc": "팁 누적 100,000원"},
	{"key": "rival1", "name": "시장 점유율 확보", "desc": "경쟁사 배달차 1대 격추"},
	{"key": "rival10", "name": "독점 기업", "desc": "경쟁사 배달차 10대 격추"},
	{"key": "pubg_clear", "name": "이겼닭! 오늘 저녁은 치킨이닭!", "desc": "배그 전장에서 100만원 달성"},
	{"key": "district_all", "name": "전국구 배달왕", "desc": "모든 구역 해금"},
	{"key": "day1", "name": "1일차 종료", "desc": "100만원 달성"},
]

const ORDER_MODS := [
	{"key": "vip", "name": "VIP 주문", "note": "보수 2배 · 제한시간 30% 삭감",
	 "pay": 2.0, "time": 0.7, "speed": 1.0, "turn": 1.0, "crash": 1.0,
	 "line": "구청장 아들 주문입니다. 늦으면 안 됩니다"},
	{"key": "big", "name": "곱빼기", "note": "보수 1.4배 · 무거워서 느림",
	 "pay": 1.4, "time": 1.0, "speed": 0.85, "turn": 1.0, "crash": 1.0,
	 "line": "곱빼기 3인분입니다. 차가 주저앉습니다"},
	{"key": "soup", "name": "국물 요리", "note": "보수 1.5배 · 충돌 시 시간 손해 2배",
	 "pay": 1.5, "time": 1.0, "speed": 1.0, "turn": 1.0, "crash": 2.0,
	 "line": "뚜껑이 없습니다. 조심하세요"},
	{"key": "rain", "name": "폭우 배송", "note": "보수 1.6배 · 빗길에 심하게 미끄러짐",
	 "pay": 1.6, "time": 1.0, "speed": 1.0, "turn": 0.95, "crash": 1.0, "grip": 0.16,
	 "line": "비가 옵니다. 타이어가 웁니다"},
]

const TUTORIAL := [
	{"t": "W 를 꾹 눌러 출발", "s": "S 는 브레이크와 후진"},
	{"t": "A / D 로 방향을 튼다", "s": "속도가 붙어야 잘 돈다"},
	{"t": "초록 기둥으로 가서 음식을 받는다", "s": "화살표와 우측 상단 미니맵을 보면 된다"},
	{"t": "E 를 눌러 부스터", "s": "게이지를 태워 최고속을 올린다"},
	{"t": "SPACE 로 로켓 점프", "s": "0.8초 이상 떠 있다가 착지하면 에어타임 보너스"},
	{"t": "주황 기둥의 고객에게 배달", "s": "빨리 갈수록 팁이 붙는다"},
	{"t": "SHIFT 를 물고 코너를 돌아 드리프트", "s": "게이지가 차면 손을 떼는 순간 부스터가 터진다"},
	{"t": "V 로 시점 전환", "s": "추격 · 본넷 · 운전석 · 탑뷰 · 측면 · 무지개 환각 6종"},
	{"t": "ESC 를 누르면 메뉴", "s": "업그레이드 · 도전과제 · 설정. 아무 키나 눌러 시작"},
]

const STORY := [
	"2047년. 대한민국.",
	"당신은 평범한 배달원이었다.",
	"어느 날 치킨 한 마리를 배달하다가\n대통령 전용기에 국물을 쏟았다.",
	"전용기는 추락했다.\n다행히 아무도 타고 있지 않았다.",
	"불행히도 전용기 안에는\n국가 예산 전액이 실려 있었다.",
	"법원은 당신에게 100만원의 배상을 명령했다.",
	"국가 예산 전액이 100만원이었던 것이다.",
	"오늘 안에 갚아라.",
	"목표: 100만원",
]

var crash_lines := [
	"운전면허 어디서 땄냐",
	"차 수리비는 당신 부담",
	"고객이 창밖을 보고 있었습니다",
	"국물 다 쏟음",
	"보험사에 연락하세요",
	"방금 그거 벽이었는데요",
	"핸들은 장식이 아닙니다",
	"음식이 벽을 정면으로 봤습니다",
	"평점 1점 예약되었습니다",
	"그 건물 원래 거기 있었어요",
	"브레이크 밟는 법 알려드릴까요",
	"차체가 조금 짧아졌습니다",
	"오늘만 세 번째입니다",
	"에어백은 옵션이었습니다",
	"다시 조리해야 할 것 같습니다",
	"벽이 먼저 시비 걸었다고 하세요",
	"방금 소리 사장님까지 들렸습니다",
	"보닛이 인사를 했습니다",
	"GTA 하십니까?",
]
var bump_lines := [
	"긁혔습니다",
	"지금 뭐 스쳤는데요",
	"범퍼가 인사했습니다",
	"그건 제 잘못 아닙니다",
	"사이드미러는 왜 달았나요",
	"3cm 남았었는데",
	"도색비 나왔습니다",
	"원래 저기 흠집 있었어요",
	"이 정도는 무상수리 됩니다",
	"블랙박스는 꺼두겠습니다",
	"살짝인데 소리만 컸습니다",
	"단무지 하나 튀어나갔습니다",
	"차선이 좁은 게 문제죠",
	"방금 건 못 본 걸로",
	"운전은 감이라면서요",
	"주차장 긁은 수준입니다",
	"고객님 음식은 아직 무사합니다",
	"연비가 떨어지는 소리",
	"그 벽 튼튼하네요",
	"살짝 닿은 겁니다 진짜로",
]
var scrape_lines := [
	"계속 벽 긁고 계신데요",
	"그 벽이랑 친하세요",
	"도색이 벽으로 옮겨가는 중",
	"직진이라는 개념을 아십니까",
	"벽 따라가면 도착 안 합니다",
	"스파크 예쁘긴 하네요",
	"이거 나중에 다 청구됩니다",
	"벽지 무늬가 차에 찍혔습니다",
	"그쪽은 길이 아닙니다",
	"벽이 아프다고 합니다",
]
var land_lines := [
	"착지 성공. 서스펜션은 사망",
	"바퀴 네 개 다 붙었습니다",
	"방금 그거 왜 뛴 건가요",
	"음식이 천장을 봤습니다",
	"하체에서 이상한 소리가 납니다",
	"착지했는데 뭔가 하나 떨어졌습니다",
	"서스펜션이 항의했습니다",
	"방금 그거 차가 할 동작 아닙니다",
	"바닥이 먼저 사과했습니다",
	"배달통 안이 궁금해집니다",
]
var deliver_lines := [
	"배달 완료! 국물 90% 사수",
	"고객 감동 (아마도)",
	"따뜻하게 도착했습니다",
	"단무지는 빠졌습니다",
	"리뷰 이벤트 참여 부탁드려요",
	"현관 앞에 던졌습니다",
	"형체는 남아 있습니다",
	"고객이 문을 안 열어줬습니다",
	"문고리에 걸어뒀습니다",
	"벨은 두 번 눌렀습니다",
	"고객이 맨발로 뛰어나왔습니다",
	"별점은 기대하지 마세요",
]
var pickup_lines := [
	"음식 실었다! 밟아!",
	"뜨거우니 조심",
	"사장님이 서비스 주심",
	"포장 완료. 출발.",
	"국물 넘칠 것 같은데요",
	"주문번호 확인했습니다. 아마도",
	"뚜껑 잘 닫았습니다. 아마도",
	"사장님이 빨리 가라고 손짓합니다",
	"영수증은 안에 넣어뒀습니다",
	"따뜻할 때 가져다주세요",
]
var cow_lines := [
	"소 미안",
	"방금 그거 소였습니다",
	"소 한 마리 추가 배달",
	"음메",
	"축산업계에 사과하세요",
	"소가 날았습니다",
	"소가 번호판을 외웠습니다",
	"목장 주인이 달려옵니다",
	"소도 놀랐습니다",
	"방금 우유가 쏟아졌을 겁니다",
]
var cold_lines := [
	"음식이 식어서 드라이아이스랑 구분이 안 갑니다",
	"음식이 남극에 갔다 왔군요",
	"이거 사실 아이스크림입니다",
	"고객님이 전자레인지를 꺼내셨습니다",
	"국물에 살얼음이 꼈습니다",
	"메뉴가 냉면으로 변경되었습니다",
	"이 온도면 신선식품 취급입니다",
	"면이 불어서 떡이 되었습니다",
	"치킨이 화석이 되었습니다",
	"고객이 환불 버튼을 찾고 있습니다",
	"열역학 제2법칙을 이기지 못했습니다",
	"포장지에 성에가 꼈습니다",
	"이건 배달이 아니라 운반입니다",
	"고객이 다른 곳에서 다시 시켰습니다",
	"배달통에서 냉기가 새어나옵니다",
	"이제 데워도 안 돌아옵니다",
	"고객이 젓가락을 내려놨습니다",
	"배달통이 아니라 냉장고였군요",
	"음식이 겨울잠에 들었습니다",
	"튀김옷이 눅눅함을 넘어 축축합니다",
	"고객이 그냥 라면을 끓였습니다",
	"온도계가 실온을 가리킵니다",
	"이건 배달이 아니라 냉장 유통입니다",
	"김이 한 톨도 안 납니다",
	"고객님이 괜찮다고 합니다. 안 괜찮습니다",
	"치즈가 굳어서 뚜껑에 붙었습니다",
	"소스가 젤리가 됐습니다",
	"사장님께는 비밀로 하겠습니다",
]
var late_lines := [
	"사장님이 기다리다 지치셨습니다",
	"아직 가게에 도착도 못 했습니다",
	"음식은 이미 포장대에서 식는 중입니다",
	"가게 사장님이 전화를 세 번 했습니다",
	"주문이 취소될 것 같은데요",
	"사장님이 셔터를 반쯤 내렸습니다",
	"포장대에 음식이 혼자 앉아 있습니다",
	"다른 기사님이 대신 가져갈 뻔했습니다",
	"가게 리뷰에 기사 욕이 올라왔습니다",
	"사장님이 앞치마를 벗고 계십니다",
	"이 속도면 가게가 먼저 문을 닫습니다",
	"사장님 표정이 굳었습니다",
	"픽업 지점이 도망간 게 아닙니다",
	"내비게이션 탓을 해보세요",
	"기다리던 손님이 직접 가지러 왔습니다",
	"주문번호를 잊어버리셨을 겁니다",
	"가게 앞에 이미 다음 주문이 쌓였습니다",
]
var rtx_damage_lines := [
	"5090이 4090이 됐습니다",
	"5090이 3090이 됐습니다",
	"5090이 1050 Ti가 됐습니다",
	"이제 그냥 벽돌입니다",
	"방열판이 떨어져 나갔습니다",
]
var rtx_pickup_lines := [
	"RTX 5090입니다. 깨지면 당신 인생도 같이 깨집니다",
	"이거 당신 월급 몇 배입니다",
	"뽁뽁이 안 쌌습니다. 알아서 하세요",
	"고객이 3개월을 기다린 물건입니다",
]
var horn_lines := [
	"빵빵거린다고 길이 열리진 않습니다",
	"경적은 무죄입니다",
	"아무도 없는데요",
	"소가 쳐다봅니다",
	"경적 좋아하시네요",
	"소음 민원 들어갑니다",
	"창문 여는 소리가 들립니다",
	"빵빵. 그래서요?",
]
var death_lines := [
	"차가 완전히 주저앉았습니다",
	"견인차가 왔습니다. 수리비는 선불입니다",
	"폐차 직전에서 겨우 살렸습니다",
	"보험사가 전화를 안 받습니다",
	"오늘 번 돈의 일부가 정비소로 갔습니다",
	"부품값이 사람값보다 비쌉니다",
]
var my_punch_lines := [
	"주먹이 나갔습니다",
	"배달원의 분노",
	"이건 정당방위입니다",
	"글러브는 회사 지급품입니다",
	"트럭이 휘청합니다",
	"한 대 갚았습니다",
	"팔이 달린 건 저쪽만이 아닙니다",
	"경적보다 이게 빠릅니다",
]
var whiff_lines := [
	"허공을 갈랐습니다",
	"빗나갔습니다",
	"팔이 짧았습니다",
]
var punch_lines := [
	"마초 트럭에게 한 대 맞았습니다",
	"트럭이 주먹을 휘둘렀습니다",
	"차에 팔이 달려 있으면 안 되는 거 아닙니까",
	"사이드미러가 날아갔습니다",
	"배달통이 휘청했습니다",
	"저건 트럭이 아니라 격투기 선수입니다",
	"맞을 만했습니다",
	"고객님 음식이 흔들렸습니다",
	"주먹에 경적 소리가 섞여 있었습니다",
	"저쪽은 배달할 생각이 없습니다",
]
var ram_lines := [
	"정면으로 들이받았습니다",
	"트럭이 휘청합니다",
	"범퍼로 한 방",
	"이게 우리 회사 방식입니다",
	"상대 배달통이 찌그러졌습니다",
	"주먹 대신 차체로 갚았습니다",
	"저쪽 사이드미러도 날아갔습니다",
	"마짱은 이렇게 하는 겁니다",
]
var shot_lines := [
	"총 맞았습니다. 음식은 무사합니다",
	"경쟁사가 총을 꺼냈습니다",
	"유리창에 구멍 났습니다",
	"저쪽은 배달을 안 할 생각인가 봅니다",
	"산업 스파이가 아니라 그냥 강도입니다",
	"차체에 구멍이 하나 더 늘었습니다",
	"헬멧이 아니라 차가 맞았습니다",
	"이래서 보험이 필요합니다",
	"저쪽 사격 실력이 형편없어서 다행입니다",
	"뚝배기는 아직 멀쩡합니다",
]
var rival_kill_lines := [
	"경쟁사 차량 격파! 배달은 우리가 한다",
	"라이벌 업체 주가가 하락했습니다",
	"독점 체제 구축 완료",
	"사장님이 보너스를 챙겨주십니다",
	"경쟁업체 폐업 처리 완료",
	"이 구역의 배달왕은 나다",
]


func _ready() -> void:
	_setup_world()
	_setup_ui()
	_load_save()
	_check_district_unlocks(true)   # 이미 열려 있던 구역은 연출 없이 흡수
	_show_title()
	debug_events = "events" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("daytime="):
			debug_day = float(a.substr(8))
		if a.begins_with("theme="):
			debug_theme = int(a.substr(6))
			city.rebuild(randi(), debug_theme)
		if a.begins_with("legtime="):
			leg_time = float(a.substr(8))
		if a.begins_with("cam="):
			cam_mode = int(a.substr(4)) % CamMode.size()
		if a.begins_with("bzradius="):
			debug_bz_radius = float(a.substr(9))
		if a.begins_with("turbo="):
			Engine.time_scale = clampf(float(a.substr(6)), 0.1, 20.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("time="):
			start_time = float(a.substr(5))
	if "autostart" in OS.get_cmdline_user_args():
		start_game()
	for a3 in OS.get_cmdline_user_args():
		if a3.begins_with("signart="):
			# 전광판 채널 6개를 각각 PNG 로 떨군다. 화면 내용만 따로 확인용.
			debug_no_save = true
			start_game()
			await get_tree().create_timer(1.2).timeout
			var n := 0
			for ch in city.get_children():
				if ch is SubViewport:
					await RenderingServer.frame_post_draw
					var im: Image = (ch as SubViewport).get_texture().get_image()
					im.save_png("%s%d.png" % [a3.substr(8), n])
					n += 1
			print("[dbg] 전광판 채널 %d장 저장" % n)
			get_tree().quit()
	if "aimshot" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.4).timeout
		tutorial_step = -1
		# 경쟁사 트럭을 앞에 세워두고 조준한 그림을 찍는다
		var fwd2 := -car.global_transform.basis.z
		for r in rivals:
			if is_instance_valid(r):
				r.global_position = car.global_position + fwd2 * 55.0
				break
		_set_aiming(true)
	for a4 in OS.get_cmdline_user_args():
		if a4.begins_with("enginewav="):
			# 엔진음을 오프라인으로 뽑아 WAV 로 저장한다. 게임과 같은 synth_frames() 를 쓴다.
			debug_no_save = true
			start_game()
			await get_tree().create_timer(0.3).timeout
			var rate := int(Car.SND_RATE)
			var pcm := PackedByteArray()
			var peak := 0.0
			var sq := 0.0
			var cnt := 0
			# 공회전 → 가속 → 레드존 → 부스터 → 경적
			var plan := [
				{"t": 1.2, "v": 0.0, "th": 0.0, "bo": false, "hn": false, "name": "공회전"},
				{"t": 5.0, "v": -1.0, "th": 1.0, "bo": false, "hn": false, "name": "가속(변속 포함)"},
				{"t": 1.2, "v": 1.0, "th": 1.0, "bo": false, "hn": false, "name": "레드존"},
				{"t": 1.5, "v": 1.0, "th": 1.0, "bo": true, "hn": false, "name": "부스터"},
				{"t": 1.0, "v": 0.35, "th": 0.0, "bo": false, "hn": false, "name": "스로틀 off"},
				{"t": 0.9, "v": 0.2, "th": 0.3, "bo": false, "hn": true, "name": "경적"},
			]
			for step in plan:
				var secs: float = float(step["t"])
				var total: int = int(secs * float(rate))
				var done := 0
				var seg_peak := 0.0
				while done < total:
					var n: int = mini(2048, total - done)
					var sweep: float = float(step["v"])
					if sweep < 0.0:
						sweep = float(done) / float(total)   # 0 → 1 로 가속
					car.speed = car.max_speed * sweep
					car.boosting = bool(step["bo"])
					car.honking = bool(step["hn"])
					car.last_input = {"throttle": float(step["th"]), "steer": 0.0,
						"jump": false, "boost": bool(step["bo"]), "horn": bool(step["hn"]),
						"drift": false}
					for fr in car.synth_frames(n):
						var l: int = int(clampf(fr.x, -1.0, 1.0) * 32767.0)
						var r: int = int(clampf(fr.y, -1.0, 1.0) * 32767.0)
						pcm.append(l & 0xFF); pcm.append((l >> 8) & 0xFF)
						pcm.append(r & 0xFF); pcm.append((r >> 8) & 0xFF)
						peak = maxf(peak, absf(fr.x))
						seg_peak = maxf(seg_peak, absf(fr.x))
						sq += fr.x * fr.x
						cnt += 1
					done += n
				print("[dbg] %s — rpm %.0f / 구간 피크 %.2f / 터보 스풀 %.2f" % [
					String(step["name"]), car.engine_rpm(), seg_peak, car._spool])
			# 부스터가 음높이를 안 건드리는지 직접 확인
			car.speed = car.max_speed * 0.5
			car.boosting = false
			var r_off := car.engine_rpm()
			car.boosting = true
			var r_on := car.engine_rpm()
			car.boosting = false
			print("[dbg] 절반 속도 rpm — 부스터 끔 %.0f / 켬 %.0f (같아야 정상)" % [r_off, r_on])

			var path := a4.substr(10)
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f == null:
				print("[dbg] WAV 열기 실패: %s" % path)
				get_tree().quit()
			var data_len := pcm.size()
			f.store_buffer("RIFF".to_ascii_buffer())
			f.store_32(36 + data_len)
			f.store_buffer("WAVEfmt ".to_ascii_buffer())
			f.store_32(16)            # fmt 청크 길이
			f.store_16(1)             # PCM
			f.store_16(2)             # 스테레오
			f.store_32(rate)
			f.store_32(rate * 4)      # 바이트/초
			f.store_16(4)             # 블록 정렬
			f.store_16(16)            # 비트
			f.store_buffer("data".to_ascii_buffer())
			f.store_32(data_len)
			f.store_buffer(pcm)
			f.close()
			print("[dbg] %s 저장 — %.1f초 / %d Hz / 피크 %.2f / RMS %.3f" % [
				path, float(cnt) / float(rate), rate, peak, sqrt(sq / maxf(1.0, float(cnt)))])
			get_tree().quit()
	if "aimtest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.6).timeout
		tutorial_step = -1
		print("[dbg] 구역=%s can_shoot=%s" % [String(city.theme["name"]), str(can_shoot())])
		var f0 := cam.fov
		var cam0 := cam.global_position
		_set_aiming(true)
		await get_tree().create_timer(1.2).timeout
		var eye := car.global_position + Vector3.UP * 2.4
		print("[dbg] 우클릭 유지 — 시야각 %.1f -> %.1f (배율 %.1fx) / 경통 %s / 크로스헤어 %s" % [
			f0, cam.fov, 70.0 / cam.fov, str(scope.visible), str(crosshair.visible)])
		print("[dbg] 카메라 차와의 거리 %.1f -> %.1f (운전석 눈높이까지 %.1f) / 차체 %s / 핸들 %s" % [
			cam0.distance_to(car.global_position), cam.global_position.distance_to(car.global_position),
			cam.global_position.distance_to(eye), str(car._pivot.visible), str(car._cockpit.visible)])
		# 마우스를 돌리면 시선이 따라가는지
		var d0 := aim_dir()
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(200, -60)
		_unhandled_input(mm)
		await get_tree().create_timer(0.4).timeout
		print("[dbg] 마우스 (200,-60) — 조준각 좌우 %.2f / 상하 %.2f rad / 시선 변화 %.1f도" % [
			aim_yaw, aim_pitch, rad_to_deg(d0.angle_to(aim_dir()))])
		# 경통 한가운데로 쏴서 실제로 맞는지
		aim_yaw = 0.0
		aim_pitch = 0.0
		# 시선을 되돌린 뒤 카메라가 실제로 그쪽을 볼 때까지 기다린다.
		# 안 기다리면 예전 각도로 거리를 재서 엉뚱한 자리에 트럭을 세운다.
		await get_tree().create_timer(0.4).timeout
		var victim: RivalCar = null
		for r in rivals:
			if is_instance_valid(r) and r.alive:
				victim = r
				break
		if victim:
			# 경쟁사 트럭은 스스로 돌아다닌다. 세워놔야 경통 한가운데에 남는다.
			victim.set_physics_process(false)
			# 정면에 건물이 있으면 총알이 거기서 막힌다. 먼저 뚫린 거리를 재고
			# 그 안쪽에 세워야 조준 정확도를 재는 시험이 된다.
			var ctr0 := get_viewport().get_visible_rect().size * 0.5
			var ro0 := cam.project_ray_origin(ctr0)
			var rn0 := cam.project_ray_normal(ctr0)
			var q0 := PhysicsRayQueryParameters3D.create(ro0, ro0 + rn0 * 400.0)
			q0.exclude = [car.get_rid()]
			var res0 := get_world_3d().direct_space_state.intersect_ray(q0)
			var clear0: float = 400.0
			if res0.size() > 0:
				clear0 = ro0.distance_to(res0["position"])
			var place: float = clampf(clear0 - 8.0, 12.0, 55.0)
			print("[dbg] 정면 뚫린 거리 %.0f — 트럭을 %.0f 앞에 세운다" % [clear0, place])
			victim.global_position = car.global_position + aim_dir() * place
			await get_tree().create_timer(0.4).timeout
			victim.global_position = car.global_position + aim_dir() * place
			await get_tree().create_timer(0.2).timeout
			var hp0: int = victim.hp
			print("[dbg] 트럭 위치 %s / 차 %s / 카메라 %s / aim_dir %s" % [
				str(victim.global_position.round()), str(car.global_position.round()),
				str(cam.global_position.round()), str(aim_dir())])
			var ctr := get_viewport().get_visible_rect().size * 0.5
			var ro := cam.project_ray_origin(ctr)
			var rn := cam.project_ray_normal(ctr)
			var sp2 := get_world_3d().direct_space_state
			var q3 := PhysicsRayQueryParameters3D.create(ro, ro + rn * 400.0)
			q3.exclude = [car.get_rid()]
			var hit3 := sp2.intersect_ray(q3)
			print("[dbg] 화면중앙 레이 origin=%s normal=%s / 맞은것=%s / 위치=%s" % [
				str(ro.round()), str(rn), 
				str(hit3.get("collider")) if hit3.size() > 0 else "없음",
				str(hit3.get("position").round()) if hit3.size() > 0 else "-"])
			var killed := false
			for i in 6:
				shoot_cooldown = 0.0
				_try_shoot(ctr)
				await get_tree().create_timer(0.35).timeout
				# 격파되면 노드가 사라진다. 그 뒤에 hp 를 읽으면 스크립트가 죽는다.
				if not is_instance_valid(victim) or not victim.alive:
					killed = true
					print("[dbg] %d발째에 트럭 격파" % (i + 1))
					break
			if killed:
				print("[dbg] 조준 사격 — 시작 체력 %d 에서 격파 (명중 확인)" % hp0)
			else:
				print("[dbg] 조준 사격 6발 — 트럭 체력 %d -> %d" % [hp0, victim.hp])
		_set_aiming(false)
		await get_tree().create_timer(1.2).timeout
		print("[dbg] 우클릭 해제 — 시야각 %.1f / 경통 %s / 크로스헤어 %s / 차체 %s" % [
			cam.fov, str(scope.visible), str(crosshair.visible), str(car._pivot.visible)])
		# 무지개 시점에서는 조준이 안 먹어야 한다 (시야각을 환각이 덮어쓴다)
		cam_mode = CamMode.TRIP
		_apply_cam_mode()
		_set_aiming(true)
		await get_tree().create_timer(0.8).timeout
		print("[dbg] 무지개 시점에서 우클릭 — 경통 %s (false 여야 정상)" % str(scope.visible))
		get_tree().quit()
	if "driftshot" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.3).timeout
		tutorial_step = -1
		car.debug_input = {"throttle": 1.0, "steer": 1.0, "jump": false, "boost": false,
			"horn": false, "drift": true}
	if "drifttest" in OS.get_cmdline_user_args():
		debug_no_save = true
		debug_events = true
		start_game()
		await get_tree().create_timer(0.4).timeout
		tutorial_step = -1
		# 1) 드리프트 없이 같은 입력으로 돌 때
		car.debug_input = {"throttle": 1.0, "steer": 1.0, "jump": false, "boost": false,
			"horn": false, "drift": false}
		await get_tree().create_timer(2.0).timeout
		print("[dbg] 드리프트 OFF — 미끄럼각 %.1f도 / 충전 %.0f" % [car.slide_angle(), car.drift_charge])
		# 2) 드리프트를 물고 같은 입력
		car.debug_input["drift"] = true
		await get_tree().create_timer(1.0).timeout
		var a1 := car.slide_angle()
		await get_tree().create_timer(1.6).timeout
		print("[dbg] 드리프트 ON — 미끄럼각 %.1f -> %.1f도 / 충전 %.0f / 단계 %d / %.1f초" % [
			a1, car.slide_angle(), car.drift_charge, car.drift_tier, car.drift_secs])
		var sp0 := car.kmh()
		var boosts0 := drift_boosts
		# 3) 손을 떼면 부스터
		car.debug_input["drift"] = false
		await get_tree().create_timer(0.2).timeout
		print("[dbg] 릴리즈 — 부스터 %.1f초 / 속도 %.0f -> %.0f km/h / 정산 %d회 / 스턴트 %s원" % [
			car.drift_boost_time, sp0, car.kmh(), drift_boosts - boosts0, _won(drift_total)])
		# 4) 충전이 모자라면 부스터가 안 나와야 한다
		car.drift_charge = 0.0
		car.debug_input["drift"] = true
		await get_tree().create_timer(0.25).timeout
		car.debug_input["drift"] = false
		await get_tree().create_timer(0.2).timeout
		print("[dbg] 짧은 드리프트 — 추가 정산 %d회 (0 이어야 정상)" % [drift_boosts - boosts0 - 1])
		# 5) 충전 속도. 드리프트가 제대로 물린 프레임(각 40도 이상, 지면)만 골라서 잰다.
		# 건물에 박히면 속도가 죽어 결과가 판마다 달라지므로 그런 프레임은 버린다.
		car.debug_input["drift"] = true
		var good_t := 0.0
		var gained := 0.0
		var watched := 0.0
		while watched < 7.0:
			await get_tree().physics_frame
			var dt := get_physics_process_delta_time()
			watched += dt
			if car.slide_angle() > 40.0 and not car.airborne and car.drift_charge < Car.DRIFT_CHARGE_MAX:
				var before_c := car.drift_charge
				await get_tree().physics_frame
				watched += dt
				gained += maxf(0.0, car.drift_charge - before_c)
				good_t += dt
			if car.drift_charge >= Car.DRIFT_CHARGE_MAX:
				car.drift_charge = 0.0
		var rate: float = gained / maxf(0.001, good_t)
		print("[dbg] 제대로 물린 %.1f초 동안 충전 속도 %.1f/초 — 1단계 %.2f초 / 2단계 %.2f초 / 3단계 %.2f초" % [
			good_t, rate,
			float(Car.DRIFT_TIERS[0]) / rate, float(Car.DRIFT_TIERS[1]) / rate,
			float(Car.DRIFT_TIERS[2]) / rate])
		car.debug_input["drift"] = false
		get_tree().quit()
	if "camtest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.4).timeout
		for i in 7:
			await get_tree().create_timer(0.35).timeout
			print("[dbg] 시점 %d=%s / 차체 %s / 운전석 %s / 무지개 %s / 카메라 %s" % [
				cam_mode, CAM_NAMES[cam_mode], str(car._pivot.visible),
				str(car._cockpit.visible), str(trip_rect.visible),
				str(cam.global_position.round())])
			cycle_camera()
		# 계기 바늘이 실제로 움직이는지
		cam_mode = CamMode.FIRST
		_apply_cam_mode()
		car.boost_fuel = 100.0
		await get_tree().create_timer(0.4).timeout
		var a0: float = car._needle_speed.rotation.z
		var f0: float = car._needle_fuel.rotation.z
		car.speed = car.max_speed
		car.boost_fuel = 20.0
		await get_tree().create_timer(0.4).timeout
		print("[dbg] 속도바늘 %.2f -> %.2f (%.0f km/h) / 연료바늘 %.2f -> %.2f (부스터 20%%)" % [
			a0, car._needle_speed.rotation.z, car.kmh(), f0, car._needle_fuel.rotation.z])
		get_tree().quit()
	if "atsign" in OS.get_cmdline_user_args():
		# 전광판 정면에 카메라를 직접 놓는다. 추격 카메라로는 각도를 못 맞춘다.
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.3).timeout
		print("[dbg] 전광판 %d개 / 채널 %d개" % [city.billboards.size(), City.SCREEN_CHANNELS])
		if not city.billboards.is_empty():
			var idx := 0
			for a2 in OS.get_cmdline_user_args():
				if a2.begins_with("sign="):
					idx = int(a2.substr(5))
			var b: MeshInstance3D = city.billboards[idx % city.billboards.size()]
			var face := Vector3(0, 0, 1).rotated(Vector3.UP, b.rotation.y)
			var wide: float = (b.mesh as QuadMesh).size.x
			print("[dbg] %d번 전광판 — 높이 %.1f / 폭 %.1f / 위치 %s" % [
				idx, b.global_position.y, wide, str(b.global_position.round())])
			# 전광판 정면이 실제로 뚫려 있는지(= 길을 보고 있는지) 레이로 재고,
			# 그 여유 거리 안에 카메라를 놓는다.
			var space := get_world_3d().direct_space_state
			var want: float = wide * 1.5 + 6.0
			var q := PhysicsRayQueryParameters3D.create(
				b.global_position + face * 0.5, b.global_position + face * want)
			var hit := space.intersect_ray(q)
			var clear: float = want
			if not hit.is_empty():
				clear = maxf(4.0, b.global_position.distance_to(hit["position"]) - 1.5)
			print("[dbg] 정면 여유 %.1f / 원하는 거리 %.1f" % [clear, want])
			# 전체 전광판 중 몇 개가 길을 보고 있는지
			var open_cnt := 0
			for bb in city.billboards:
				var f2 := Vector3(0, 0, 1).rotated(Vector3.UP, bb.rotation.y)
				var q2 := PhysicsRayQueryParameters3D.create(
					bb.global_position + f2 * 0.5, bb.global_position + f2 * 16.0)
				if space.intersect_ray(q2).is_empty():
					open_cnt += 1
			print("[dbg] 정면 16m 가 뚫린 전광판 %d / %d" % [open_cnt, city.billboards.size()])
			debug_freecam = true
			cam.global_position = b.global_position + face * clear
			cam.look_at(b.global_position, Vector3.UP)
			cam.fov = 62.0
	if "atpickup" in OS.get_cmdline_user_args():
		# 보급 상자를 화면에 담기 위해 픽업 지점 앞에 차를 세워둔다.
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.3).timeout
		var back := Vector3(26.0, 0, 34.0)
		car.reset_to(target_pos + back + Vector3(0, 0.6, 0))
		car.look_at(target_pos, Vector3.UP)
	if "botplay" in OS.get_cmdline_user_args():
		start_game()
		botplay = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("botspeed="):
				bot_speed = float(a.substr(9))
	if "demo" in OS.get_cmdline_user_args():
		start_game()
		car.auto_drive = true
	if "achtest" in OS.get_cmdline_user_args():
		debug_no_save = true
		achieved.clear()
		start_game()
		_unlock("gta")
	if "clicktest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		score = 180000.0
		open_menu()
		menu.tab = 2
		menu.refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var slot := menu._body.get_child(2) as Control
		var pos: Vector2 = slot.global_position + slot.size * 0.5
		print("[dbg] 클릭 대상=%s 위치=%s filter=%d" % [slot.get_child(0).text, str(pos), slot.mouse_filter])
		for pressed in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.position = pos
			ev.global_position = pos
			Input.parse_input_event(ev)
			await get_tree().process_frame
		await get_tree().process_frame
		print("[dbg] 클릭 후 levels=%s  잔액=%s" % [str(upgrade_levels), _won(score)])
	if "resettest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		achieved = {"first": true, "gta": true}
		best_score = 777000.0
		open_menu()
		menu.tab = 4
		menu.row = 1
		menu.refresh()
		await get_tree().process_frame
		print("[dbg] 시작: 도전과제=%d 최고기록=%s" % [achieved.size(), _won(best_score)])
		menu.handle_key(KEY_SPACE)
		await get_tree().process_frame
		print("[dbg] 1회 누름: confirm_idx=%d 도전과제=%d (아직 안 지워져야 함)" % [menu.confirm_idx, achieved.size()])
		menu.handle_key(KEY_SPACE)
		await get_tree().process_frame
		print("[dbg] 2회 누름: 도전과제=%d 최고기록=%s" % [achieved.size(), _won(best_score)])
	if "shakecheck" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		for mode in [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_FULLSCREEN]:
			DisplayServer.window_set_mode(mode)
			await get_tree().process_frame
			shake = 0.0
			_shake(0.25)
			var minor := shake
			shake = 0.0
			_shake(1.2, true)
			var major := shake
			print("[dbg] %s — 작은충돌 %.2f / 큰충돌 %.2f" % [
				"창모드" if mode == DisplayServer.WINDOW_MODE_WINDOWED else "전체화면", minor, major])
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if "colcheck" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().physics_frame
		await get_tree().physics_frame
		var space := get_world_3d().direct_space_state
		var q := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 1.2
		q.shape = sph
		var hit := 0
		for isl in city.islands:
			q.transform = Transform3D(Basis(), isl + Vector3(0, 3.5, 0))
			if space.intersect_shape(q, 1).size() > 0:
				hit += 1
		print("[dbg] 교통섬 기념물 충돌체: %d / %d" % [hit, city.islands.size()])
		# 가로등/나무: 인도 위 물체가 실제로 막히는지 샘플
		var lamp_hits := 0
		var samples := 0
		for body in get_tree().get_nodes_in_group("_none"):
			pass
		var total_static := 0
		for ch in city.get_children():
			if ch is StaticBody3D:
				total_static += 1
		print("[dbg] 도시 StaticBody3D 총 %d개" % total_static)
	if "fireshot" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.7).timeout
		var ring2 := 0
		for r in rivals:
			if not is_instance_valid(r):
				continue
			var a2: float = TAU * float(ring2) / float(maxi(rivals.size(), 1)) + 0.4
			r.global_position = car.global_position + Vector3(cos(a2), 0, sin(a2)) * 26.0
			r.look_at(car.global_position, Vector3.UP)
			r.set_physics_process(false)
			r.gun_cooldown = 0.05
			ring2 += 1
	if "resultshot" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.5).timeout
		# 통계를 그럴듯하게 채워서 가장 긴 줄로 확인한다
		score = 1234567.0
		best_score = 2345678.0
		deliveries = 23
		cold_deliveries = 4
		elapsed = 494.0
		top_speed = 318.0
		special_done = 4
		crashes = 17
		bumps = 63
		cows_hit = 12
		best_leg = 8.4
		tips_total = 184320.0
		stunt_total = 47600.0
		crash_total = 8000.0
		things_flattened = 41
		times_shot = 29
		times_punched = 18
		punches_landed = 26
		deaths = 3
		_quit_shift()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cutshot="):
			debug_no_save = true
			start_game()
			await get_tree().create_timer(0.4).timeout
			for k in City.THEMES.size():
				seen_unlock_cutscene[k] = true
			_queue_unlock_cutscene(int(a.substr(8)))
	if "replaytest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.6).timeout
		open_menu()
		menu.tab = 5
		menu.row = 4
		menu.refresh()
		await get_tree().process_frame
		print("[dbg] 설정 항목 %d개 / 선택 %d" % [menu._row_count(), menu.row])
		menu.handle_key(KEY_SPACE)
		await get_tree().process_frame
		print("[dbg] 1번째 — 표시=%s 제목=%s / 대기열 %d" % [
			str(cut_root.visible), cut_name.text, pending_cutscenes.size()])
		close_unlock_cutscene()
		await get_tree().process_frame
		print("[dbg] 2번째 — 표시=%s 제목=%s" % [str(cut_root.visible), cut_name.text])
		get_tree().quit()
	if "sliptest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.6).timeout
		for g in [1.0, 0.16]:
			car.reset_to(city.random_point())
			car.mod_grip = float(g)
			car.mod_turn = 1.0 if g >= 1.0 else 0.95
			await get_tree().physics_frame
			var peak := 0.0
			# 최고속으로 달리다가 핸들을 꺾는다
			for i in 120:
				car.speed = 40.0
				if i > 40:
					car.rotate_y(2.2 * 0.95 * (1.0 / 60.0))
				await get_tree().physics_frame
				if i > 40:
					peak = maxf(peak, car.slide_angle())
			print("[dbg] 접지 %.2f — 조향 중 최대 미끄러짐 각도 %.1f도" % [g, peak])
		get_tree().quit()
	if "fovtest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.6).timeout
		car.speed = 40.0
		car.boosting = false
		for i in 60:
			car.speed = 40.0
			await get_tree().process_frame
		var normal_fov := cam.fov
		for i in 60:
			car.speed = 40.0
			car.boosting = true
			await get_tree().process_frame
		var boost_fov := cam.fov
		print("[dbg] 같은 속도 40 — 평상시 FOV %.1f / 부스터 FOV %.1f (+%.1f)" % [
			normal_fov, boost_fov, boost_fov - normal_fov])
		get_tree().quit()
	if "roadwidth" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().physics_frame
		await get_tree().physics_frame
		var space := get_world_3d().direct_space_state
		var sums := {"일반": [0.0, 0], "대로": [0.0, 0]}
		for i in range(1, City.GRID):
			for j in range(1, City.GRID):
				var p := Vector3(city._origin + i * City.CELL, 1.0, city._origin + j * City.CELL)
				# 교차로 사이 중간 지점에서 좌우로 쏜다
				var mid := p + Vector3(0, 0, City.CELL * 0.5)
				for axis in [Vector3.RIGHT, Vector3.LEFT]:
					var q := PhysicsRayQueryParameters3D.create(mid, mid + axis * 60.0)
					q.exclude = [car.get_rid()]
					var r := space.intersect_ray(q)
					var d: float = 60.0
					if r.size() > 0:
						d = mid.distance_to(r.get("position"))
					var key: String = "대로" if city.road_width(i) > City.ROAD * 1.5 else "일반"
					sums[key][0] += d
					sums[key][1] += 1
		for k in sums.keys():
			if int(sums[k][1]) > 0:
				var avg: float = float(sums[k][0]) / float(sums[k][1])
				print("[dbg] %s 도로 — 중앙에서 한쪽 평균 %.1f / 전체 폭 %.1f (차폭 2.4 기준 %.1f대분)" % [
					k, avg, avg * 2.0, avg * 2.0 / 2.4])
		print("[dbg] 설정값: ROAD=%.0f 대로=%.0f BLOCK=%.0f CELL=%.0f" % [
			City.ROAD, city.road_width(3), City.BLOCK, City.CELL])
		get_tree().quit()
	if "unlocktest" in OS.get_cmdline_user_args():
		debug_no_save = true
		# 아무것도 해금 안 된 상태에서 시작
		career_earnings = 0.0
		seen_unlock_cutscene = {}
		selected_district = 0
		start_game()
		await get_tree().create_timer(0.6).timeout
		print("[dbg] 시작 — 소지금 %s / 업그레이드 %d종" % [_won(score), upgrade_levels.size()])
		# 배달 벌이로 배그 해금선을 넘긴다
		score = 400000.0
		career_earnings = 400000.0
		_check_district_unlocks()
		await get_tree().process_frame
		print("[dbg] 40만원 달성 — 연출 표시=%s / 제목=%s" % [
			str(cut_root.visible), cut_name.text])
		close_unlock_cutscene()
		await get_tree().process_frame
		print("[dbg] 닫은 뒤 대기열 %d개 / 표시=%s / 제목=%s" % [
			pending_cutscenes.size(), str(cut_root.visible), cut_name.text])
		close_unlock_cutscene()
		await get_tree().process_frame
		# 구역 이동 시 돈이 유지되는가
		upgrade_levels["engine"] = 2
		var before := score
		select_district(City.PUBG_DISTRICT_INDEX)
		await get_tree().process_frame
		print("[dbg] 구역 이동 — 소지금 %s → %s / 엔진 Lv.%d (유지되어야 정상)" % [
			_won(before), _won(score), int(upgrade_levels.get("engine", 0))])
		get_tree().quit()
	if "moneytest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.8).timeout
		open_menu()
		menu.tab = 5
		menu.row = 3
		menu.refresh()
		await get_tree().process_frame
		await get_tree().process_frame
		print("[dbg] 설정 탭 항목 수=%d / 선택 %d / 실행 전 소지금 %s" % [
			menu._row_count(), menu.row, _won(score)])
		menu.handle_key(KEY_SPACE)
		await get_tree().process_frame
		print("[dbg] 한 번 눌렀을 때 — 소지금 %s / confirm_idx=%d (확인 없이 바로 되어야 함)" % [
			_won(score), menu.confirm_idx])
		var unlocked := 0
		for i in City.THEMES.size():
			if is_district_unlocked(i):
				unlocked += 1
		print("[dbg] 해금된 구역 %d / %d" % [unlocked, City.THEMES.size()])
		get_tree().quit()
	if "quittest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.8).timeout
		open_menu()
		await get_tree().process_frame
		print("[dbg] 메뉴 연 직후 — state=%d menu.visible=%s" % [state, str(menu.visible)])
		menu.handle_key(KEY_Q)
		await get_tree().process_frame
		await get_tree().process_frame
		print("[dbg] Q(퇴근) 후 — state=%d (RESULT=%d) menu.visible=%s result.visible=%s hud.visible=%s" % [
			state, State.RESULT, str(menu.visible), str(result_root.visible), str(hud_root.visible)])
		get_tree().quit()
	if "armortest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.8).timeout
		score = 900000.0
		var idx := -1
		for i in UPGRADES.size():
			if String(UPGRADES[i]["key"]) == "armor":
				idx = i
		print("[dbg] 기본 최대체력 %.0f / 현재 %.0f" % [max_hp(), player_hp])
		player_hp = 60.0
		for lvl in 3:
			buy_upgrade(idx)
			await get_tree().process_frame
			print("[dbg] 방탄 강판 Lv.%d — 최대 %.0f / 현재 %.0f / 총알 %d발 버팀 / 잔액 %s" % [
				int(upgrade_levels.get("armor", 0)), max_hp(), player_hp,
				int(ceilf(max_hp() / GUN_DAMAGE)), _won(score)])
		print("[dbg] 철판 장착=%s" % str(car._pivot.get_node_or_null("Armor") != null))
		# 최대치 넘어서 회복 안 되는지
		player_hp = max_hp() + 50.0
		for i in 30:
			await get_tree().physics_frame
		print("[dbg] 과충전 후 %.0f (최대 %.0f 이하여야 정상은 아님 — 회복만 막으면 됨)" % [player_hp, max_hp()])
		get_tree().quit()
	if "punchtest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(1.0).timeout
		print("[dbg] 구역=%s / 주먹 가능=%s / 팔 장착=%s" % [
			String(city.theme["name"]), str(can_punch()),
			str(car._pivot.get_node_or_null("Fists") != null)])
		var r: RivalCar = null
		for x in rivals:
			if is_instance_valid(x) and x.alive:
				r = x
				break
		if r == null:
			print("[dbg] 적 없음")
			get_tree().quit()
		# 앞쪽에 붙여놓고 때린다
		var fwd := -car.global_transform.basis.z
		r.set_physics_process(false)
		r.global_position = car.global_position + fwd * 5.0
		await get_tree().physics_frame
		var hp0 := r.hp
		var landed0 := punches_landed
		for i in 4:
			punch_cooldown = 0.0
			_try_punch()
			await get_tree().physics_frame
		print("[dbg] 앞쪽 4번 — 적 hp %d → %s / 명중 %d대" % [
			hp0, str(r.hp) if is_instance_valid(r) and r.alive else "격파", punches_landed - landed0])
		# 뒤쪽은 안 맞아야 한다
		var r2: RivalCar = null
		for x in rivals:
			if is_instance_valid(x) and x.alive:
				r2 = x
				break
		if r2 != null:
			r2.set_physics_process(false)
			r2.global_position = car.global_position - fwd * 5.0
			await get_tree().physics_frame
			var hp1 := r2.hp
			var l1 := punches_landed
			for i in 3:
				punch_cooldown = 0.0
				_try_punch()
				await get_tree().physics_frame
			print("[dbg] 뒤쪽 3번 — 적 hp %d → %d / 명중 %d대 (0이어야 정상)" % [
				hp1, r2.hp, punches_landed - l1])
		get_tree().quit()
	if "powertest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(1.0).timeout
		print("[dbg] 내 체력 %.0f / 총알 -%.0f (%d발 버팀) / 주먹 -%.0f (%d대 버팀)" % [
			max_hp(), GUN_DAMAGE, int(ceilf(max_hp() / GUN_DAMAGE)),
			PUNCH_DAMAGE, int(ceilf(max_hp() / PUNCH_DAMAGE))])
		var r: RivalCar = null
		for x in rivals:
			if is_instance_valid(x) and x.alive:
				r = x
				break
		if r != null:
			print("[dbg] 트럭 체력 %d / 박치기 저속2·고속3 → 고속 %d번이면 KO / 총알 1발씩 → %d발" % [
				r.hp, int(ceilf(float(r.hp) / 3.0)), r.hp])
		# 고깔콘 대사 안 나오는지
		var cones := 0
		for c in city.cows:
			if c.get_child_count() <= 2:
				cones += 1
		print("[dbg] 고깔콘 %d개 / 소 %d마리 — 콘 전용 대사 호출 제거됨" % [cones, city.cows.size() - cones])
		get_tree().quit()
	if "hptest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(1.0).timeout
		print("[dbg] 구역=%s  체력시스템=%s  시작체력=%.0f" % [
			String(city.theme["name"]), str(hp_active()), player_hp])
		score = 500000.0
		# 1) 피격 누적으로 대파되는지
		var d0 := deaths
		for i in 12:
			player_hit_cooldown = 0.0
			_hurt(GUN_DAMAGE, "총")
			await get_tree().process_frame
		print("[dbg] 총 12발(11씩) — 체력 %.0f / 대파 %d회 / 잔액 %s원 (50만의 7%% = 35,000)" % [
			player_hp, deaths - d0, _won(score)])
		# 2) 자기장 밖에서 체력 닳는지
		if bluezone_active:
			player_hp = max_hp()
			car.global_position = bluezone_center + Vector3(bluezone_radius + 60.0, 0, 0)
			var hp0 := player_hp
			var t_before := time_left
			for i in 120:
				car.global_position = bluezone_center + Vector3(bluezone_radius + 60.0, 0, 0)
				await get_tree().physics_frame
			print("[dbg] 자기장 밖 2초 — 체력 %.0f → %.0f / 제한시간 %.1f → %.1f (정상 감소 약 2.0초)" % [
				hp0, player_hp, t_before, time_left])
			# 3) 안전구역 회복
			player_hp = 30.0
			var hp1 := player_hp
			for i in 180:
				car.global_position = bluezone_center
				await get_tree().physics_frame
			print("[dbg] 안전구역 3초 — 체력 %.0f → %.0f" % [hp1, player_hp])
		get_tree().quit()
	if "zonetest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.5).timeout
		print("[dbg] 구역=%s bluezone_active=%s" % [String(city.theme["name"]), str(bluezone_active)])
		var c0 := bluezone_center
		var moved := 0.0
		var far_targets := 0
		var checked := 0
		var seen_targets := {}
		# 120초를 빨리감기하면서 중심이 실제로 옮겨가는지, 목적지가 원 안에 있는지 본다
		Engine.time_scale = 8.0
		for i in 240:
			await get_tree().create_timer(0.5).timeout
			# 목표 금액을 채우면 판이 끝나버려서 자기장이 멈춘다. 잔액을 계속 비운다.
			score = 0.0
			checked += 1
			var d_now: float = Vector2(target_pos.x, target_pos.z).distance_to(
				Vector2(bluezone_center.x, bluezone_center.z))
			if d_now > bluezone_radius:
				far_targets += 1
			moved = maxf(moved, Vector2(bluezone_center.x, bluezone_center.z).distance_to(Vector2(c0.x, c0.z)))
			seen_targets[Vector2i(int(target_pos.x), int(target_pos.z))] = true
			# 배달이 진행돼야 목적지가 갱신된다. 차를 목적지로 순간이동시킨다.
			car.global_position = Vector3(target_pos.x, car.global_position.y, target_pos.z)
		Engine.time_scale = 1.0
		print("[dbg] 자기장 단계 %d / 중심 이동 최대 %.1f (0이면 가운데로만 줄어든 것) / 반경 %.1f" % [
			zone_phase, moved, bluezone_radius])
		print("[dbg] 목적지 원 밖으로 잡힌 횟수 %d / %d 샘플 / 서로 다른 목적지 %d곳" % [
			far_targets, checked, seen_targets.size()])
		print("[dbg] 보급 획득 %d개 / 체력 %.0f / 잔액 %s원" % [supplies_taken, player_hp, _won(score)])
		get_tree().quit()
	if "machotest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(1.0).timeout
		print("[dbg] macho_active=%s / 트럭 %d대" % [str(macho_active), rivals.size()])
		var tgt_ok := 0
		for r in rivals:
			if is_instance_valid(r) and r.target_is_player:
				tgt_ok += 1
		print("[dbg] 플레이어를 노리는 트럭 %d / %d" % [tgt_ok, rivals.size()])
		# 트럭들을 옆에 붙여놓고 얻어맞아 본다
		var ring := 0
		for r in rivals:
			if not is_instance_valid(r):
				continue
			var a: float = TAU * float(ring) / float(maxi(rivals.size(), 1))
			r.global_position = car.global_position + Vector3(cos(a), 0, sin(a)) * 7.0
			ring += 1
		var t0 := times_punched
		var time0 := time_left
		for i in 420:
			car.speed = 0.0
			await get_tree().physics_frame
		print("[dbg] 7초간 가만히 — 주먹 %d대 / 시간 %.1f → %.1f" % [
			times_punched - t0, time0, time_left])
		# 이제 박아서 잡아본다
		var victim: RivalCar = null
		for r in rivals:
			if is_instance_valid(r) and r.alive:
				victim = r
				break
		var hp0 := victim.hp
		var kills0 := rival_kills
		for i in 300:
			if not is_instance_valid(victim) or not victim.alive:
				break
			car.global_position = victim.global_position + Vector3(4.0, 0, 0)
			car.speed = 34.0
			await get_tree().physics_frame
		print("[dbg] 박치기 — hp %d → %s / 격추 %d건 증가" % [
			hp0, str(victim.hp) if is_instance_valid(victim) else "격파", rival_kills - kills0])
		get_tree().quit()
	if "enemyfire" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(1.0).timeout
		# 적들을 플레이어 주변에 배치하고 시야를 열어준다
		var ring := 0
		for r in rivals:
			if not is_instance_valid(r):
				continue
			var a: float = TAU * float(ring) / float(maxi(rivals.size(), 1))
			r.global_position = car.global_position + Vector3(cos(a), 0, sin(a)) * 32.0
			r.set_physics_process(false)
			ring += 1
		var t0 := times_shot
		var before_time := time_left
		var fired := 0
		for i in 600:
			await get_tree().physics_frame
			fired = 0
			for ch in get_children():
				if ch is Bullet and (ch as Bullet).hostile:
					fired += 1
		await get_tree().create_timer(1.0).timeout
		print("[dbg] 10초간 — 피격 %d회 / 시간 %.1f → %.1f" % [
			times_shot - t0, before_time, time_left])
		print("[dbg] 트럭 %d대, 사격 거리 32유닛 (다 맞으면 40회 이상이어야 함)" % rivals.size())
		get_tree().quit()
	if "linetest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		for pair in [["지각", late_lines], ["식음", cold_lines], ["대형사고", crash_lines]]:
			var pool: Array = pair[1]
			var seen := {}
			var seq: Array = []
			var dup_adjacent := 0
			for i in pool.size() * 2:
				var ln := _line(pool)
				if seq.size() > 0 and ln == seq[seq.size() - 1]:
					dup_adjacent += 1
				seq.append(ln)
				seen[ln] = int(seen.get(ln, 0)) + 1
			var first_cycle := {}
			for i in pool.size():
				first_cycle[seq[i]] = true
			print("[dbg] %s — 풀 %d개 / 2바퀴 %d회 뽑기 / 서로 다른 대사 %d개 / 첫 바퀴 고유 %d개 / 연속중복 %d회" % [
				String(pair[0]), pool.size(), seq.size(), seen.size(), first_cycle.size(), dup_adjacent])
		print("[dbg] 지각 대사 예시: %s / %s / %s" % [_line(late_lines), _line(late_lines), _line(late_lines)])
		get_tree().quit()
	if "flattest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.8).timeout
		# 평지 직진: y 가 출렁이면 껄떡거리는 것이다
		car.reset_to(city.random_point())
		await get_tree().physics_frame
		car.steps_taken = 0
		var ys: Array = []
		for i in 150:
			car.speed = 22.0
			await get_tree().physics_frame
			ys.append(car.global_position.y)
		var mn := 999.0
		var mx := -999.0
		for y in ys:
			mn = minf(mn, float(y))
			mx = maxf(mx, float(y))
		print("[dbg] 150프레임 직진 — y %.2f~%.2f / 올라타기 발동 %d회 (1~2회면 인도 진입, 수십회면 껄떡거림)" % [
			mn, mx, car.steps_taken])
	if "steptest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		car.step_enabled = not ("nostep" in OS.get_cmdline_user_args())
		await get_tree().create_timer(0.8).timeout
		for spd in [3.0, 6.0, 12.0, 24.0, 40.0]:
			var origin := city.random_point()
			car.reset_to(origin)
			var target := origin + Vector3(City.CELL * 0.5, 0, City.CELL * 0.5)
			car.look_at(car.global_position + (target - origin).normalized(), Vector3.UP)
			# 스폰 높이(2.0)가 섞이지 않게 먼저 가라앉힌다
			for i in 40:
				car.speed = 0.0
				await get_tree().physics_frame
			var ground_y := car.global_position.y
			car.steps_taken = 0
			var top_y := ground_y
			# 저속은 턱까지 가는 데 시간이 더 걸린다. 이동 거리 기준으로 맞춘다.
			var frames: int = clampi(int(2400.0 / float(spd)), 200, 1400)
			for i in frames:
				car.speed = float(spd)
				await get_tree().physics_frame
				top_y = maxf(top_y, car.global_position.y)
			print("[dbg] 속도 %.0f — 지면 y=%.2f → 최고 y=%.2f (상승 %.2f) / 올라타기 %d회 / %s" % [
				spd, ground_y, top_y, top_y - ground_y, car.steps_taken,
				"인도 올라탐" if top_y - ground_y > 0.7 else "못 올라감"])
		get_tree().quit()
	if "breakshot" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(0.6).timeout
		var near: Array[Node3D] = []
		for b in city.breakables:
			if b.global_position.distance_to(car.global_position) < 60.0:
				near.append(b)
		for b in near:
			if not b.has_meta("fallen"):
				_topple(b, b.get_child(b.get_child_count() - 1))
		print("[dbg] %d개 쓰러뜨림" % near.size())
	if "breaktest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(1.0).timeout
		print("[dbg] 차 mask=%d / breakable layer=%d → %s" % [
			car.collision_mask, City.BREAKABLE_LAYER,
			"물리적으로 못 막음" if (car.collision_mask & City.BREAKABLE_LAYER) == 0 else "막힘(문제)"])
		var ok := 0
		var tested := 0
		for n in 5:
			var target: Node3D = null
			for b in city.breakables:
				if not b.has_meta("fallen"):
					target = b
					break
			if target == null:
				break
			target.global_position = car.global_position + Vector3(0, -0.9, 0)
			tested += 1
			var sp_before := car.speed
			car.speed = 30.0
			await get_tree().physics_frame
			await get_tree().process_frame
			await get_tree().create_timer(0.5).timeout
			var tilt := rad_to_deg(maxf(absf(target.rotation.x), absf(target.rotation.z)))
			if target.has_meta("fallen") and tilt > 70.0:
				ok += 1
		print("[dbg] 접촉 %d개 중 쓰러짐 %d개 (기울기 70도 이상)" % [tested, ok])
		print("[dbg] 누적 쓰러뜨린 수 = %d" % things_flattened)
		get_tree().quit()
	if "shoottest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(1.0).timeout
		var space := get_world_3d().direct_space_state
		var rv: RivalCar = null
		for r in rivals:
			if is_instance_valid(r) and r.alive:
				rv = r
				break
		rv.set_physics_process(false)
		var lo := 0
		var hi := 0
		var n_lo := 0
		var n_hi := 0
		for dist in [20.0, 35.0, 50.0, 70.0, 90.0, 120.0]:
			var placed := false
			for ang in [0.0, 0.3, 0.6, 0.9, 1.2, 1.5, 1.8, 2.1, 2.4, 2.7, 3.0, 3.3, 3.6, 3.9, 4.2, 4.5, 4.8, 5.1, 5.4, 5.7, 6.0]:
				var dir2 := Vector3(cos(float(ang)), 0, sin(float(ang)))
				var spot: Vector3 = car.global_position + dir2 * float(dist)
				var ok := true
				for hy in [1.0, 2.6]:
					var q := PhysicsRayQueryParameters3D.create(
						car.get_muzzle_pos(), spot + Vector3(0, float(hy), 0))
					q.exclude = [car.get_rid()]
					var rr := space.intersect_ray(q)
					if rr.size() > 0 and not (rr.get("collider") is RivalCar):
						ok = false
					var cq := PhysicsRayQueryParameters3D.create(
						cam.global_position, spot + Vector3(0, float(hy), 0))
					cq.exclude = [car.get_rid()]
					var cc := space.intersect_ray(cq)
					if cc.size() > 0 and not (cc.get("collider") is RivalCar):
						ok = false
				if ok:
					rv.global_position = spot
					placed = true
					break
			if not placed:
				print("[dbg] 거리 %.0f — 사방이 막혀 테스트 불가" % dist)
				continue
			await get_tree().process_frame
			await get_tree().process_frame
			for aim_y in [1.0, 2.6]:
				var aim_pt := rv.global_position + Vector3(0, float(aim_y), 0)
				rv.hp = 99
				shoot_cooldown = 0.0
				_try_shoot(cam.unproject_position(aim_pt))
				await get_tree().create_timer(0.6).timeout
				var ok2 := rv.hp < 99
				if aim_y < 2.0:
					n_lo += 1
					if ok2: lo += 1
				else:
					n_hi += 1
					if ok2: hi += 1
			print("[dbg] 거리 %.0f 완료" % dist)
		print("[dbg] 아래쪽(y=1.0) %d/%d   위쪽(y=2.6) %d/%d" % [lo, n_lo, hi, n_hi])
		get_tree().quit()
	if "droptest" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(1.2).timeout
		var tgt: RivalCar = null
		for r in rivals:
			if is_instance_valid(r) and r.alive:
				tgt = r
				break
		var kill_pos: Vector3 = tgt.global_position
		tgt.hp = 1
		tgt.take_damage(1)
		await get_tree().process_frame
		var drop: MoneyDrop = money_drops[money_drops.size() - 1]
		print("[dbg] 격추 위치=%s / 돈다발 위치=%s / 오차=%.2f" % [
			str(kill_pos.round()), str(drop.global_position.round()),
			kill_pos.distance_to(drop.global_position)])
		# 줍기 경로도 태워본다
		var before := score
		car.global_position = drop.global_position
		await get_tree().create_timer(0.6).timeout
		print("[dbg] 수거 후 수익 증가 = %s원" % _won(score - before))
		get_tree().quit()
	if "rivalcheck" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(1.5).timeout
		print("[dbg] 초기 적 차량 = %d대" % rivals.size())
		# 3대를 강제 격추하고 수가 유지되는지 본다
		for n in 3:
			var target: RivalCar = null
			for r in rivals:
				if is_instance_valid(r) and r.alive:
					target = r
					break
			if target == null:
				print("[dbg] 격추할 대상이 없음")
				break
			target.hp = 1
			target.take_damage(1)
			await get_tree().create_timer(0.9).timeout
			var live := 0
			for r in rivals:
				if is_instance_valid(r) and r.alive:
					live += 1
			print("[dbg] %d대 격추 후 — 배열 %d대 / 살아있는 %d대 / 누적 격추 %d" % [
				n + 1, rivals.size(), live, rival_kills])
		print("[dbg] macho_active=%s  can_shoot=%s" % [str(macho_active), str(can_shoot())])
		# 30대 연속 격추 — 배열이 무한정 커지지 않는지(누수) 본다
		for n in 30:
			for r in rivals:
				if is_instance_valid(r) and r.alive:
					r.hp = 1
					r.take_damage(1)
					break
			await get_tree().create_timer(0.08).timeout
		await get_tree().create_timer(1.0).timeout
		var live2 := 0
		for r in rivals:
			if is_instance_valid(r) and r.alive:
				live2 += 1
		print("[dbg] 30대 추가 격추 후 — 배열 %d대 / 살아있는 %d대 / 누적 격추 %d" % [
			rivals.size(), live2, rival_kills])
		print("[dbg] 전체 노드 %d  vs  대기중인 queue_free 정리 확인" % get_tree().get_node_count())
		get_tree().quit()
	if "bluecheck" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(3.0).timeout
		print("[dbg] bluezone_active=%s visible=%s radius=%.1f center=%s" % [
			str(bluezone_active), str(bluezone_mesh.visible), bluezone_radius, str(bluezone_center)])
		print("[dbg] mesh scale=%s pos=%s aabb=%s" % [
			str(bluezone_mesh.scale), str(bluezone_mesh.position),
			str(bluezone_mesh.get_aabb())])
		var box := bluezone_mesh.get_aabb()
		print("[dbg] world y range = %.2f ~ %.2f  (바닥 0 보다 위여야 함)" % [
			bluezone_mesh.position.y + box.position.y * bluezone_mesh.scale.y,
			bluezone_mesh.position.y + (box.position.y + box.size.y) * bluezone_mesh.scale.y])
		print("[dbg] visible_on_screen=%s" % str(bluezone_mesh.is_visible_in_tree()))
		print("[dbg] can_shoot=%s  rivals=%d대  crosshair_visible=%s" % [
			str(can_shoot()), rivals.size(), str(crosshair.visible)])
		get_tree().quit()
	if "mmcheck" in OS.get_cmdline_user_args():
		# 레이더(미니맵)에 찍힌 트럭 마커가 계산 위치와 맞는지 픽셀 단위로 검사한다.
		debug_no_save = true
		start_game()
		await get_tree().create_timer(4.0).timeout
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var vr: Vector2 = get_viewport().get_visible_rect().size
		var k := Vector2(float(img.get_width()) / vr.x, float(img.get_height()) / vr.y)
		var span: float = City.GRID * City.CELL + City.ROAD * 2.0
		var s: float = minf(minimap.size.x, minimap.size.y) / span
		var mmc: Vector2 = minimap.size * 0.5
		print("[mm] virtual=%s image=%s scale=%s" % [str(vr), str(img.get_size()), str(k)])
		print("[mm] minimap pos=%s size=%s  s=%.4f center=%s" % [
			str(minimap.global_position), str(minimap.size), s, str(mmc)])

		var expect := func(v: Vector3) -> Vector2:
			return (minimap.global_position + mmc + Vector2(v.x, v.z) * s) * k
		var back := func(p: Vector2) -> Vector2:
			return (p / k - minimap.global_position - mmc) / s

		print("[mm] player w=%s expect=%s" % [str(car.global_position), str(expect.call(car.global_position))])
		print("[mm] target w=%s expect=%s" % [str(target_pos), str(expect.call(target_pos))])
		for r in rivals:
			if is_instance_valid(r):
				print("[mm] rival  w=%s expect=%s" % [str(r.global_position), str(expect.call(r.global_position))])
				var pv: Node3D = r.get_node_or_null("Node3D")
				if pv != null:
					print("[mm]   mesh pivot=%s  논리좌표와 차이=%s" % [
						str(pv.global_position), str(pv.global_position - r.global_position)])

		# 미니맵 영역에서 붉은 마커 픽셀을 찾아 클러스터링
		var o: Vector2 = minimap.global_position * k
		var e: Vector2 = (minimap.global_position + minimap.size) * k
		var cents: Array[Vector2] = []
		var counts: Array[int] = []
		var total := 0
		for y in range(int(o.y), int(e.y)):
			for x in range(int(o.x), int(e.x)):
				var px := img.get_pixel(x, y)
				if px.r > 0.75 and px.g < 0.40 and px.b < 0.45:
					total += 1
					var hp := Vector2(x, y)
					var merged := false
					for i in cents.size():
						if cents[i].distance_to(hp) < 10.0:
							cents[i] = (cents[i] * float(counts[i]) + hp) / float(counts[i] + 1)
							counts[i] += 1
							merged = true
							break
					if not merged:
						cents.append(hp)
						counts.append(1)
		print("[mm] 붉은 픽셀 %d개 / 클러스터 %d개" % [total, cents.size()])
		for i in cents.size():
			var w: Vector2 = back.call(cents[i])
			print("[mm]   blob screen=%s n=%d  world≈(%.0f, %.0f)" % [
				str(cents[i]), counts[i], w.x, w.y])
		print("[mm] mouse=%s crosshair=%s" % [
			str(get_viewport().get_mouse_position()), str(crosshair.visible)])

		# 미니맵 영역만 4배 확대 저장 (마커가 도로 위에 있는지 눈으로 확인용)
		var reg := Rect2i(int(o.x), int(o.y), int(e.x - o.x), int(e.y - o.y))
		var crop := img.get_region(reg)
		crop.resize(crop.get_width() * 4, crop.get_height() * 4, Image.INTERPOLATE_NEAREST)
		crop.save_png("/tmp/mm_zoom.png")
		print("[mm] 확대 저장: /tmp/mm_zoom.png (%s)" % str(reg))
		get_tree().quit()
	if "rvsink" in OS.get_cmdline_user_args():
		debug_no_save = true
		if state != State.PLAY:
			start_game()
		for f in 40:
			await get_tree().physics_frame
			var s := ""
			for r in rivals:
				if is_instance_valid(r):
					s += "(%.0f,%.2f,%.0f) " % [r.global_position.x, r.global_position.y, r.global_position.z]
			print("[sk] f=%02d %s" % [f, s])
		# 격추 → 리스폰 경로. 사용자가 본 상황이 이쪽이다.
		for r in rivals:
			if is_instance_valid(r):
				r.hp = 1
				r.take_damage(1)
		await get_tree().create_timer(0.6).timeout
		var worst := 999.0
		var sunk := 0
		for f in 90:
			await get_tree().physics_frame
			for r in rivals:
				if not is_instance_valid(r):
					continue
				worst = minf(worst, r.global_position.y)
				if r.global_position.y < -1.0:
					sunk += 1
		print("[sk] 리스폰 %d대 검증: 최저 y=%.2f  지면아래 관측=%d프레임" % [rivals.size(), worst, sunk])
		print("[sk] %s" % ("통과 — 지면 아래로 꺼진 트럭 없음" if sunk == 0 else "*** 실패 — 꺼진 트럭 있음 ***"))
		get_tree().quit()
	if "perf" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(3.0).timeout   # 워밍업
		var samples: Array = []
		var dcs: Array = []
		for i in 180:
			await get_tree().process_frame
			samples.append(Engine.get_frames_per_second())
			dcs.append(RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		samples.sort()
		dcs.sort()
		var med: float = float(samples[samples.size() / 2])
		var lo: float = float(samples[int(samples.size() * 0.05)])
		var dc_med: float = float(dcs[dcs.size() / 2])
		print("[dbg] FPS 중앙값 %.0f / 하위5%% %.0f  |  드로우콜 중앙 %.0f  |  노드 %d" % [
			med, lo, dc_med, get_tree().get_node_count()])
		get_tree().quit()
	if "inputdbg" in OS.get_cmdline_user_args():
		debug_no_save = true
		start_game()
		await get_tree().create_timer(2.0).timeout
		print("[dbg] 패드=%s  입력=%s  speed=%.2f" % [
			str(Input.get_connected_joypads()), str(car.last_input), car.speed])
		print("[dbg] W=%s UP=%s S=%s DOWN=%s A=%s D=%s LEFT=%s RIGHT=%s" % [
			str(Input.is_key_pressed(KEY_W)), str(Input.is_key_pressed(KEY_UP)),
			str(Input.is_key_pressed(KEY_S)), str(Input.is_key_pressed(KEY_DOWN)),
			str(Input.is_key_pressed(KEY_A)), str(Input.is_key_pressed(KEY_D)),
			str(Input.is_key_pressed(KEY_LEFT)), str(Input.is_key_pressed(KEY_RIGHT))])
		print("[dbg] auto_drive=%s botplay=%s" % [str(car.auto_drive), str(botplay)])
	if "story" in OS.get_cmdline_user_args():
		_show_story()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("menutab="):
			start_game()
			score = 180000.0
			open_menu()
			menu.tab = int(a.substr(8))
			for b in OS.get_cmdline_user_args():
				if b.begins_with("menurow="):
					menu.row = int(b.substr(8))
			menu.refresh()

	for a in OS.get_cmdline_user_args():
		if a.begins_with("money="):
			score = float(a.substr(6))
			career_earnings = maxf(career_earnings, score)
			_check_district_unlocks()
		if a.begins_with("paylv="):
			upgrade_levels["pay"] = int(a.substr(6))
			car.apply_upgrades(upgrade_levels)
	_maybe_debug_shot()


var _shot_path := ""
var _shot_delay := 3.0


func _maybe_debug_shot() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			_shot_path = a.substr(5)
		elif a.begins_with("delay="):
			_shot_delay = float(a.substr(6))
	if _shot_path != "":
		_do_shot()


func _do_shot() -> void:
	await get_tree().create_timer(_shot_delay).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shot_path)
	get_tree().quit()


# ---------------------------------------------------------------- 월드

func _setup_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.55, 1.0)
	sky_mat.sky_horizon_color = Color(1.0, 0.72, 0.55)
	sky_mat.ground_bottom_color = Color(0.35, 0.3, 0.45)
	sky_mat.ground_horizon_color = Color(1.0, 0.72, 0.55)
	sky_mat.sun_angle_max = 25.0
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 1.1
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.55
	# 블록 덩어리끼리 맞닿는 구석을 어둡게 해준다. 이게 없으면 벽과 바닥이 한 덩어리로 붙어 보인다.
	e.ssao_enabled = true
	e.ssao_radius = 1.8
	e.ssao_intensity = 2.2
	e.ssao_power = 1.4
	e.fog_enabled = true
	e.fog_light_color = Color(0.95, 0.72, 0.85)
	e.fog_density = 0.0005
	env.environment = e
	add_child(env)
	world_env = e
	world_sky = sky_mat

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, 132, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	add_child(sun)
	world_sun = sun

	city = City.new()
	add_child(city)
	city.build(randi())

	car = Car.new()
	add_child(car)
	_spawn_car()
	car.crashed.connect(_on_crash)
	car.bumped.connect(_on_bump)
	car.scraped.connect(_on_scrape)
	car.landed.connect(_on_land)
	car.drift_boosted.connect(_on_drift_boost)

	cam = Camera3D.new()
	cam.fov = 72.0
	# 도로가 넓어져 시야가 멀리까지 트이면서 드로우콜이 늘었다.
	# 안개로 가려지는 지점에서 잘라낸다.
	cam.far = 480.0
	add_child(cam)

	marker = Node3D.new()
	add_child(marker)
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.2
	cyl.height = 130.0
	pillar.mesh = cyl
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.2, 1.0, 0.55, 0.32)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.emission_enabled = true
	pm.emission = Color(0.2, 1.0, 0.55)
	pm.emission_energy_multiplier = 1.4
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pillar.material_override = pm
	pillar.position.y = 65.0
	marker.add_child(pillar)
	marker_pillar = pillar

	marker_ring = MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(4.0, 4.0, 4.0)
	marker_ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.9, 0.2)
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.8, 0.1)
	rmat.emission_energy_multiplier = 1.8
	marker_ring.material_override = rmat
	marker_ring.position.y = 6.0
	marker.add_child(marker_ring)

	# 배그 구역 전용 보급 상자. 픽업 지점 위에 같이 떨어져 있다.
	supply_crate = Node3D.new()
	supply_crate.visible = false
	marker.add_child(supply_crate)
	var crate := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(5.0, 4.0, 5.0)
	crate.mesh = cb
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.85, 0.35, 0.12)
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.45, 0.1)
	cm.emission_energy_multiplier = 0.9
	crate.material_override = cm
	crate.position.y = 2.2
	supply_crate.add_child(crate)
	# 낙하산. 천이 아니라 그냥 뒤집힌 원뿔이다. 똥겜이니까 이 정도면 됐다.
	var chute := MeshInstance3D.new()
	var cc := CylinderMesh.new()
	cc.top_radius = 5.6
	cc.bottom_radius = 0.4
	cc.height = 4.6
	cc.radial_segments = 10
	chute.mesh = cc
	var chm := StandardMaterial3D.new()
	chm.albedo_color = Color(1.0, 0.92, 0.35)
	chm.emission_enabled = true
	chm.emission = Color(1.0, 0.8, 0.2)
	chm.emission_energy_multiplier = 1.1
	chm.cull_mode = BaseMaterial3D.CULL_DISABLED
	chute.material_override = chm
	chute.position.y = 8.6
	supply_crate.add_child(chute)
	# 연막. 배그 보급 상자 특유의 빨간 연기 대신 기둥 하나로 때운다.
	var smoke := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 1.1
	sc.bottom_radius = 1.6
	sc.height = 16.0
	smoke.mesh = sc
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(1.0, 0.3, 0.25, 0.3)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	smoke.material_override = sm
	smoke.position = Vector3(4.0, 8.0, 0.0)
	supply_crate.add_child(smoke)

	arrow = Node3D.new()
	add_child(arrow)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.85
	cone.height = 2.6
	tip.mesh = cone
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(1.0, 0.25, 0.85)
	am.emission_enabled = true
	am.emission = Color(1.0, 0.25, 0.85)
	am.emission_energy_multiplier = 1.2
	tip.material_override = am
	tip.rotation_degrees = Vector3(-90, 0, 0)
	arrow.add_child(tip)

	_setup_bluezone()


func _zone_limit() -> float:
	# 원이 도시 밖으로 튀어나가지 않게 중심을 묶어두는 반경
	return City.GRID * City.CELL * 0.5


func _zone_reset() -> void:
	bluezone_center = Vector3.ZERO
	# 도시 한 변의 절반보다 살짝 크게 시작해서 외곽에서 좁혀 들어오는 느낌을 준다.
	bluezone_radius = debug_bz_radius if debug_bz_radius > 0.0 else City.GRID * City.CELL * 0.62
	zone_phase = 0
	zone_wait = ZONE_WAIT
	zone_shrink_left = 0.0
	zone_from_center = bluezone_center
	zone_from_radius = bluezone_radius
	_plan_next_zone()


func _plan_next_zone() -> void:
	zone_next_radius = maxf(ZONE_MIN_RADIUS, bluezone_radius * 0.66)
	# 새 원은 현재 원 안쪽에 들어가야 한다. 그 여유분만큼만 중심을 옮긴다.
	var slack: float = maxf(0.0, bluezone_radius - zone_next_radius)
	# 최소 반경까지 줄어든 뒤에도 원이 얼어붙지 않게 조금씩 돌아다니게 한다.
	if slack < 6.0:
		slack = zone_next_radius * 0.55
	var ang: float = randf() * TAU
	var off: float = slack * sqrt(randf()) * 0.9
	var c := bluezone_center + Vector3(cos(ang) * off, 0.0, sin(ang) * off)
	var lim: float = maxf(0.0, _zone_limit() - zone_next_radius * 0.75)
	c.x = clampf(c.x, -lim, lim)
	c.z = clampf(c.z, -lim, lim)
	zone_next_center = c
	zone_phase += 1


func _zone_dir_name(from: Vector3, to: Vector3) -> String:
	var d := to - from
	if Vector2(d.x, d.z).length() < 12.0:
		return "거의 제자리"
	var ns: String = "북" if d.z < 0.0 else "남"
	var ew: String = "동" if d.x > 0.0 else "서"
	if absf(d.z) < absf(d.x) * 0.45:
		return ew + "쪽"
	if absf(d.x) < absf(d.z) * 0.45:
		return ns + "쪽"
	return ns + ew + "쪽"


func _tick_bluezone(delta: float) -> void:
	if zone_shrink_left > 0.0:
		zone_shrink_left -= delta
		var t: float = clampf(1.0 - zone_shrink_left / ZONE_SHRINK, 0.0, 1.0)
		bluezone_center = zone_from_center.lerp(zone_next_center, t)
		bluezone_radius = lerpf(zone_from_radius, zone_next_radius, t)
		if zone_shrink_left <= 0.0:
			zone_shrink_left = 0.0
			bluezone_center = zone_next_center
			bluezone_radius = zone_next_radius
			zone_wait = ZONE_WAIT
			_plan_next_zone()
			_toast("자기장 수축 완료. 다음 원은 %s입니다" % _zone_dir_name(bluezone_center, zone_next_center))
	else:
		zone_wait -= delta
		if zone_wait <= 0.0:
			zone_wait = 0.0
			zone_from_center = bluezone_center
			zone_from_radius = bluezone_radius
			zone_shrink_left = ZONE_SHRINK
			_pop("자기장 이동!", Color(0.9, 0.4, 1.0))
			_toast("자기장이 %s으로 밀려옵니다. 가운데에 있다고 안전한 거 아닙니다" % _zone_dir_name(bluezone_center, zone_next_center))
	# X/Z 만 줄인다. Y 를 건드리면 벽 높이가 같이 변해서 바닥을 뚫는다.
	bluezone_mesh.scale = Vector3(bluezone_radius, 42.0, bluezone_radius)
	bluezone_mesh.position = bluezone_center + Vector3(0, 21.4, 0)
	minimap.bluezone_radius = bluezone_radius
	minimap.bluezone_center = bluezone_center
	minimap.next_center = zone_next_center
	minimap.next_radius = zone_next_radius

	var flat_car_2d := Vector2(car.global_position.x, car.global_position.z)
	var flat_center_2d := Vector2(bluezone_center.x, bluezone_center.z)
	if flat_car_2d.distance_to(flat_center_2d) > bluezone_radius:
		# 제한시간은 안 건드린다. 자기장은 체력으로만 압박한다.
		_hurt(ZONE_DPS * delta, "자기장")
		bluezone_warning_cooldown -= delta
		if bluezone_warning_cooldown <= 0.0:
			bluezone_warning_cooldown = 1.8
			_pop("자기장 밖! 체력 급감!", Color(1.0, 0.25, 0.85))
			_toast("자기장 밖입니다! 체력이 깎이고 있습니다!")
			_shake(0.15)


func _setup_bluezone() -> void:
	if bluezone_mesh != null:
		return
	bluezone_mesh = MeshInstance3D.new()
	# 캡 없는 원기둥(벽면만). 캡이 있으면 바닥과 같은 평면에 깔려서 z-fighting 이 난다.
	var wall := CylinderMesh.new()
	wall.top_radius = 1.0
	wall.bottom_radius = 1.0
	wall.height = 1.0
	wall.radial_segments = 64
	wall.cap_top = false
	wall.cap_bottom = false
	bluezone_mesh.mesh = wall
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.65, 0.15, 0.95, 0.18)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.emission_enabled = true
	bm.emission = Color(0.75, 0.2, 1.0)
	bm.emission_energy_multiplier = 1.6
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 반투명 벽이 지형을 뚫고 보이지 않게 한다. 깊이 정렬이 흔들려 깜빡이던 원인.
	bm.no_depth_test = false
	bm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bluezone_mesh.material_override = bm
	# 벽 높이는 고정(scale 로 늘리지 않는다). 바닥에 붙지 않도록 0.4 띄운다.
	bluezone_mesh.mesh = wall
	bluezone_mesh.visible = false
	bluezone_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bluezone_mesh)


# ---------------------------------------------------------------- UI

func _mklabel(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.12, 0.9))
	l.add_theme_constant_override("outline_size", maxi(6, size / 5))
	return l


func _panel(preset: int, margin: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(preset)
	box.add_theme_constant_override("separation", 2)
	match preset:
		Control.PRESET_TOP_LEFT:
			box.offset_left = margin.x
			box.offset_top = margin.y
		Control.PRESET_TOP_RIGHT:
			box.offset_right = -margin.x
			box.offset_top = margin.y
			box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			box.alignment = BoxContainer.ALIGNMENT_END
		Control.PRESET_BOTTOM_LEFT:
			box.offset_left = margin.x
			box.offset_bottom = -margin.y
			box.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_:
			pass
	return box


func _gradient_bg(a: Color, b: Color, c: Color) -> TextureRect:
	var tr := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, c)
	g.add_point(0.5, b)
	gt.gradient = g
	gt.width = 256
	gt.height = 256
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 1)
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	return tr


func _setup_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)

	# 무지개 환각 시점 전용 화면 덧칠. HUD 보다 먼저 넣어서 글자를 안 가린다.
	# 단색을 깜빡이면 그냥 화면이 하얘진다. 무지개 띠를 화면 밖까지 깔고 옆으로 흘린다.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array()
	grad.colors = PackedColorArray()
	var stops := 13   # 무지개 2바퀴 + 이음매 1
	for i in stops:
		grad.add_point(float(i) / float(stops - 1),
			Color.from_hsv(fmod(float(i) / 6.0, 1.0), 0.95, 1.0))
	grad.remove_point(0)
	grad.remove_point(0)
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 512
	gtex.height = 8
	gtex.fill_from = Vector2(0, 0)
	gtex.fill_to = Vector2(1, 0)
	trip_rect = TextureRect.new()
	trip_rect.texture = gtex
	trip_rect.stretch_mode = TextureRect.STRETCH_SCALE
	trip_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trip_rect.visible = false
	var tmat := CanvasItemMaterial.new()
	tmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	trip_rect.material = tmat
	ui.add_child(trip_rect)

	# 두 번째 띠는 세로로 흐른다. 하나만 쓰면 그냥 가로줄무늬로 보인다.
	var gtex2 := GradientTexture2D.new()
	gtex2.gradient = grad
	gtex2.width = 8
	gtex2.height = 512
	gtex2.fill_from = Vector2(0, 0)
	gtex2.fill_to = Vector2(0, 1)
	trip_rect2 = TextureRect.new()
	trip_rect2.texture = gtex2
	trip_rect2.stretch_mode = TextureRect.STRETCH_SCALE
	trip_rect2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trip_rect2.visible = false
	trip_rect2.material = tmat
	ui.add_child(trip_rect2)

	# ---- 타이틀
	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title_root)
	var tbg := _gradient_bg(Color(1.0, 0.45, 0.75), Color(1.0, 0.72, 0.3), Color(0.35, 0.85, 1.0))
	tbg.modulate.a = 0.66
	title_root.add_child(tbg)

	var tv := VBoxContainer.new()
	tv.set_anchors_preset(Control.PRESET_FULL_RECT)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 6)
	title_root.add_child(tv)

	var t1 := _mklabel("퀵 루프", 108, Color(1, 1, 1))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t1)
	var t2 := _mklabel("Q U I C K   L O O P", 30, Color(0.15, 0.05, 0.25))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t2)
	var t3 := _mklabel("식지 않게. 죽지 않게. 늦지 않게.", 26, Color(1, 1, 1))
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(t3)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 34)
	tv.add_child(spacer)

	var keys := _mklabel(
		"게임 중 ESC 를 누르면 메뉴가 열린다\n"
		+ "스토리 · 튜토리얼 · 업그레이드 · 도전과제",
		24, Color(1, 1, 1))
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(keys)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 26)
	tv.add_child(spacer2)

	var t4 := _mklabel("스페이스를 눌러 출근", 38, Color(0.1, 0.05, 0.2))
	t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t4.name = "Blink"
	tv.add_child(t4)

	# ---- HUD
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud_root)

	var tl := _panel(Control.PRESET_TOP_LEFT, Vector2(26, 18))
	lbl_score = _mklabel("0 원", 44, Color(1, 0.95, 0.4))
	tl.add_child(lbl_score)
	var goal_bg := ColorRect.new()
	goal_bg.color = Color(0, 0, 0, 0.45)
	goal_bg.custom_minimum_size = Vector2(300, 14)
	goal_bar = ColorRect.new()
	goal_bar.color = Color(0.4, 1.0, 0.55)
	goal_bar.size = Vector2(0, 14)
	goal_bg.add_child(goal_bar)
	tl.add_child(goal_bg)
	lbl_goal = _mklabel("", 20, Color(0.85, 1.0, 0.9))
	tl.add_child(lbl_goal)
	lbl_combo = _mklabel("연속 0", 24, Color(1, 1, 1))
	tl.add_child(lbl_combo)
	hud_root.add_child(tl)

	var tc := VBoxContainer.new()
	tc.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tc.offset_top = 10
	lbl_time = _mklabel("0.0", 76, Color(1, 1, 1))
	lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(lbl_time)
	lbl_task = _mklabel("픽업하러 가는 중", 26, Color(0.6, 1.0, 0.7))
	lbl_task.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tc.add_child(lbl_task)
	hud_root.add_child(tc)

	var tr2 := _panel(Control.PRESET_TOP_RIGHT, Vector2(26, 18))
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(196, 196)
	minimap.city = city
	minimap.car = car
	tr2.add_child(minimap)
	lbl_dist = _mklabel("000 m", 36, Color(1, 0.6, 0.9))
	lbl_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr2.add_child(lbl_dist)
	hud_root.add_child(tr2)

	var bl := _panel(Control.PRESET_BOTTOM_LEFT, Vector2(26, 22))
	lbl_speed = _mklabel("0 km/h", 46, Color(0.5, 1.0, 1.0))
	bl.add_child(lbl_speed)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.45)
	bar_bg.custom_minimum_size = Vector2(230, 16)
	hp_label = _mklabel("", 20, Color(1, 0.75, 0.75))
	hp_bg = ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.45)
	hp_bg.custom_minimum_size = Vector2(230, 18)
	hp_bar = ColorRect.new()
	hp_bar.color = Color(1.0, 0.35, 0.35)
	hp_bar.size = Vector2(230, 18)
	hp_bg.add_child(hp_bar)

	boost_bar = ColorRect.new()
	boost_bar.color = Color(1.0, 0.85, 0.1)
	boost_bar.size = Vector2(230, 16)
	boost_bar.position = Vector2.ZERO
	bar_bg.add_child(boost_bar)

	# 드리프트 충전 게이지. 평소엔 숨어 있다가 물고 있을 때만 나온다.
	drift_bg = ColorRect.new()
	drift_bg.color = Color(0, 0, 0, 0.45)
	drift_bg.custom_minimum_size = Vector2(230, 14)
	drift_bg.visible = false
	drift_bar = ColorRect.new()
	drift_bar.color = Color(0.35, 0.75, 1.0)
	drift_bar.size = Vector2(0, 14)
	drift_bg.add_child(drift_bar)
	drift_label = _mklabel("", 20, Color(0.7, 0.9, 1.0))
	drift_label.visible = false

	bl.add_child(bar_bg)
	bl.add_child(drift_bg)
	bl.add_child(drift_label)
	bl.add_child(hp_bg)
	bl.add_child(hp_label)
	hud_root.add_child(bl)

	var bc := VBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bc.offset_bottom = -26
	bc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for i in 3:
		var sz: int = 22 if i < 2 else 30
		var sl := _mklabel("", sz, Color(1, 0.85, 0.5))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.modulate.a = 0.0
		bc.add_child(sl)
		toast_slots.append(sl)
	hud_root.add_child(bc)

	lbl_pop = _mklabel("", 84, Color(1, 1, 1))
	lbl_pop.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_pop.pivot_offset = Vector2(640, 360)
	hud_root.add_child(lbl_pop)

	scope = Scope.new()
	scope.set_anchors_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.visible = false
	hud_root.add_child(scope)
	# HUD 글자 밑에 깔아야 남은 시간·체력이 경통에 안 가린다.
	hud_root.move_child(scope, 0)

	crosshair = _mklabel("✛", 32, Color(1.0, 0.35, 0.35, 0.8))
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(crosshair)

	# ---- 결과
	result_root = Control.new()
	result_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(result_root)
	var rbg := _gradient_bg(Color(0.2, 0.1, 0.4), Color(0.85, 0.25, 0.55), Color(1.0, 0.65, 0.3))
	rbg.modulate.a = 0.92
	result_root.add_child(rbg)

	var rv := VBoxContainer.new()
	rv.set_anchors_preset(Control.PRESET_FULL_RECT)
	rv.offset_left = 70
	rv.offset_right = -70
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 6)
	result_root.add_child(rv)

	# ---- 스토리
	story_root = Control.new()
	story_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(story_root)
	var sbg := _gradient_bg(Color(0.12, 0.05, 0.28), Color(0.7, 0.15, 0.45), Color(1.0, 0.55, 0.25))
	sbg.modulate.a = 0.94
	story_root.add_child(sbg)
	var sv := VBoxContainer.new()
	sv.set_anchors_preset(Control.PRESET_FULL_RECT)
	sv.offset_left = 90
	sv.offset_right = -90
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", 30)
	story_root.add_child(sv)
	story_label = _mklabel("", 44, Color(1, 1, 1))
	story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_child(story_label)
	var shint := _mklabel("SPACE 다음      ESC 건너뛰기", 22, Color(1, 1, 1, 0.75))
	shint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(shint)
	story_root.visible = false

	# ---- 튜토리얼 배너
	tut_root = Control.new()
	tut_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	tut_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(tut_root)
	var tstrip := ColorRect.new()
	tstrip.color = Color(0.05, 0.05, 0.12, 0.72)
	tstrip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tstrip.anchor_left = 0.0
	tstrip.anchor_right = 1.0
	tstrip.anchor_top = 0.60
	tstrip.anchor_bottom = 0.60
	tstrip.offset_top = 0
	tstrip.offset_bottom = 130
	tut_root.add_child(tstrip)
	var tv2 := VBoxContainer.new()
	tv2.set_anchors_preset(Control.PRESET_FULL_RECT)
	tv2.anchor_top = 0.60
	tv2.anchor_bottom = 0.60
	tv2.offset_top = 12
	tv2.offset_bottom = 130
	tv2.add_theme_constant_override("separation", 4)
	tut_root.add_child(tv2)
	tut_label = _mklabel("", 40, Color(0.45, 1.0, 0.65))
	tut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv2.add_child(tut_label)
	tut_sub = _mklabel("", 22, Color(0.9, 0.92, 1.0))
	tut_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv2.add_child(tut_sub)
	var tskip := _mklabel("ESC 건너뛰기", 19, Color(0.62, 0.66, 0.8))
	tskip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv2.add_child(tskip)
	tut_root.visible = false

	# ---- 도전과제 배너
	ach_root = Control.new()
	ach_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ach_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(ach_root)
	var slot := Control.new()
	slot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	slot.offset_left = -470
	slot.offset_top = -170
	slot.offset_right = -24
	slot.offset_bottom = -44
	ach_root.add_child(slot)

	ach_panel = Control.new()
	ach_panel.size = Vector2(446, 126)
	slot.add_child(ach_panel)

	var abg := ColorRect.new()
	abg.color = Color(0.06, 0.05, 0.13, 0.92)
	abg.size = Vector2(446, 126)
	ach_panel.add_child(abg)
	var accent := ColorRect.new()
	accent.color = Color(1.0, 0.85, 0.25)
	accent.size = Vector2(7, 126)
	ach_panel.add_child(accent)

	var av := VBoxContainer.new()
	av.position = Vector2(24, 14)
	av.custom_minimum_size = Vector2(404, 0)
	av.add_theme_constant_override("separation", 2)
	ach_panel.add_child(av)
	var atitle := _mklabel("도전과제 달성", 19, Color(1.0, 0.85, 0.25))
	av.add_child(atitle)
	ach_name = _mklabel("", 31, Color(1, 1, 1))
	av.add_child(ach_name)
	ach_desc = _mklabel("", 19, Color(0.72, 0.76, 0.9))
	av.add_child(ach_desc)
	ach_root.visible = false

	# ---- 구역 해금 연출
	cut_root = Control.new()
	cut_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	cut_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(cut_root)
	var cbg := ColorRect.new()
	cbg.color = Color(0.03, 0.02, 0.07, 0.94)
	cbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	cut_root.add_child(cbg)
	cbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cv := VBoxContainer.new()
	cut_root.add_child(cv)
	cv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cv.offset_left = 80
	cv.offset_right = -80
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 10)
	cut_title = _mklabel("구역 해금", 30, Color(1.0, 0.85, 0.25))
	cut_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cut_title)
	cut_name = _mklabel("", 66, Color(1, 1, 1))
	cut_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cut_name)
	cut_art = Control.new()
	cut_art.custom_minimum_size = Vector2(0, 190)
	cut_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(cut_art)
	cut_line = _mklabel("", 32, Color(0.92, 0.95, 1.0))
	cut_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cut_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cut_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_child(cut_line)
	var chint := _mklabel("아무 키나 눌러 계속", 20, Color(0.7, 0.72, 0.85))
	chint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(chint)
	cut_root.visible = false

	# ---- 메뉴
	menu = GameMenu.new()
	ui.add_child(menu)
	menu.setup(self)
	menu.closed.connect(_on_menu_closed)
	menu.quit_shift.connect(_quit_shift)
	result_title = _mklabel("1일차 종료", 82, Color(1, 1, 1))
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(result_title)
	# GTA 수배 레벨 스타일 별 다섯 개. 항상 만점.
	result_rating = _mklabel("★ ★ ★ ★ ★", 64, Color(1.0, 0.82, 0.12))
	result_rating.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_rating.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_rating.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	result_rating.add_theme_constant_override("outline_size", 14)
	rv.add_child(result_rating)
	result_comment = _mklabel("", 30, Color(1, 1, 1))
	result_comment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_comment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(result_comment)
	var rgap := Control.new()
	rgap.custom_minimum_size = Vector2(0, 14)
	rv.add_child(rgap)
	result_body = _mklabel("", 25, Color(1, 1, 1))
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(result_body)
	var r3 := _mklabel("R 다시 출근      ESC 퇴사", 28, Color(1, 1, 1))
	r3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(r3)


# ---------------------------------------------------------------- 상태

func _quit_shift() -> void:
	# close() 가 _on_menu_closed 를 통해 state 를 PLAY 로 되돌린 뒤 결과창으로 넘긴다
	menu.close()
	_end_game()


func _on_menu_closed() -> void:
	if state == State.MENU:
		state = State.PLAY
		car.set_physics_process(true)
		hud_root.visible = true


func open_menu() -> void:
	if state != State.PLAY:
		return
	state = State.MENU
	_set_aiming(false)
	car.set_physics_process(false)
	hud_root.visible = false
	menu.open()


func buy_upgrade(idx: int) -> void:
	if idx < 0 or idx >= UPGRADES.size():
		return
	var u: Dictionary = UPGRADES[idx]
	var lv: int = upgrade_levels.get(u["key"], 0)
	if lv >= u["cost"].size():
		return
	var cost := float(u["cost"][lv])
	if score < cost:
		return
	score -= cost
	upgrade_levels[u["key"]] = lv + 1
	if String(u["key"]) == "armor":
		player_hp += ARMOR_HP_PER_LV   # 늘어난 만큼 바로 채워준다
	car.apply_upgrades(upgrade_levels)
	_toast("%s Lv.%d 장착" % [String(u["name"]), lv + 1])


func is_district_unlocked(idx: int) -> bool:
	if idx < 0 or idx >= City.THEMES.size():
		return false
	var cost: int = int(City.THEMES[idx].get("unlock_cost", 0))
	return career_earnings >= float(cost)


func select_district(idx: int) -> void:
	if idx < 0 or idx >= City.THEMES.size():
		return
	if not is_district_unlocked(idx):
		var need: float = float(City.THEMES[idx].get("unlock_cost", 0)) - career_earnings
		_toast("잠긴 구역입니다! (누적 %s원 더 필요)" % _won(maxf(0.0, need)))
		return
	selected_district = idx
	_save()
	menu.close()
	start_game(true)
	_toast("구역 출근: %s (보수 %.1f배)" % [String(City.THEMES[idx]["name"]), float(City.THEMES[idx].get("pay_mult", 1.0))])


func _check_district_unlocks(silent := false) -> void:
	var all_unlocked := true
	for i in City.THEMES.size():
		if not is_district_unlocked(i):
			all_unlocked = false
			continue
		if bool(seen_unlock_cutscene.get(i, false)):
			continue
		# UI 가 아직 없거나(부팅 중) 기본 구역이면 연출 없이 소진한다.
		# 예전에는 여기서 무조건 seen 처리해서 연출이 영영 안 떴다.
		if silent or cut_root == null or int(City.THEMES[i].get("unlock_cost", 0)) <= 0:
			seen_unlock_cutscene[i] = true
			_save()
		else:
			_queue_unlock_cutscene(i)
	if all_unlocked:
		_unlock("district_all")


func _queue_unlock_cutscene(idx: int) -> void:
	if cut_root == null:
		return
	if cut_root.visible:
		# 한 번에 여러 개가 열리면 줄 세운다
		if not pending_cutscenes.has(idx):
			pending_cutscenes.append(idx)
		return
	seen_unlock_cutscene[idx] = true
	_save()
	var nm := String(City.THEMES[idx]["name"])
	cut_name.text = nm
	for ch in cut_art.get_children():
		ch.queue_free()
	if idx == City.PUBG_DISTRICT_INDEX:
		cut_line.text = "모아둔 돈으로 총을 샀습니다.\n이제 경쟁사가 총을 쏴도 대응할 수 있습니다."
		_draw_gun(cut_art)
	elif idx == City.MACHO_DISTRICT_INDEX:
		cut_line.text = "모아둔 돈으로 펀치 기계를 샀습니다.\n트럭에 권투 글러브가 달렸습니다."
		_draw_punch_machine(cut_art)
	else:
		cut_line.text = "새 배달 구역이 열렸습니다."
		_draw_box_stack(cut_art)
	cut_root.visible = true
	cut_timer = 6.0
	if state == State.PLAY:
		car.set_physics_process(false)


func _cut_rect(parent: Control, r: Rect2, c: Color) -> void:
	# 부모의 가로 중앙(anchor 0.5)을 기준으로 놓는다.
	# position 을 직접 주면 컨테이너가 레이아웃할 때 덮어써서 엉뚱한 데로 간다.
	var cr := ColorRect.new()
	cr.color = c
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.anchor_left = 0.5
	cr.anchor_right = 0.5
	cr.anchor_top = 0.0
	cr.anchor_bottom = 0.0
	cr.offset_left = r.position.x
	cr.offset_right = r.position.x + r.size.x
	cr.offset_top = r.position.y + 100.0
	cr.offset_bottom = r.position.y + 100.0 + r.size.y
	parent.add_child(cr)


func _draw_gun(p: Control) -> void:
	var metal := Color(0.30, 0.32, 0.38)
	var dark := Color(0.16, 0.16, 0.2)
	var wood := Color(0.45, 0.28, 0.14)
	_cut_rect(p, Rect2(-210, -14, 300, 26), metal)          # 총열
	_cut_rect(p, Rect2(-40, -34, 150, 62), dark)            # 몸통
	_cut_rect(p, Rect2(110, -30, 90, 54), wood)             # 개머리판
	_cut_rect(p, Rect2(10, 28, 34, 60), dark)               # 손잡이
	_cut_rect(p, Rect2(-30, 28, 30, 46), metal)             # 탄창
	_cut_rect(p, Rect2(-235, -8, 34, 14), dark)             # 총구
	_cut_rect(p, Rect2(-10, -48, 60, 14), metal)            # 조준경


func _draw_punch_machine(p: Control) -> void:
	var body := Color(0.86, 0.14, 0.2)
	var steel := Color(0.35, 0.37, 0.44)
	var glove := Color(0.95, 0.25, 0.25)
	_cut_rect(p, Rect2(-70, 10, 140, 78), steel)            # 받침
	_cut_rect(p, Rect2(-52, -60, 104, 74), body)            # 본체
	_cut_rect(p, Rect2(-36, -46, 72, 30), Color(0.1, 0.9, 0.8))  # 점수판
	_cut_rect(p, Rect2(52, -34, 96, 18), steel)             # 팔대
	_cut_rect(p, Rect2(148, -56, 62, 62), glove)            # 글러브
	_cut_rect(p, Rect2(196, -40, 26, 30), glove.darkened(0.2))
	_cut_rect(p, Rect2(-14, -92, 28, 32), steel)            # 상단 봉


func _draw_box_stack(p: Control) -> void:
	var b := Color(1.0, 0.78, 0.15)
	_cut_rect(p, Rect2(-80, 10, 160, 70), b)
	_cut_rect(p, Rect2(-56, -56, 112, 62), b.lightened(0.12))
	_cut_rect(p, Rect2(-30, -104, 60, 44), b.lightened(0.25))
	_cut_rect(p, Rect2(-80, 4, 160, 8), b.darkened(0.35))


func close_unlock_cutscene() -> void:
	if not cut_root.visible:
		return
	cut_root.visible = false
	cut_timer = 0.0
	if not pending_cutscenes.is_empty():
		var nxt: int = pending_cutscenes.pop_front()
		_queue_unlock_cutscene(nxt)
		return
	if state == State.PLAY:
		car.set_physics_process(true)


func restart_day() -> void:
	menu.close()
	start_game()
	_toast("처음부터 다시 시작합니다")


func replay_unlock_cutscenes() -> void:
	pending_cutscenes.clear()
	close_unlock_cutscene()
	for i in [City.PUBG_DISTRICT_INDEX, City.MACHO_DISTRICT_INDEX]:
		seen_unlock_cutscene[i] = false
	_queue_unlock_cutscene(City.PUBG_DISTRICT_INDEX)
	pending_cutscenes.append(City.MACHO_DISTRICT_INDEX)


func grant_test_money() -> void:
	score = 10000000.0
	career_earnings = maxf(career_earnings, score)
	_check_district_unlocks()
	_save()
	_toast("테스트용 소지금 1,000만원 지급")


func reset_save() -> void:
	achieved.clear()
	best_score = 0.0
	career_earnings = 0.0
	selected_district = 0
	tutorial_done = false
	ach_queue.clear()
	ach_timer = 0.0
	ach_root.visible = false
	if not debug_no_save:
		var abs_path := ProjectSettings.globalize_path(SAVE_PATH)
		if FileAccess.file_exists(SAVE_PATH):
			DirAccess.remove_absolute(abs_path)
	_save()


func _unlock(key: String) -> void:
	if achieved.get(key, false):
		return
	achieved[key] = true
	for a in ACHIEVEMENTS:
		if a["key"] == key:
			ach_queue.append(a)
			break
	_save()


func _check_achievements() -> void:
	if deliveries >= 1: _unlock("first")
	if combo >= 10: _unlock("combo10")
	if cows_hit >= 10: _unlock("cow10")
	if bumps >= 50: _unlock("scratch50")
	if crashes >= 20: _unlock("gta")
	if cold_deliveries >= 5: _unlock("cold5")
	if cold_deliveries >= 10: _unlock("iceage")
	if horns >= 30: _unlock("horn30")
	if tips_total >= 100000.0: _unlock("tiprich")
	if top_speed >= 200.0: _unlock("fast")
	if car.air_time >= 2.0: _unlock("air")
	if rival_kills >= 1: _unlock("rival1")
	if rival_kills >= 10: _unlock("rival10")
	if goal_reached and selected_district == City.PUBG_DISTRICT_INDEX and bool(city.theme.get("is_pubg", false)): _unlock("pubg_clear")
	var total := 0
	for v in upgrade_levels.values():
		total += int(v)
	if total >= 6: _unlock("tuned")
	if goal_reached: _unlock("day1")
	_check_district_unlocks()


func start_tutorial() -> void:
	tutorial_step = 0
	_show_tutorial_step()


func _show_tutorial_step() -> void:
	if tutorial_step < 0 or tutorial_step >= TUTORIAL.size():
		tut_root.visible = false
		return
	var st: Dictionary = TUTORIAL[tutorial_step]
	tut_label.text = String(st["t"])
	tut_sub.text = String(st["s"])
	tut_root.visible = true


func skip_tutorial() -> void:
	if tutorial_step < 0:
		return
	tutorial_step = -1
	tut_root.visible = false
	tutorial_done = true
	_save()
	_toast("튜토리얼 건너뜀. 설정에서 다시 볼 수 있습니다")


func _advance_tutorial() -> void:
	tutorial_step += 1
	if tutorial_step >= TUTORIAL.size():
		tutorial_step = -1
		tut_root.visible = false
		tutorial_done = true
		_save()
		_toast("이제 시작입니다. 100만원 갚으세요")
		return
	_show_tutorial_step()


func _tick_tutorial() -> void:
	if tutorial_step < 0:
		return
	var inp: Dictionary = car.last_input
	match tutorial_step:
		0:
			if car.speed > 8.0: _advance_tutorial()
		1:
			if absf(float(inp.get("steer", 0.0))) > 0.5 and car.speed > 5.0: _advance_tutorial()
		2:
			if has_package: _advance_tutorial()
		3:
			if car.boosting: _advance_tutorial()
		4:
			if car.jumped_once: _advance_tutorial()
		5:
			if deliveries >= 1: _advance_tutorial()
		6:
			if car.drifts_done >= 1: _advance_tutorial()
		7:
			if cam_switched: _advance_tutorial()
		8:
			pass


func _show_story() -> void:
	state = State.STORY
	story_index = 0
	title_root.visible = false
	hud_root.visible = false
	result_root.visible = false
	story_root.visible = true
	story_label.text = String(STORY[0])


func _advance_story() -> void:
	story_index += 1
	if story_index >= STORY.size():
		story_root.visible = false
		start_game()
	else:
		story_label.text = String(STORY[story_index])


func _show_title() -> void:
	state = State.TITLE
	title_root.visible = true
	hud_root.visible = false
	result_root.visible = false
	if story_root:
		story_root.visible = false


func start_game(keep_progress := false) -> void:
	state = State.PLAY
	var kept_score := score
	var kept_upgrades := upgrade_levels.duplicate()
	var theme_idx: int = debug_theme if debug_theme >= 0 else selected_district
	city.rebuild(randi(), theme_idx)
	minimap.city = city
	title_root.visible = false
	story_root.visible = false
	hud_root.visible = true
	result_root.visible = false
	time_left = start_time
	score = 0.0
	combo = 0
	cold_deliveries = 0
	horns = 0
	was_honking = false
	pickup_at = 0.0
	best_leg = 0.0
	leg_mod = {}
	tips_total = 0.0
	stunt_total = 0.0
	drift_total = 0.0
	drift_boosts = 0
	best_drift = 0.0
	crash_total = 0.0
	air_bonuses = 0
	things_flattened = 0
	times_shot = 0
	times_punched = 0
	deaths = 0
	player_hp = max_hp()
	no_damage_time = 0.0
	ram_cooldown = 0.0
	punch_cooldown = 0.0
	punches_landed = 0
	player_hit_cooldown = 0.0
	rival_kills = 0
	car.mod_speed = 1.0
	car.mod_turn = 1.0
	car.jumped_once = false
	tutorial_step = -1
	tut_root.visible = false
	elapsed = 0.0
	was_cold = false
	special_order = false
	special_damage = 0
	special_done = 0
	goal_reached = false
	upgrade_levels = {}
	car.apply_upgrades(upgrade_levels)
	deliveries = 0
	crashes = 0
	bumps = 0
	cows_hit = 0
	top_speed = 0.0
	has_package = false
	_spawn_car()
	car.boost_fuel = 100.0
	day_t = 0.0

	# 배그 모드는 1일차 기본 구역이 아니라 2번째 구역 전용이다.
	var is_pubg: bool = theme_idx == City.PUBG_DISTRICT_INDEX and bool(city.theme.get("is_pubg", false))
	macho_active = theme_idx == City.MACHO_DISTRICT_INDEX and bool(city.theme.get("is_macho", false))
	bluezone_active = is_pubg
	car.set_pubg_mode(is_pubg)
	_apply_cam_mode()
	car.set_fists(macho_active)
	supplies_taken = 0
	cam_switched = false
	_set_aiming(false)
	if is_pubg:
		_setup_bluezone()
		_zone_reset()
		bluezone_mesh.visible = true
	elif bluezone_mesh:
		bluezone_mesh.visible = false

	# 경쟁사 배달차 스폰.
	# 배그 전장은 사격 대상, 마초 트럭장은 주먹 마짱 상대가 필요하다.
	# 파스텔 지구는 평화 구역이라 적 차량이 아예 없다.
	for r in rivals:
		if is_instance_valid(r):
			r.queue_free()
	rivals.clear()
	for md in money_drops:
		if is_instance_valid(md):
			md.queue_free()
	money_drops.clear()

	var rival_count := 0
	if macho_active:
		rival_count = macho_target_count()
	elif can_shoot():
		rival_count = rival_target_count()
	for k in rival_count:
		_spawn_rival()

	minimap.rivals = rivals
	minimap.money_drops = money_drops
	minimap.is_pubg = is_pubg
	minimap.bluezone_center = bluezone_center
	minimap.bluezone_radius = bluezone_radius
	minimap.next_center = zone_next_center
	minimap.next_radius = zone_next_radius if is_pubg else 0.0

	if keep_progress:
		# 구역 이동은 '새 날' 이 아니다. 번 돈과 개조는 그대로 가져간다.
		score = kept_score
		upgrade_levels = kept_upgrades
		car.apply_upgrades(upgrade_levels)
		player_hp = max_hp()
	_new_target(true)
	var pay_mult_str: String = " (보수 %.1f배)" % float(city.theme.get("pay_mult", 1.0)) if float(city.theme.get("pay_mult", 1.0)) != 1.0 else ""
	_toast("오늘의 구역: %s%s" % [String(city.theme["name"]), pay_mult_str])
	if macho_active:
		_toast("마초 트럭장 개장! 트럭들이 서로 마짱까고 돈다발을 떨굽니다")
	if botplay or debug_events:
		print("[event] 새 판 — 구역: %s / 교차로 %d개 / 섬 %d개" % [String(city.theme["name"]), city.intersections.size(), city.islands.size()])
	if not tutorial_done:
		start_tutorial()


func _on_rival_destroyed(pos: Vector3, reward: float) -> void:
	rival_kills += 1
	_shake(0.55, true)
	if macho_active:
		_toast("마초 트럭 KO! 승부수당이 도로에 떨어졌습니다")
		_pop("마짱 승부수당! +%s원" % _won(reward), Color(1.0, 0.65, 0.15))
	else:
		_toast(_line(rival_kill_lines))
		_pop("경쟁사 격파! +%s원" % _won(reward), Color(1.0, 0.35, 0.45))

	var md := MoneyDrop.new()
	md.amount = reward
	# global_position 은 트리에 들어간 뒤에 설정해야 한다.
	# 먼저 주면 조용히 무시돼서 돈다발이 전부 원점(0,0,0)에 떨어진다.
	add_child(md)
	md.global_position = pos
	md.collected.connect(_on_money_collected)
	money_drops.append(md)
	_check_achievements()
	# 한 대 처리할 때마다 한 대씩 다시 채운다. 판이 끝날 때까지 수가 유지된다.
	_spawn_rival()


func _on_money_collected(amount: float) -> void:
	score += amount
	career_earnings += amount
	_toast("현금 번들 수거 +%s원" % _won(amount))
	_pop("+%s원" % _won(amount), Color(0.3, 1.0, 0.5))
	_check_district_unlocks()
	_save()


func _spawn_rival() -> void:
	# 마초 트럭장은 주먹 마짱 상대, 배그 전장은 사격 대상으로 스폰한다.
	# 위치는 플레이어에서 멀리 잡는다 — 눈앞에서 갑툭튀하면 어색하다.
	rivals.append(_make_rival())


func _make_rival() -> RivalCar:
	var r_car := RivalCar.new()
	add_child(r_car)
	r_car.setup(city, city.spawn_spot(car.global_position, live_rival_positions()))
	r_car.set_macho_mode(macho_active)
	r_car.gun_enabled = can_shoot()
	r_car.punched_player.connect(_on_punched)
	r_car.destroyed.connect(_on_rival_destroyed)
	return r_car


func live_rival_positions() -> Array:
	# 지면 아래로 꺼진 트럭은 자리 계산에서 뺀다. 어차피 곧 되돌릴 것이다.
	var out: Array = []
	for r in rivals:
		if is_instance_valid(r) and r.alive and r.global_position.y > -5.0:
			out.append(r.global_position)
	return out


func rival_target_count() -> int:
	return 4


func macho_target_count() -> int:
	return 4


func _tick_macho_targets() -> void:
	# 마초 트럭장은 트럭끼리가 아니라 전부 플레이어를 노린다.
	for r in rivals:
		if not is_instance_valid(r) or not r.alive:
			continue
		r.brawl_target = car
		r.target_is_player = true


func hp_active() -> bool:
	# 체력은 싸우는 구역에서만 쓴다. 평화 구역은 예전 그대로.
	return macho_active or can_shoot()


func _hurt(amount: float, reason: String) -> void:
	if not hp_active() or state != State.PLAY:
		return
	no_damage_time = 0.0
	player_hp -= amount
	if player_hp <= 0.0:
		_player_down(reason)


func _player_down(_reason: String) -> void:
	deaths += 1
	player_hp = max_hp()
	no_damage_time = 0.0
	var loss := roundf(maxf(0.0, score * DEATH_MONEY_LOSS))
	score = maxf(0.0, score - loss)
	_pop("차량 대파  -%s원" % _won(loss), Color(1.0, 0.3, 0.3))
	_toast(_line(death_lines))
	_shake(1.2, true)
	player_hit_cooldown = 1.5
	# 자기장 안쪽 안전한 곳에서 다시 시작
	if bluezone_active:
		car.reset_to(city.point_near(bluezone_center, bluezone_radius * 0.55))
	else:
		_spawn_car()
	car.boost_fuel = 100.0


func _tick_player_hp(delta: float) -> void:
	if not hp_active():
		return
	no_damage_time += delta
	player_hp = minf(player_hp, max_hp())
	var in_safe := true
	if bluezone_active:
		var d := Vector2(car.global_position.x, car.global_position.z).distance_to(
			Vector2(bluezone_center.x, bluezone_center.z))
		in_safe = d <= bluezone_radius
	# 안전구역(또는 마초 구역에서 3초간 안 맞았으면) 회복
	if in_safe and (bluezone_active or no_damage_time > 3.0):
		player_hp = minf(max_hp(), player_hp + HP_REGEN * delta)


func _on_punched(from: Node3D) -> void:
	if state != State.PLAY or player_hit_cooldown > 0.0:
		return
	player_hit_cooldown = 0.95
	times_punched += 1
	time_left = maxf(TIME_FLOOR, time_left - 1.2)
	_hurt(PUNCH_DAMAGE, "주먹")
	# 주먹 맞으면 밀려난다
	var away := car.global_position - from.global_position
	away.y = 0.0
	if away.length() > 0.01:
		away = away.normalized()
		car.velocity += away * 16.0
		car.velocity.y = maxf(car.velocity.y, 6.0)
		car.airborne = true
	car.speed *= 0.55
	_shake(0.7, true)
	_toast(_line(punch_lines))


func can_punch() -> bool:
	# 배그 전장은 총만 쓴다. 주먹은 마초 트럭장 전용.
	return macho_active and state == State.PLAY


func _try_punch() -> void:
	if not can_punch() or punch_cooldown > 0.0:
		return
	punch_cooldown = 0.55
	car.punch_anim()
	var fwd := -car.global_transform.basis.z
	var best: RivalCar = null
	var best_d := INF
	for r in rivals:
		if not is_instance_valid(r) or not r.alive:
			continue
		var to_r := r.global_position - car.global_position
		to_r.y = 0.0
		var d := to_r.length()
		if d > 8.0 or d < 0.01:
			continue
		if fwd.dot(to_r.normalized()) < 0.35:   # 앞쪽만
			continue
		if d < best_d:
			best_d = d
			best = r
	if best == null:
		if randf() < 0.4:
			_toast(_line(whiff_lines))
		return
	punches_landed += 1
	best.take_damage(2)
	var away := best.global_position - car.global_position
	away.y = 0.0
	if away.length() > 0.01 and is_instance_valid(best):
		best.velocity += away.normalized() * 22.0
	_shake(0.4, true)
	_toast(_line(my_punch_lines))


func _tick_player_ram(delta: float) -> void:
	# 마초 트럭은 총이 아니라 박아서 잡는다
	if not macho_active:
		return
	ram_cooldown = maxf(0.0, ram_cooldown - delta)
	if ram_cooldown > 0.0 or absf(car.speed) < 16.0:
		return
	for r in rivals:
		if not is_instance_valid(r) or not r.alive:
			continue
		if r.global_position.distance_to(car.global_position) > 6.2:
			continue
		ram_cooldown = 0.5
		var dmg: int = 3 if absf(car.speed) > 30.0 else 2
		r.take_damage(dmg)
		var back := car.global_position - r.global_position
		back.y = 0.0
		if back.length() > 0.01:
			car.velocity += back.normalized() * 8.0
		car.speed *= 0.6
		_shake(0.5, true)
		_toast(_line(ram_lines))
		return


func _spawn_car() -> void:
	var p := city.random_point()
	car.reset_to(p)
	var d := Vector3.ZERO - p
	d.y = 0.0
	if d.length() > 1.0:
		car.look_at(car.global_position + d.normalized(), Vector3.UP)


func _grab_supply(grant: float) -> float:
	# 배그 구역에서는 음식을 집을 때 보급 상자도 같이 뜯는다.
	supplies_taken += 1
	var roll := randi() % 6
	var sup_name := ""
	var line := ""
	match roll:
		0:
			sup_name = "3단계 방탄모"
			line = "머리에 뭘 쓴 건지 모르겠지만 체력이 꽉 찼습니다"
			player_hp = max_hp()
		1:
			sup_name = "8배율 스코프"
			line = "배달 주소가 선명하게 보입니다. 제한시간 +18초"
			time_left += 18.0
			grant += 18.0
		2:
			sup_name = "부스터 연료캔"
			line = "연료통에 부었습니다. 아마 경유였을 겁니다"
			car.boost_fuel = 100.0
		3:
			sup_name = "진통제"
			line = "아픈 건 똑같은데 안 아픈 것 같습니다"
			player_hp = minf(max_hp(), player_hp + 55.0)
		4:
			sup_name = "현금 다발"
			line = "보급품에 웬 현금. 안 물어보겠습니다"
			var cash := 18000.0 * float(city.theme.get("pay_mult", 1.0))
			score += roundf(cash)
			_pop("보급 현금 +%s원" % _won(roundf(cash)), Color(1.0, 0.85, 0.2))
		_:
			sup_name = "치킨"
			line = "보급 상자에서 치킨이. 이거 배달하면 안 됩니까"
			player_hp = minf(max_hp(), player_hp + 30.0)
			time_left += 9.0
			grant += 9.0
	if roll != 4:
		_pop("보급 획득: %s" % sup_name, Color(1.0, 0.6, 0.15))
	_toast("보급 상자 개봉 — %s. %s" % [sup_name, line])
	_shake(0.2)
	if botplay or debug_events:
		print("[event] 보급 %d개째: %s / 체력 %.0f / 제한 %.1f" % [supplies_taken, sup_name, player_hp, time_left])
	return grant


func _set_marker_special(on: bool) -> void:
	var gold := Color(0.25, 1.0, 0.45)
	var pm := marker_pillar.material_override as StandardMaterial3D
	var rm := marker_ring.material_override as StandardMaterial3D
	if pm:
		pm.albedo_color = Color(gold.r, gold.g, gold.b, 0.4) if on else Color(0.2, 1.0, 0.55, 0.32)
		pm.emission = gold if on else Color(0.2, 1.0, 0.55)
		pm.emission_energy_multiplier = 3.0 if on else 1.4
	if rm:
		rm.albedo_color = Color(0.08, 0.09, 0.12) if on else Color(1.0, 0.9, 0.2)
		rm.emission = gold if on else Color(1.0, 0.8, 0.1)
		rm.emission_energy_multiplier = 2.6 if on else 1.8


func _apply_leg_mod() -> void:
	if leg_mod.is_empty():
		car.mod_speed = 1.0
		car.mod_turn = 1.0
		car.mod_grip = 1.0
	else:
		car.mod_speed = float(leg_mod["speed"])
		car.mod_turn = float(leg_mod["turn"])
		car.mod_grip = float(leg_mod.get("grip", 1.0))


func _tip_line(_r: float) -> String:
	var pool := [
		"고객이 감동했습니다",
		"따뜻할 때 도착했습니다",
		"별 다섯 개 예약",
		"현금으로 주셨습니다",
		"리뷰에 사진까지 올린답니다",
	]
	return pool[randi() % pool.size()]


func _new_target(pickup: bool) -> float:
	var from := car.global_position
	var min_d: float = 90.0 if pickup else 130.0
	if bluezone_active:
		# 배그 구역에서는 픽업도 고객도 자기장 안에만 잡힌다.
		# 기준은 '다음 원'. 다음 원은 현재 원 안쪽이므로 지금도 안전하고, 수축이 끝나도 안전하다.
		var r: float = maxf(ZONE_MIN_RADIUS * 0.8, zone_next_radius * 0.85)
		# 지금 원 안에도 들어가야 한다. 막판에 원이 제자리걸음 대신 조금씩 떠돌기 때문에
		# 다음 원이 현재 원을 완전히 벗어날 수 있다.
		target_pos = city.point_in_circle(zone_next_center, r, from, minf(min_d, r * 1.05),
			bluezone_center, bluezone_radius * 0.92)
	else:
		target_pos = city.point_far_from(from, min_d)
	if special_order and not pickup:
		lbl_task.text = "RTX 5090 배송 중  ·  파손 주의"
		lbl_task.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5))
	elif not pickup and not leg_mod.is_empty():
		lbl_task.text = "%s  ·  %s" % [String(leg_mod["name"]), String(leg_mod["note"])]
		lbl_task.add_theme_color_override("font_color", Color(1.0, 0.55, 0.85))
	else:
		lbl_task.text = "픽업 지점으로" if pickup else "고객에게 배달"
		lbl_task.add_theme_color_override("font_color",
			Color(0.6, 1.0, 0.7) if pickup else Color(1.0, 0.75, 0.4))
	if pickup and (deliveries + 1) % SPECIAL_EVERY == 0:
		lbl_task.text = "픽업 지점으로  ·  다음은 RTX 5090"
		lbl_task.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5))
	marker.global_position = target_pos
	if supply_crate:
		# 보급 상자는 '픽업 지점' 에만 놓인다. 고객 집 앞에 보급이 떨어질 리는 없다.
		supply_crate.visible = bluezone_active and pickup
	# 기본 1분. 거리와 무관하고 누적되지 않되, 배달이 쌓일수록 조금씩 줄어든다.
	var grant: float = maxf(LEG_TIME_MIN, leg_time - deliveries * LEG_DECAY) + float(upgrade_levels.get("warm", 0)) * 6.0
	if not pickup and not leg_mod.is_empty():
		grant *= float(leg_mod["time"])
	leg_grant = grant
	if botplay or debug_events:
		var road_d: float = absf(target_pos.x - from.x) + absf(target_pos.z - from.z)
		print("[event] 새 구간: 주행거리 %.0f / 제한 %.1f초" % [road_d, grant])
	time_left = grant
	return grant


func _end_game() -> void:
	state = State.RESULT
	hud_root.visible = false
	result_root.visible = true

	var stars := 0
	var comment := ""
	if goal_reached:
		result_title.text = "1일차 종료"
		# 10만원을 얼마나 빨리 채웠는가로 평가
		if elapsed < 240.0: stars = 5
		elif elapsed < 330.0: stars = 4
		elif elapsed < 430.0: stars = 3
		elif elapsed < 560.0: stars = 2
		else: stars = 1
		match stars:
			1: comment = "퇴근은 했습니다. 해는 졌지만"
			2: comment = "오늘 하루 무사히 넘겼습니다"
			3: comment = "이번 달 우수사원 후보"
			4: comment = "지점장이 스카우트하려 합니다"
			_: comment = "배달의 신. 국물도 안 샜습니다"
	else:
		result_title.text = "퇴근"
		var prog: float = score / GOAL
		if prog >= 0.75: stars = 4
		elif prog >= 0.5: stars = 3
		elif prog >= 0.25: stars = 2
		elif prog >= 0.05: stars = 1
		match stars:
			0: comment = "고객센터에서 연락이 갈 예정입니다"
			1: comment = "그래도 시동은 걸 줄 아네요"
			2: comment = "절반도 못 채우고 퇴근입니다"
			3: comment = "아깝습니다. 조금만 더 했으면"
			_: comment = "코앞에서 그만두셨습니다"

	# 별은 GTA 수배 레벨처럼 항상 만점. 평가는 문구로만 한다.
	result_rating.text = "★ ★ ★ ★ ★"
	result_comment.text = comment

	if score > best_score:
		best_score = score
		_save()
	if botplay:
		print("[test] 종료 | ★5 | %s | %s원 | %.0f초" % [comment, _won(score), elapsed])

	var got := 0
	for a in ACHIEVEMENTS:
		if achieved.get(a["key"], false):
			got += 1
	result_body.text = "\n".join([
		"수익 %s원      배달 %d건 (식은 배달 %d건)      %d분 %d초" % [
			_won(score), deliveries, cold_deliveries, int(elapsed) / 60, int(elapsed) % 60],
		"최고 기록 %s원      최고 속도 %d km/h      RTX 5090 배송 %d건" % [
			_won(best_score), int(top_speed), special_done],
		"대형사고 %d회      긁힘 %d회      소 %d마리      최단 배달 %.1f초" % [
			crashes, bumps, cows_hit, best_leg],
		"팁 %s원      스턴트 %s원      벽 수집 %s원" % [
			_won(tips_total), _won(stunt_total), _won(crash_total)],
		"드리프트 부스터 %d회      드리프트 수당 %s원      최장 드리프트 %.1f초" % [
			drift_boosts, _won(drift_total), best_drift],
		"쓰러뜨린 가로등·가로수 %d개      피격 %d회      주먹 %d대      날린 주먹 %d대" % [
			things_flattened, times_shot, times_punched, punches_landed],
		"대파 %d회      도전과제 %d/%d" % [deaths, got, ACHIEVEMENTS.size()],
	])


# ---------------------------------------------------------------- 루프

func _update_achievement_banner(delta: float) -> void:
	if ach_timer > 0.0:
		ach_timer -= delta
		var shown: float = 4.2 - ach_timer
		var slide_in: float = clampf(shown / 0.3, 0.0, 1.0)
		var slide_out: float = clampf(ach_timer / 0.45, 0.0, 1.0)
		var v: float = minf(slide_in, slide_out)
		ach_root.modulate.a = v
		ach_panel.position.x = (1.0 - v) * 120.0
		if ach_timer <= 0.0:
			ach_root.visible = false
	elif not ach_queue.is_empty():
		var a: Dictionary = ach_queue.pop_front()
		ach_name.text = String(a["name"])
		ach_desc.text = String(a["desc"])
		ach_root.visible = true
		ach_root.modulate.a = 0.0
		ach_panel.position.x = 120.0
		ach_timer = 4.2


func _process(delta: float) -> void:
	if cut_root != null and cut_root.visible:
		cut_timer -= delta
		if cut_timer <= 0.0:
			close_unlock_cutscene()
	_update_achievement_banner(delta)
	_update_daylight(delta)
	_update_camera(delta)
	marker_ring.rotate_y(delta * 2.4)
	marker_ring.position.y = 6.0 + sin(Time.get_ticks_msec() / 320.0) * 1.2

	if state == State.TITLE:
		var blink := title_root.find_child("Blink", true, false) as Label
		if blink:
			blink.modulate.a = 0.45 + 0.55 * absf(sin(Time.get_ticks_msec() / 420.0))
		return

	if state == State.MENU:
		return
	if state != State.PLAY:
		return

	elapsed += delta
	_tick_tutorial()
	if tutorial_step < 0:
		time_left = maxf(TIME_FLOOR, time_left - delta)
	top_speed = maxf(top_speed, car.kmh())
	shoot_cooldown = maxf(0.0, shoot_cooldown - delta)

	# 배그 자기장 처리
	if bluezone_active and bluezone_mesh:
		_tick_bluezone(delta)
	if supply_crate and supply_crate.visible:
		supply_crate.rotate_y(delta * 1.1)

	# 머니 드랍 수거 검사
	for i in range(money_drops.size() - 1, -1, -1):
		var md := money_drops[i]
		if is_instance_valid(md):
			md.check_pickup(car.global_position)
		else:
			money_drops.remove_at(i)

	# 경쟁사 목록 정리
	for i in range(rivals.size() - 1, -1, -1):
		if not is_instance_valid(rivals[i]) or not rivals[i].alive:
			rivals.remove_at(i)
	# 겹쳐 스폰된 트럭은 물리가 지면 아래로 밀어넣는다. 화면엔 없는데 레이더에만 남으므로
	# 도로 위 빈 자리로 되돌린다. 근본 원인은 City.spawn_spot 에서 막는다.
	for r in rivals:
		if is_instance_valid(r) and r.alive and r.global_position.y < -5.0:
			r.setup(city, city.spawn_spot(car.global_position, live_rival_positions()))
	if macho_active:
		_tick_macho_targets()

	# 시간이 지나도 게임은 안 끝난다. 음식만 식는다.
	if is_cold() and not was_cold:
		was_cold = true
		if botplay or debug_events:
			print("[event] 식음 진입 (has_package=%s)" % str(has_package))
		if has_package:
			_pop("음식 식음", Color(0.45, 0.9, 1.0))
			_toast(_line(cold_lines))
		else:
			_pop("지각", Color(0.45, 0.9, 1.0))
			_toast(_line(late_lines))
	elif not is_cold():
		was_cold = false

	if car.global_position.y < -25.0:
		_spawn_car()
		_toast("맵 밖으로 떨어짐. 견인차가 데려왔습니다")
		_shake(0.8, true)

	if botplay:
		var bd := target_pos - car.global_position
		var step := bot_speed * delta
		if absf(bd.x) > 1.0:
			car.global_position.x += clampf(bd.x, -step, step)
		elif absf(bd.z) > 1.0:
			car.global_position.z += clampf(bd.z, -step, step)
		car.global_position.y = 0.1

	var flat_car := Vector3(car.global_position.x, 0, car.global_position.z)
	var flat_target := Vector3(target_pos.x, 0, target_pos.z)
	var dist := flat_car.distance_to(flat_target)

	if dist < REACH_DIST:
		_reach_target(dist)

	horn_cooldown = maxf(0.0, horn_cooldown - delta)
	if car.honking and not was_honking:
		horns += 1
	was_honking = car.honking
	if car.honking and horn_cooldown <= 0.0:
		horn_cooldown = 4.5
		_toast(_line(horn_lines))

	_update_arrow(dist)
	_check_cows()
	_check_breakables()
	player_hit_cooldown = maxf(0.0, player_hit_cooldown - delta)
	punch_cooldown = maxf(0.0, punch_cooldown - delta)
	_tick_player_hp(delta)
	_tick_rival_guns(delta)
	_tick_player_ram(delta)
	_check_achievements()
	_update_hud(dist, delta)


func is_cold() -> bool:
	return time_left <= 0.0


func can_shoot() -> bool:
	# 사격은 배그 전장에서만 허용된다.
	# 파스텔 지구는 평화 구역, 마초 트럭장은 주먹 마짱 구역이라 총이 나가지 않는다.
	return bool(city.theme.get("is_pubg", false))


func _reach_target(_dist: float) -> void:
	if not has_package:
		has_package = true
		pickup_at = elapsed
		special_order = ((deliveries + 1) % SPECIAL_EVERY == 0)
		special_damage = 0
		car.set_cargo_special(special_order)
		_set_marker_special(special_order)
		leg_mod = {}
		if not special_order and randf() < 0.34:
			leg_mod = ORDER_MODS[randi() % ORDER_MODS.size()]
		_apply_leg_mod()
		var g := _new_target(false)
		if bluezone_active:
			g = _grab_supply(g)
		if not leg_mod.is_empty():
			_toast(String(leg_mod["line"]))
		if special_order:
			_pop("RTX 5090 배송", Color(0.3, 1.0, 0.45))
			_toast(_line(rtx_pickup_lines) + "   (제한 %.0f초)" % g)
		else:
			_pop("픽업!", Color(0.5, 1.0, 0.6))
			_toast(_line(pickup_lines) + "   (제한 %.0f초)" % g)
	else:
		has_package = false
		deliveries += 1
		combo += 1
		var leg_secs: float = elapsed - pickup_at
		if best_leg <= 0.0 or leg_secs < best_leg:
			best_leg = leg_secs
		if leg_secs <= 10.0:
			_unlock("speedrun")
		var cold := is_cold()
		var district_mult: float = float(city.theme.get("pay_mult", 1.0))
		var pay_mult: float = (1.0 + float(upgrade_levels.get("pay", 0)) * 0.18) * district_mult
		var gain: float = 0.0
		if cold:
			gain = COLD_PAY
		elif special_order:
			gain = maxf(5000.0, SPECIAL_PAY - special_damage * SPECIAL_DAMAGE_COST * (1.0 - car.crash_shield))
			gain *= pay_mult
		else:
			gain = float(9000 + combo * 2200 + int(car.kmh()) * 45) * pay_mult
		if not cold and not leg_mod.is_empty():
			gain *= float(leg_mod["pay"])

		# 팁: 제한시간을 얼마나 남기고 왔는가
		var tip := 0.0
		if not cold and leg_grant > 0.0:
			var left_ratio: float = clampf(time_left / leg_grant, 0.0, 1.0)
			var tip_rate := 0.0
			if left_ratio >= 0.75: tip_rate = 0.30
			elif left_ratio >= 0.55: tip_rate = 0.18
			elif left_ratio >= 0.35: tip_rate = 0.08
			tip = roundf(gain * tip_rate)
			if tip > 0.0:
				tips_total += tip
				gain += tip
		if not cold:
			gain = roundf(gain)
		score += gain
		career_earnings += gain
		_check_district_unlocks()
		_save()
		if cold:
			cold_deliveries += 1
		if tip > 0.0:
			_toast("팁 +%s원  ·  %s" % [_won(tip), _tip_line(tip / maxf(gain, 1.0))])
		var mod_name: String = String(leg_mod["name"]) if not leg_mod.is_empty() else ""
		leg_mod = {}
		_apply_leg_mod()
		if botplay:
			print("[test] 배달 %d건 / 수익 %s원 / 연속 %d / 남은 %.1f/%.0f초 / 팁 %s%s%s%s" % [
				deliveries, _won(score), combo, time_left, leg_grant, _won(tip),
				"  (식음)" if cold else "", "  [RTX]" if special_order else "",
				"  <%s>" % mod_name if mod_name != "" else ""])
		if cold:
			_pop("식은 배달  +0.001원", Color(0.45, 0.9, 1.0))
			if special_order:
				_toast("GPU는 안 식는데 배송비는 식었습니다")
		elif special_order:
			special_done += 1
			if special_damage == 0:
				_unlock("perfect_rtx")
			elif special_damage >= 3:
				_unlock("brick")
			_pop("RTX 5090 배송 완료  +%s원" % _won(gain), Color(0.3, 1.0, 0.45))
			if special_damage == 0:
				_toast("무사히 도착했습니다. 놀랍습니다")
			else:
				_toast("고객이 박스를 흔들어 보고 있습니다")
		else:
			_pop("배달 완료  +%s원" % _won(gain), Color(1.0, 0.9, 0.3))
		special_order = false
		car.set_cargo_special(false)
		_set_marker_special(false)
		var g2 := _new_target(true)
		if not cold:
			_toast(_line(deliver_lines) + "   (제한 %.0f초)" % g2)
		if score >= GOAL and not goal_reached:
			goal_reached = true
			_end_game()


const SKY_PHASES := [
	# 낮
	{"top": Color(0.25, 0.55, 1.00), "hor": Color(1.00, 0.72, 0.55), "sun": Color(1.00, 0.95, 0.85),
	 "energy": 1.25, "ambient": 1.10, "angle": -46.0, "fog": Color(0.95, 0.72, 0.85),
	 "fogd": 0.0005, "glow": 0.55},
	# 노을
	{"top": Color(0.33, 0.32, 0.72), "hor": Color(1.00, 0.42, 0.22), "sun": Color(1.00, 0.58, 0.28),
	 "energy": 1.05, "ambient": 0.80, "angle": -12.0, "fog": Color(1.00, 0.50, 0.35),
	 "fogd": 0.0011, "glow": 0.85},
	# 밤
	{"top": Color(0.04, 0.05, 0.16), "hor": Color(0.16, 0.10, 0.34), "sun": Color(0.52, 0.58, 1.00),
	 "energy": 0.42, "ambient": 0.48, "angle": -62.0, "fog": Color(0.13, 0.10, 0.28),
	 "fogd": 0.0014, "glow": 1.45},
]


func _update_daylight(delta: float) -> void:
	if world_env == null:
		return
	if debug_day >= 0.0:
		day_t = debug_day
	else:
		var target: float = clampf(float(deliveries) / 16.0, 0.0, 1.0)
		day_t = move_toward(day_t, target, delta * 0.08)
	var seg: float = day_t * 2.0
	var i: int = 0 if seg < 1.0 else 1
	var f: float = clampf(seg - float(i), 0.0, 1.0)
	var a: Dictionary = SKY_PHASES[i]
	var b: Dictionary = SKY_PHASES[i + 1]

	world_sky.sky_top_color = Color(a["top"]).lerp(Color(b["top"]), f)
	world_sky.sky_horizon_color = Color(a["hor"]).lerp(Color(b["hor"]), f)
	world_sky.ground_horizon_color = world_sky.sky_horizon_color
	world_sun.light_color = Color(a["sun"]).lerp(Color(b["sun"]), f)
	world_sun.light_energy = lerpf(float(a["energy"]), float(b["energy"]), f)
	world_sun.rotation_degrees.x = lerpf(float(a["angle"]), float(b["angle"]), f)
	world_env.ambient_light_energy = lerpf(float(a["ambient"]), float(b["ambient"]), f)
	world_env.fog_light_color = Color(a["fog"]).lerp(Color(b["fog"]), f)
	world_env.fog_density = lerpf(float(a["fogd"]), float(b["fogd"]), f)
	world_env.glow_intensity = lerpf(float(a["glow"]), float(b["glow"]), f)
	# 창문 불빛은 해가 질수록 켜진다
	city.set_night(day_t)


func _is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _shake(amount: float, big := false) -> void:
	# 전체화면에서는 큰 충돌만 흔든다. 창모드는 전부 그대로.
	if _is_fullscreen() and not big:
		return
	shake = maxf(shake, amount)


func cycle_camera() -> void:
	cam_switched = true
	cam_mode = (cam_mode + 1) % CamMode.size()
	_apply_cam_mode()
	_toast("시점: %s — %s" % [CAM_NAMES[cam_mode], CAM_LINES[cam_mode]])
	_pop("시점 %s" % CAM_NAMES[cam_mode], Color(0.6, 0.9, 1.0))
	_save()


func _apply_cam_mode() -> void:
	# 1인칭 계열에서만 차체를 숨긴다. 본넷은 차체가 화면을 절반 잡아먹는다.
	car.set_body_visible(cam_mode != CamMode.FIRST and cam_mode != CamMode.HOOD)
	# 핸들·계기판은 운전석에서만 나온다. 본넷은 차 밖이라 보일 리가 없다.
	car.set_cockpit_visible(cam_mode == CamMode.FIRST)
	if trip_rect:
		trip_rect.visible = cam_mode == CamMode.TRIP
		trip_rect2.visible = cam_mode == CamMode.TRIP
		if cam_mode != CamMode.TRIP:
			cam.fov = 70.0


func _update_camera(delta: float) -> void:
	if trip_rect:
		# 메뉴·결과 화면까지 무지개가 덮으면 글자를 못 읽는다.
		var trip_on: bool = cam_mode == CamMode.TRIP and state == State.PLAY
		trip_rect.visible = trip_on
		trip_rect2.visible = trip_on
	# 조준은 카메라 모드와 무관하게 매 프레임 갱신한다.
	# 아래 분기들이 중간에 return 하므로 여기서 처리하지 않으면 경통이 화면에 남는다.
	var want_aim: bool = (aiming and state == State.PLAY and can_shoot()
		and cam_mode != CamMode.TRIP)
	aim_t = move_toward(aim_t, 1.0 if want_aim else 0.0, delta * 5.0)
	_update_scope(delta)
	if debug_freecam:
		return
	if state == State.TITLE or state == State.STORY:
		var t := Time.get_ticks_msec() / 1000.0
		var pivot := Vector3(car.global_position.x, 6.0, car.global_position.z)
		cam.global_position = pivot + Vector3(sin(t * 0.16) * 118.0, 74.0, cos(t * 0.16) * 118.0)
		cam.look_at(pivot)
		cam.fov = 62.0
		return
	var back := car.global_transform.basis.z
	var right := car.global_transform.basis.x
	var fwd := -back
	# 시점마다 카메라 위치 / 바라보는 곳 / 따라붙는 속도가 다르다.
	var desired: Vector3
	var look_at: Vector3
	var follow := 5.5
	match cam_mode:
		CamMode.HOOD:
			desired = car.global_position + fwd * 2.2 + Vector3.UP * 2.0
			look_at = car.global_position + fwd * 26.0 + Vector3.UP * 2.0
			follow = 22.0
		CamMode.FIRST:
			desired = car.global_position + fwd * 0.2 + Vector3.UP * 2.4
			look_at = car.global_position + fwd * 26.0 + Vector3.UP * 2.4
			follow = 22.0
		CamMode.TOP:
			desired = car.global_position + Vector3.UP * 30.0 + back * 6.0
			look_at = car.global_position
			follow = 7.0
		CamMode.SIDE:
			desired = car.global_position + right * 14.0 + Vector3.UP * 4.0 + back * 2.0
			look_at = car.global_position + Vector3.UP * 1.4
			follow = 4.0
		CamMode.TRIP:
			# 차 주위를 제멋대로 도는 궤도. 궤도 속도까지 출렁여서 멀미가 나게 만든다.
			trip_t += delta
			var ang: float = trip_t * 2.3 + sin(trip_t * 0.47) * 2.6
			var rad: float = 9.5 + sin(trip_t * 1.21) * 6.5
			# 가끔 지면 아래까지 내려가서 차를 올려다본다
			var hgt: float = 4.2 + sin(trip_t * 1.73) * 5.6
			desired = car.global_position + Vector3(cos(ang) * rad, hgt, sin(ang) * rad)
			# 바라보는 곳도 흔든다. 차가 화면 가운데 가만히 있으면 안 어지럽다.
			look_at = car.global_position + Vector3(
				sin(trip_t * 2.9) * 2.4, 1.6 + sin(trip_t * 3.7) * 1.6, cos(trip_t * 3.3) * 2.4)
			follow = 60.0
		_:
			desired = car.global_position + back * 13.5 + Vector3.UP * 6.2
			look_at = car.global_position + Vector3.UP * 2.2
	# 조준하면 배그처럼 운전석 1인칭으로 들어간다.
	# 3인칭에서 시야각만 좁히면 화면 절반을 자기 차 뒤통수가 차지한다.
	if aim_t > 0.001:
		var eye: Vector3 = car.global_position + fwd * 0.2 + Vector3.UP * 2.4
		desired = desired.lerp(eye, aim_t)
		look_at = look_at.lerp(eye + aim_dir() * 120.0, aim_t)
		follow = lerpf(follow, 26.0, aim_t)
	cam_pos = cam_pos.lerp(desired, clampf(delta * follow, 0.0, 1.0))
	var sh := Vector3.ZERO
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.4)
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake
	cam.global_position = cam_pos + sh
	# 탑뷰는 바로 위에서 내려다봐서 기본 up 벡터와 시선이 평행해진다. 옆으로 누우므로
	# 차 뒤쪽을 up 으로 준다.
	if cam_mode == CamMode.TOP:
		cam.look_at(look_at, -back)
	else:
		cam.look_at(look_at)
	if cam_mode == CamMode.TRIP:
		# look_at 이 롤을 0 으로 되돌리므로 그 뒤에 직접 기울인다.
		# 주기를 둘 겹쳐서 가끔 화면이 통째로 뒤집힌다.
		var roll: float = sin(trip_t * 1.05) * 1.7 + sin(trip_t * 0.33) * 1.5
		cam.rotate_object_local(Vector3.FORWARD, roll)
		cam.fov = 88.0 + sin(trip_t * 3.4) * 38.0 + sin(trip_t * 0.9) * 12.0
		cam.fov = clampf(cam.fov, 26.0, 150.0)
		# 무지개 띠 두 겹. 가로로 흐르는 띠 + 세로로 흐르는 띠가 겹쳐 격자로 일렁인다.
		var vp := get_viewport().get_visible_rect().size
		trip_rect.size = Vector2(vp.x * 2.0, vp.y)
		trip_rect.position = Vector2(-fmod(trip_t * 520.0, vp.x), 0.0)
		trip_rect.modulate.a = 0.28 + 0.14 * absf(sin(trip_t * 3.1))
		trip_rect2.size = Vector2(vp.x, vp.y * 2.0)
		trip_rect2.position = Vector2(0.0, -fmod(trip_t * 360.0, vp.y))
		trip_rect2.modulate.a = 0.17 + 0.12 * absf(sin(trip_t * 2.3 + 1.0))
		return
	var sp: float = clampf(car.kmh() / 560.0, 0.0, 1.0)
	# lerp 가중치는 1 을 넘으면 발산한다. turbo 로 delta 가 커지면 fov 가 음수까지 튀어서
	# Camera3D 가 "p_fov < 1" 에러를 뿜는다. 반드시 clamp 한다.
	# 부스터를 켜면 시야각을 더 벌려서 속도감을 준다
	var fov_target: float = 70.0 + sp * 26.0
	if car.boosting:
		fov_target += 12.0
	# 조준 중에는 속도·부스터 시야각을 무시하고 확 당긴다
	if aim_t > 0.001:
		fov_target = lerpf(fov_target, AIM_FOV, aim_t)
	cam.fov = lerpf(cam.fov, fov_target, clampf(delta * (6.0 if car.boosting else 4.0), 0.0, 1.0))


func aim_dir() -> Vector3:
	# 차 방향 + 마우스로 돌린 각. 화면 한가운데가 곧 총구 방향이 된다.
	var yaw: float = car.global_rotation.y + aim_yaw
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, aim_pitch)
	return -b.z


func _set_aiming(on: bool) -> void:
	if on == aiming:
		return
	aiming = on
	if on:
		aim_yaw = 0.0
		aim_pitch = 0.0
		# 마우스를 가둬야 화면 밖으로 새지 않고 상대 이동만 들어온다.
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _update_scope(delta: float) -> void:
	if scope == null:
		return
	scope.visible = aim_t > 0.02
	# 운전석에 들어앉은 셈이므로 차체도 핸들도 시야를 막으면 안 된다.
	# 경통이 사라진 뒤에도 한 번은 돌려놔야 하므로 early return 앞에서 처리한다.
	if aim_t > 0.5:
		car.set_body_visible(false)
		car.set_cockpit_visible(false)
	elif _aim_hid_body:
		_apply_cam_mode()
	_aim_hid_body = aim_t > 0.5
	if not scope.visible:
		return
	var vp := get_viewport().get_visible_rect().size
	scope.size = vp
	# 1인칭 조준이라 경통은 화면 한가운데 고정이다. 총구도 그쪽을 본다.
	scope.center = vp * 0.5
	# 레드닷은 시야를 안 가린다. 창만 작고 바깥은 그대로 보인다.
	scope.radius = vp.y * 0.24
	scope.on = aim_t
	scope.zoom = 70.0 / maxf(1.0, cam.fov)
	scope.sway += delta * 2.2
	scope.queue_redraw()


func _update_arrow(dist: float) -> void:
	arrow.global_position = car.global_position + Vector3.UP * 7.4
	var dir := (target_pos - car.global_position)
	dir.y = 0
	if dir.length() > 0.5:
		arrow.look_at(arrow.global_position + dir.normalized(), Vector3.UP)
	arrow.visible = dist > 12.0


func _tick_rival_guns(delta: float) -> void:
	if not can_shoot() or is_cold():
		return
	var space := get_world_3d().direct_space_state
	var player_aim := car.global_position + Vector3(0, 1.2, 0)
	for r in rivals:
		if not is_instance_valid(r) or not r.alive:
			continue
		r.gun_cooldown -= delta
		if r.gun_cooldown > 0.0:
			continue
		var muzzle := r.gun_muzzle()
		var dist := muzzle.distance_to(player_aim)
		if dist > 110.0:
			continue
		# 건물 너머로는 안 쏜다
		var q := PhysicsRayQueryParameters3D.create(muzzle, player_aim)
		q.exclude = _rival_rids()
		var res := space.intersect_ray(q)
		if res.size() > 0 and (res.get("collider") as Object) != car:
			continue
		r.gun_cooldown = randf_range(1.1, 2.2)
		_rival_fire(r, player_aim, dist)


func _rival_rids() -> Array[RID]:
	var out: Array[RID] = []
	for r in rivals:
		if is_instance_valid(r):
			out.append(r.get_rid())
	return out


func _rival_fire(r: RivalCar, aim: Vector3, dist: float) -> void:
	var muzzle := r.gun_muzzle()
	var dir := (aim - muzzle).normalized()
	# 애임이 형편없다. 거리가 멀수록 더 흔들린다.
	var spread: float = lerpf(0.12, 0.26, clampf(dist / 110.0, 0.0, 1.0))
	dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
	var side := dir.cross(Vector3.UP)
	if side.length() > 0.01:
		dir = dir.rotated(side.normalized(), randf_range(-spread * 0.45, spread * 0.45))
	var b := Bullet.new()
	b.hostile = true
	b.player_rid = car.get_rid()
	b.ignore = _rival_rids()   # 자기들끼리는 안 맞는다
	b.hit_player.connect(_on_player_shot)
	add_child(b)
	b.setup(muzzle, dir.normalized())


func _on_player_shot() -> void:
	if player_hit_cooldown > 0.0 or state != State.PLAY:
		return
	player_hit_cooldown = 0.7
	times_shot += 1
	# 대형사고(-1.5초)보다는 가볍게. 총알은 자주 날아온다.
	time_left = maxf(TIME_FLOOR, time_left - 1.0)
	_hurt(GUN_DAMAGE, "총")
	car.speed *= 0.88
	_shake(0.45, true)
	_toast(_line(shot_lines))


func _check_breakables() -> void:
	# 물체가 수백 개라 전부 거리 검사하면 낭비다. 물리 쿼리 한 번으로 끝낸다.
	if _break_query == null:
		_break_shape = BoxShape3D.new()
		_break_shape.size = Vector3(3.2, 2.6, 5.4)
		_break_query = PhysicsShapeQueryParameters3D.new()
		_break_query.shape = _break_shape
		_break_query.collision_mask = City.BREAKABLE_LAYER
	_break_query.transform = car.global_transform.translated_local(Vector3(0, 1.0, 0))
	var space := get_world_3d().direct_space_state
	for hit in space.intersect_shape(_break_query, 6):
		var body: Object = hit.get("collider")
		if body == null:
			continue
		var root := (body as Node).get_parent() as Node3D
		if root == null or root.has_meta("fallen"):
			continue
		_topple(root, body as Node)


func _topple(root: Node3D, body: Node) -> void:
	root.set_meta("fallen", true)
	things_flattened += 1
	body.queue_free()   # 쓰러진 뒤에는 총알도 통과
	var away := root.global_position - car.global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = -car.global_transform.basis.z
	away = away.normalized()
	# 밀려난 방향으로 눕힌다
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "rotation",
		root.rotation + Vector3(away.z, 0.0, -away.x) * deg_to_rad(88.0), 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(root, "position",
		root.position + away * 0.8, 0.45).set_ease(Tween.EASE_OUT)


func _check_cows() -> void:
	near_cooldown = maxf(0.0, near_cooldown - get_process_delta_time())
	for c in city.cows:
		if not is_instance_valid(c) or c.get_meta("hit", false):
			continue
		var d_near := c.global_position.distance_to(car.global_position)
		if d_near < 7.5 and d_near >= 4.6 and absf(car.speed) > 26.0 and near_cooldown <= 0.0:
			near_cooldown = 1.6
			_stunt(1400.0, "아슬아슬")
		if d_near < 4.2 and absf(car.speed) > 8.0:
			c.set_meta("hit", true)
			cows_hit += 1
			var away := (c.global_position - car.global_position).normalized()
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(c, "position",
				c.position + away * 26.0 + Vector3.UP * 22.0, 0.9).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "rotation",
				c.rotation + Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)), 0.9)
			tw.chain().tween_property(c, "position",
				c.position + away * 40.0 + Vector3.DOWN * 30.0, 1.1).set_ease(Tween.EASE_IN)
			_shake(0.5)
			# 소는 대사, 고깔콘은 조용히 날아가기만 한다
			if c.get_child_count() > 2:
				_toast(_line(cow_lines))


func _update_hud(dist: float, delta: float) -> void:
	var f: float = absf(sin(Time.get_ticks_msec() / 110.0))
	if is_cold():
		lbl_time.text = "%.1f" % time_left
		lbl_time.add_theme_color_override("font_color", Color(0.4, 0.8 + f * 0.2, 1.0))
		lbl_time.scale = Vector2.ONE
		lbl_task.text = "음식이 식는 중"
		lbl_task.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	else:
		# 0.04초를 "0.0"으로 내림하면 아직 안 식었는데 식은 줄 안다. 올림해서 0.1로 보여준다.
		lbl_time.text = "%.1f" % (ceilf(time_left * 10.0) / 10.0)
		if time_left < 8.0:
			lbl_time.add_theme_color_override("font_color", Color(1.0, 0.25 + f * 0.5, 0.25))
			lbl_time.scale = Vector2.ONE * (1.0 + f * 0.06)
		else:
			lbl_time.add_theme_color_override("font_color", Color.WHITE)
			lbl_time.scale = Vector2.ONE
	lbl_score.text = "%s 원" % _won(score)
	goal_bar.size.x = 300.0 * clampf(score / GOAL, 0.0, 1.0)
	lbl_goal.text = "남은 금액 %s원" % _won(maxf(0.0, GOAL - score))
	lbl_combo.text = "연속 %d      배달 %d건" % [combo, deliveries]
	lbl_speed.text = "%d km/h" % int(car.kmh())
	lbl_dist.text = "%d m" % int(dist)
	minimap.target = target_pos
	minimap.has_pkg = has_package
	minimap.cold = is_cold()
	var show_hp := hp_active()
	hp_bg.visible = show_hp
	hp_label.visible = show_hp
	if show_hp:
		var ratio: float = clampf(player_hp / max_hp(), 0.0, 1.0)
		hp_bar.size.x = 230.0 * ratio
		hp_bar.color = Color(1.0, 0.35, 0.35) if ratio > 0.3 else Color(1.0, 0.75, 0.2)
		hp_label.text = "체력 %d" % int(ceilf(player_hp))
		if ratio <= 0.3:
			var f2: float = absf(sin(Time.get_ticks_msec() / 130.0))
			hp_label.add_theme_color_override("font_color", Color(1.0, 0.4 + f2 * 0.5, 0.3))
		else:
			hp_label.add_theme_color_override("font_color", Color(1, 0.75, 0.75))
	boost_bar.size.x = 230.0 * (car.boost_fuel / 100.0)
	boost_bar.color = Color(1.0, 0.85, 0.1) if not car.boosting else Color(0.3, 1.0, 1.0)

	var show_drift: bool = car.drifting or car.drift_boost_time > 0.0
	drift_bg.visible = show_drift
	drift_label.visible = show_drift
	if show_drift:
		var tier: int = car.drift_tier_of(car.drift_charge)
		drift_bar.size.x = 230.0 * (car.drift_charge / Car.DRIFT_CHARGE_MAX)
		drift_bar.color = car.drift_color(tier)
		if car.drift_boost_time > 0.0:
			drift_label.text = "드리프트 부스터 %.1f초" % car.drift_boost_time
			drift_bar.size.x = 230.0 * (car.drift_boost_time / 2.9)
			drift_bar.color = Color(1.0, 0.95, 0.4)
		else:
			var names := ["충전 중", "미니 터보", "슈퍼 터보", "울트라 터보"]
			drift_label.text = "드리프트 · %s  (%.0f도)" % [names[tier], car.slide_angle()]

	if crosshair and aim_t > 0.35:
		crosshair.visible = false
	elif crosshair:
		# 사격 가능한 구역에서만 조준선을 보여준다.
		crosshair.visible = (state == State.PLAY and can_shoot())
		crosshair.global_position = get_viewport().get_mouse_position() - crosshair.size * 0.5

	for i in toast_slots.size():
		toast_ages[i] += delta
		var fade: float = clampf(3.4 - toast_ages[i], 0.0, 1.0)
		toast_slots[i].modulate.a = fade * (0.5 if i < 2 else 1.0)
	if pop_timer > 0.0:
		pop_timer -= delta
		var t: float = clampf(pop_timer / 1.1, 0.0, 1.0)
		lbl_pop.modulate.a = t
		lbl_pop.scale = Vector2.ONE * (1.25 - t * 0.25)
	else:
		lbl_pop.text = ""


func _comma(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


func _won(v: float) -> String:
	# 0.001원 단위가 섞이므로 소수부가 있을 때만 보여준다
	if absf(v - roundf(v)) < 0.0005:
		return _comma(int(roundf(v)))
	var whole := int(floorf(v))
	return _comma(whole) + ("%.3f" % (v - float(whole))).substr(1)


func _toast(msg: String) -> void:
	# 새 대사는 맨 아래, 이전 대사는 위로 밀리며 흐려진다
	for i in range(0, toast_slots.size() - 1):
		toast_slots[i].text = toast_slots[i + 1].text
		toast_ages[i] = toast_ages[i + 1]
	toast_slots[toast_slots.size() - 1].text = msg
	toast_ages[toast_slots.size() - 1] = 0.0


func _line(pool: Array) -> String:
	# 셔플백. 직전 1개만 피하면 풀이 작을 때 금방 반복된다.
	# 묶음을 섞어놓고 하나씩 꺼내 쓰면 한 바퀴 돌기 전에는 절대 안 겹친다.
	if pool.is_empty():
		return ""
	var bag: Array = _bags.get(pool, [])
	if bag.is_empty():
		bag = range(pool.size())
		bag.shuffle()
		# 새 묶음 첫 장이 직전 대사면 뒤로 보낸다 (묶음 경계에서의 연속 중복 방지)
		if bag.size() > 1 and String(pool[bag[0]]) == _last_line:
			bag.push_back(bag.pop_front())
	var idx: int = bag.pop_front()
	_bags[pool] = bag
	_last_line = String(pool[idx])
	return _last_line


func _pop(msg: String, color: Color) -> void:
	lbl_pop.text = msg
	lbl_pop.add_theme_color_override("font_color", color)
	lbl_pop.modulate.a = 1.0
	pop_timer = 1.1


func _on_crash(force: float) -> void:
	crashes += 1
	if special_order and has_package and state == State.PLAY:
		special_damage += 1
		_toast(rtx_damage_lines[mini(special_damage - 1, rtx_damage_lines.size() - 1)])
		_pop("파손", Color(1.0, 0.35, 0.3))
	if botplay or debug_events:
		print("[event] 대형사고 impact=%.1f  누적 벽수집=%s원  수익=%s원" % [force, _won(crash_total + CRASH_PAY), _won(score + CRASH_PAY)])
	combo = 0
	_shake(clampf(force * 0.045, 0.3, 1.4), true)
	if state == State.PLAY:
		score += CRASH_PAY
		career_earnings += CRASH_PAY
		crash_total += CRASH_PAY
		_check_district_unlocks()
		if not (special_order and has_package):
			_toast(_line(crash_lines) + "   +%d원" % int(CRASH_PAY))
		var crash_mult: float = float(leg_mod["crash"]) if not leg_mod.is_empty() else 1.0
		time_left = maxf(TIME_FLOOR, time_left - 1.5 * crash_mult * (1.0 - car.crash_shield))


func _on_bump(force: float) -> void:
	bumps += 1
	if botplay or debug_events:
		print("[event] 긁힘 impact=%.1f  누적 벽수집=%s원" % [force, _won(crash_total + CRASH_PAY)])
	_shake(clampf(force * 0.06, 0.08, 0.3))
	if state == State.PLAY:
		score += CRASH_PAY
		career_earnings += CRASH_PAY
		crash_total += CRASH_PAY
		_check_district_unlocks()
		_toast(_line(bump_lines) + "   +%d원" % int(CRASH_PAY))
		time_left = maxf(TIME_FLOOR, time_left - 0.25 * (1.0 - car.crash_shield))


func _on_scrape() -> void:
	if botplay or debug_events:
		print("[event] 벽 비빔")
	if state == State.PLAY:
		_toast(_line(scrape_lines))


var drift_lines := [
	"뒷바퀴가 뭘 하는지 본인도 모릅니다",
	"타이어값은 회사가 안 줍니다",
	"이니셜 D 보고 오셨습니까",
	"국물이 원심분리 됐습니다",
	"주차장에서 연습한 티가 납니다",
	"고객님 음식이 방금 옆으로 누웠습니다",
	"드리프트는 지름길이 아닙니다. 그래도 합니다",
]


func _on_drift_boost(tier: int, charge: float, secs: float) -> void:
	if state != State.PLAY:
		return
	drift_boosts += 1
	best_drift = maxf(best_drift, secs)
	var names := ["", "미니 터보", "슈퍼 터보", "울트라 터보"]
	var gain: float = roundf(600.0 * tier * (1.0 + secs * 0.25))
	drift_total += gain
	_stunt(gain, "%s (%.1f초 드리프트)" % [names[tier], secs])
	_pop("%s!" % names[tier], car.drift_color(tier))
	_shake(0.12 + 0.06 * tier)
	if randf() < 0.55:
		_toast(_line(drift_lines))
	if drift_boosts >= 15:
		_unlock("drifter")
	if botplay or debug_events:
		print("[event] 드리프트 부스터 %d단계 / 충전 %.0f / %.1f초 / +%s원" % [
			tier, charge, secs, _won(gain)])


func _stunt(amount: float, label: String) -> void:
	if state != State.PLAY or is_cold():
		return
	score += amount
	career_earnings += amount
	stunt_total += amount
	_check_district_unlocks()
	_toast("%s  +%s원" % [label, _won(amount)])


func _on_land(force: float, air_hang: float) -> void:
	_shake(clampf(force * 0.02, 0.1, 0.9))
	if state == State.PLAY and air_hang > 0.8:
		air_bonuses += 1
		if air_bonuses >= 10:
			_unlock("acrobat")
		_stunt(roundf(air_hang * 2500.0), "에어타임 %.1f초" % air_hang)
	elif force > 22.0 and state == State.PLAY:
		_toast(_line(land_lines))


# ---------------------------------------------------------------- 입력 / 저장

func _try_shoot(screen_override := Vector2(-1, -1)) -> void:
	if state != State.PLAY or shoot_cooldown > 0.0:
		return
	# 총은 배그 전장에서만 나간다. 다른 구역에서는 그냥 아무 일도 일어나지 않는다.
	if not can_shoot():
		return
	shoot_cooldown = 0.16
	var mouse_pos := get_viewport().get_mouse_position()
	if screen_override.x >= 0.0:
		mouse_pos = screen_override
	var ray_origin := cam.project_ray_origin(mouse_pos)
	var ray_normal := cam.project_ray_normal(mouse_pos)
	# 커서를 고정 높이 평면에 투영하면, 트럭 위쪽을 겨눌 때 그 점이 트럭 '뒤 먼 바닥'으로
	# 매핑돼서 총알이 위로 넘어간다. 화면에서 커서 아래 실제로 있는 물체를 레이캐스트한다.
	var space := get_world_3d().direct_space_state
	var aim_q := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_normal * 400.0)
	aim_q.exclude = [car.get_rid()]
	var aim_res := space.intersect_ray(aim_q)
	var target_3d: Vector3 = ray_origin + ray_normal * 400.0
	if aim_res.size() > 0:
		target_3d = aim_res.get("position")

	var muzzle := car.get_muzzle_pos()
	var dir := (target_3d - muzzle).normalized()
	dir.y = clampf(dir.y, -0.6, 0.6)

	if Engine.has_meta("aim_debug"):
		print("[aim] 조준점=%s  muzzle=%s  dir=%s  레이적중=%s" % [
			str(target_3d.round()), str(muzzle.round()), str(dir),
			str(aim_res.get("collider").get_class() if aim_res.size() > 0 else "없음")])
	var b := Bullet.new()
	b.ignore = [car.get_rid()]
	add_child(b)
	b.setup(muzzle, dir)
	_shake(0.06)


func _unhandled_input(event: InputEvent) -> void:
	if cut_root != null and cut_root.visible:
		var pressed: bool = false
		if event is InputEventKey:
			pressed = (event as InputEventKey).pressed and not (event as InputEventKey).echo
		elif event is InputEventMouseButton:
			pressed = (event as InputEventMouseButton).pressed
		elif event is InputEventJoypadButton:
			pressed = (event as InputEventJoypadButton).pressed
		if pressed:
			close_unlock_cutscene()
		return

	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
			_set_aiming(false)
	if aiming and event is InputEventMouseMotion:
		var rel := (event as InputEventMouseMotion).relative
		aim_yaw = clampf(aim_yaw - rel.x * AIM_SENS, -AIM_YAW_LIMIT, AIM_YAW_LIMIT)
		aim_pitch = clampf(aim_pitch - rel.y * AIM_SENS, -AIM_PITCH_LIMIT, AIM_PITCH_LIMIT)
		return
	if state == State.PLAY and event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			# 총이 있는 구역은 사격, 없으면 주먹
			if can_shoot():
				# 조준 중에는 커서가 아니라 경통 한가운데로 쏜다
				if aim_t > 0.5:
					_try_shoot(get_viewport().get_visible_rect().size * 0.5)
				else:
					_try_shoot()
			else:
				_try_punch()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			# 총이 있는 구역은 조준경, 없으면 주먹
			if can_shoot() and cam_mode != CamMode.TRIP:
				_set_aiming(true)
			else:
				_try_punch()
			return

	if not (event is InputEventKey) or event.echo or not event.pressed:
		_check_pad_confirm()
		return
	var key := (event as InputEventKey).keycode
	match state:
		State.TITLE:
			if key == KEY_SPACE or key == KEY_ENTER:
				_show_story()
			elif key == KEY_ESCAPE:
				get_tree().quit()
		State.STORY:
			if key == KEY_SPACE or key == KEY_ENTER:
				_advance_story()
			elif key == KEY_ESCAPE:
				story_root.visible = false
				start_game()
		State.MENU:
			menu.handle_key(key)
		State.PLAY:
			if tutorial_step >= 0 and key == KEY_ESCAPE:
				skip_tutorial()
				return
			if tutorial_step == TUTORIAL.size() - 1:
				_advance_tutorial()
				return
			if key == KEY_V:
				cycle_camera()
			elif key == KEY_F:
				_try_punch()
			elif key == KEY_R:
				car.reset_to(car.global_position.snapped(Vector3.ONE))
				_toast("제자리 복귀. 시간은 안 돌려줍니다")
			elif key == KEY_ESCAPE or key == KEY_L:
				open_menu()
		State.RESULT:
			if key == KEY_R or key == KEY_SPACE or key == KEY_ENTER:
				start_game()
			elif key == KEY_ESCAPE:
				get_tree().quit()


func _check_pad_confirm() -> void:
	if state == State.PLAY:
		return
	if Input.get_connected_joypads().size() == 0:
		return
	var pad: int = Input.get_connected_joypads()[0]
	if Input.is_joy_button_pressed(pad, JOY_BUTTON_START):
		start_game()


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = float(cfg.get_value("record", "best_score", 0.0))
		career_earnings = float(cfg.get_value("record", "career_earnings", 0.0))
		selected_district = int(cfg.get_value("record", "selected_district", 0))
		tutorial_done = bool(cfg.get_value("record", "tutorial_done", false))
		cam_mode = int(cfg.get_value("record", "cam_mode", 0)) % CamMode.size()
		seen_unlock_cutscene = cfg.get_value("record", "seen_unlock_cutscene", {})
		var saved: Dictionary = cfg.get_value("record", "achieved", {})
		for k in saved.keys():
			achieved[k] = bool(saved[k])


func _save() -> void:
	if debug_no_save:
		return
	var cfg := ConfigFile.new()
	cfg.set_value("record", "best_score", best_score)
	cfg.set_value("record", "career_earnings", career_earnings)
	cfg.set_value("record", "selected_district", selected_district)
	cfg.set_value("record", "achieved", achieved)
	cfg.set_value("record", "tutorial_done", tutorial_done)
	cfg.set_value("record", "cam_mode", cam_mode)
	cfg.set_value("record", "seen_unlock_cutscene", seen_unlock_cutscene)
	cfg.save(SAVE_PATH)
