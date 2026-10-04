extends Control
class_name Scope

# 배그 구역 레드닷 조준기. 우클릭을 물고 있는 동안만 보인다.
# 배율 경통과 달리 바깥을 까맣게 덮지 않는다. 얇은 하우징 링 + 렌즈 틴트 +
# 가운데 빨간 점이 전부다. 시야를 안 잡아먹는 게 레드닷의 존재 이유다.

var center := Vector2.ZERO
var radius := 210.0
var zoom := 1.0
var sway := 0.0
var on := 1.0     # 0 = 꺼짐, 1 = 완전히 올라옴. 켜질 때 점이 먼저 들어온다


func _draw() -> void:
	if radius <= 1.0:
		return
	var c := center + Vector2(sin(sway * 1.7) * 1.6, cos(sway * 1.3) * 1.3)

	# 렌즈. 아주 옅은 푸른 코팅 + 가장자리만 살짝 어둡게.
	draw_circle(center, radius, Color(0.30, 0.55, 0.95, 0.035 * on))
	draw_arc(center, radius * 0.95, 0.0, TAU, 64, Color(0.02, 0.03, 0.05, 0.10 * on),
		radius * 0.09)
	# 하우징. 두꺼운 고무 링처럼 보이게 두 겹.
	draw_arc(center, radius, 0.0, TAU, 72, Color(0.05, 0.05, 0.06, 0.92 * on), 9.0)
	draw_arc(center, radius - 5.0, 0.0, TAU, 72, Color(0.42, 0.45, 0.52, 0.55 * on), 1.5)
	draw_arc(center, radius + 5.0, 0.0, TAU, 72, Color(0.0, 0.0, 0.0, 0.55 * on), 2.0)

	# 레티클: 큰 원 + 가운데 점 (EOTech 식)
	var red := Color(1.0, 0.16, 0.12, 0.95 * on)
	var glow := Color(1.0, 0.18, 0.12, 0.32 * on)
	var ring_r: float = radius * 0.46
	draw_arc(c, ring_r, 0.0, TAU, 48, glow, 7.0)
	draw_arc(c, ring_r, 0.0, TAU, 48, red, 2.0)
	# 원을 4등분하는 짧은 눈금. 원만 있으면 어디가 위인지 안 보인다.
	for i in 4:
		var a: float = float(i) * TAU / 4.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * (ring_r - 9.0), c + d * (ring_r + 9.0), red, 2.0)
	# 가운데 점. 번지는 빛을 겹쳐서 진짜 발광처럼 보이게 한다.
	draw_circle(c, 13.0, glow)
	draw_circle(c, 6.4, Color(1.0, 0.18, 0.12, 0.8 * on))
	draw_circle(c, 3.4, Color(1.0, 0.42, 0.34, 1.0 * on))
	draw_circle(c, 1.4, Color(1.0, 0.92, 0.88, 1.0 * on))

	# 하단 표기
	var f := ThemeDB.fallback_font
	draw_string(f, center + Vector2(-radius * 0.22, radius * 0.72), "RED DOT %.1fx" % zoom,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.45, 0.4, 0.7 * on))
