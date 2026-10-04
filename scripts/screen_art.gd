extends Control
class_name ScreenArt

# 건물 전광판 화면. 이미지 파일 없이 _draw() 로 매 프레임 직접 그린다.
# SubViewport 안에서 돌아가고, 그 텍스처를 3D 쿼드에 붙여서 도시에 건다.

const W := 256.0
const H := 128.0

var kind := 0
var accent := Color(1.0, 0.3, 0.3)
var t := 0.0
var _font: Font
var _ads: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Apple SD Gothic Neo", "AppleGothic", "Noto Sans CJK KR"])
	sf.font_weight = 700
	_font = sf
	# 채널마다 문구를 한 번만 골라둔다. 매 프레임 뽑으면 글자가 부들부들 떨린다.
	_ads = [
		["퀵 루프 배달원 대모집", "주 7일 · 4대보험 없음 · 열정페이 있음"],
		["24시 국밥", "밥은 무한리필 국물은 유한"],
		["김밥천국 ▲ 12.4%", "치킨집 ▼ 3.1%   피자 ▲ 0.2%"],
		["노래방 1시간 5,000원", "지금 들어가면 2시간 5,000원"],
		["속보", "도심서 배달 트럭 난동 … 시민 대피"],
		["치킨 9,900원", "배달비 12,000원"],
	]


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _txt(pos: Vector2, s: String, sz: int, c: Color, center := false) -> void:
	var al := HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	var w := W if center else -1.0
	var p := Vector2(0.0 if center else pos.x, pos.y)
	draw_string(_font, p, s, al, w, sz, c)


func _scanlines() -> void:
	# LED 패널 티를 내는 가로줄. 이거 없으면 그냥 색칠한 판이다.
	var y := 0.0
	while y < H:
		draw_rect(Rect2(0, y, W, 1.0), Color(0, 0, 0, 0.22))
		y += 4.0


func _draw() -> void:
	var ad: Array = _ads[kind % _ads.size()]
	match kind % 6:
		0: _ch_scroll(ad)
		1: _ch_neon(ad)
		2: _ch_ticker(ad)
		3: _ch_equalizer(ad)
		4: _ch_news(ad)
		_: _ch_price(ad)
	_scanlines()
	# 테두리
	draw_rect(Rect2(1, 1, W - 2, H - 2), Color(0.1, 0.1, 0.12), false, 2.0)


func _ch_scroll(ad: Array) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.05, 0.09))
	_txt(Vector2(0, 40), String(ad[0]), 26, accent, true)
	# 아래줄만 흘러간다
	var line: String = String(ad[1]) + "   ·   "
	var span: float = _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var x: float = -fmod(t * 46.0, span)
	while x < W:
		_txt(Vector2(x, 84), line, 18, Color(1, 1, 1, 0.9))
		x += span
	draw_rect(Rect2(0, 96, W, 6), accent)


func _ch_neon(ad: Array) -> void:
	var on: bool = fmod(t, 1.6) < 1.2
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.03, 0.05))
	var c: Color = accent if on else accent.darkened(0.72)
	draw_rect(Rect2(8, 8, W - 16, H - 16), c, false, 4.0)
	_txt(Vector2(0, 62), String(ad[0]), 38, c, true)
	_txt(Vector2(0, 94), String(ad[1]), 14, Color(1, 1, 1, 0.55 if on else 0.2), true)


func _ch_ticker(ad: Array) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.06, 0.04))
	# 톱니 주가 그래프. 시드를 t 와 무관하게 만들어 모양이 안 튀게 한다.
	var pts := PackedVector2Array()
	for i in 33:
		var fx: float = float(i) / 32.0
		var v: float = sin(fx * 9.0 + t * 1.2) * 0.5 + sin(fx * 21.0) * 0.28
		pts.append(Vector2(fx * W, 78.0 - v * 30.0))
	draw_polyline(pts, Color(0.3, 1.0, 0.5), 2.0)
	_txt(Vector2(0, 30), String(ad[0]), 24, Color(0.35, 1.0, 0.55), true)
	_txt(Vector2(0, 112), String(ad[1]), 15, Color(1, 0.5, 0.45), true)


func _ch_equalizer(ad: Array) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.03, 0.10))
	var bars := 16
	for i in bars:
		var ph: float = float(i) * 0.7
		var v: float = absf(sin(t * 4.0 + ph)) * 0.65 + absf(sin(t * 7.0 + ph * 1.7)) * 0.3
		var bh: float = 8.0 + v * 56.0
		var bw: float = W / float(bars) - 3.0
		draw_rect(Rect2(i * (W / float(bars)) + 1.5, 96.0 - bh, bw, bh),
			Color(0.5 + v * 0.5, 0.25, 1.0))
	_txt(Vector2(0, 26), String(ad[0]), 20, Color(1, 1, 1), true)
	_txt(Vector2(0, 118), String(ad[1]), 13, Color(0.8, 0.7, 1.0), true)


func _ch_news(ad: Array) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.06, 0.08))
	var flash: bool = fmod(t, 1.0) < 0.55
	draw_rect(Rect2(0, 10, 76, 34), Color(0.9, 0.1, 0.15) if flash else Color(0.45, 0.06, 0.09))
	_txt(Vector2(12, 36), String(ad[0]), 24, Color(1, 1, 1))
	draw_rect(Rect2(0, 58, W, 3), Color(0.9, 0.1, 0.15))
	var line: String = String(ad[1]) + "      "
	var span: float = _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var x: float = W - fmod(t * 54.0, span + W)
	_txt(Vector2(x, 88), line, 17, Color(1, 1, 1, 0.92))
	draw_rect(Rect2(0, 100, W, 22), Color(0.12, 0.12, 0.16))
	_txt(Vector2(8, 117), "QUICK LOOP NEWS", 13, Color(0.7, 0.75, 0.9))


func _ch_price(ad: Array) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * 3.4)
	draw_rect(Rect2(0, 0, W, H), Color(0.10, 0.06, 0.02))
	# 대충 닭다리로 보이는 도형. 똥겜이니까 이 정도면 됐다.
	draw_circle(Vector2(44, 62), 22.0, Color(0.85, 0.55, 0.18))
	draw_rect(Rect2(58, 56, 34, 12), Color(0.92, 0.82, 0.62))
	_txt(Vector2(104, 56), String(ad[0]), 22, Color(1.0, 0.85 - pulse * 0.3, 0.2))
	_txt(Vector2(104, 84), String(ad[1]), 15, Color(1, 1, 1, 0.55))
	draw_rect(Rect2(0, H - 8, W * pulse, 8), accent)
