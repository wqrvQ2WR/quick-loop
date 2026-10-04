extends Control
class_name Minimap

var city: City
var car: Node3D
var target := Vector3.ZERO
var has_pkg := false
var cold := false


var rivals: Array = []
var money_drops: Array = []
var is_pubg := false
var bluezone_center := Vector3.ZERO
var bluezone_radius := 0.0
var next_center := Vector3.ZERO
var next_radius := 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if city == null or car == null:
		return
	var sz := size
	var span: float = City.GRID * City.CELL + City.ROAD * 2.0
	var s: float = minf(sz.x, sz.y) / span
	var c := sz * 0.5
	var origin: float = -City.GRID * City.CELL * 0.5

	# 배경 = 건물 덩어리
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.06, 0.06, 0.13, 0.82))

	# 도로를 실제 폭만큼 띠로 그린다
	var road_col := Color(0.70, 0.74, 0.88, 0.5)
	var av_col := Color(0.85, 0.88, 1.0, 0.65)
	for i in City.GRID + 1:
		var q: float = origin + i * City.CELL
		var rw: float = maxf(3.0, city.road_width(i) * s)
		var col: Color = av_col if city.road_width(i) > City.ROAD * 1.5 else road_col
		var x := c.x + q * s
		var y := c.y + q * s
		draw_rect(Rect2(x - rw * 0.5, 0, rw, sz.y), col)
		draw_rect(Rect2(0, y - rw * 0.5, sz.x, rw), col)

	# 자기장 (배그 구역)
	if is_pubg and bluezone_radius > 0.0:
		var bz_pos := c + Vector2(bluezone_center.x, bluezone_center.z) * s
		var bz_r := bluezone_radius * s
		draw_circle(bz_pos, bz_r, Color(0.65, 0.15, 0.95, 0.15))
		draw_arc(bz_pos, bz_r, 0, TAU, 32, Color(0.85, 0.25, 1.0, 0.85), 2.0)
		# 다음 자기장 예고. 중심이 옮겨가므로 어디로 뛸지 미리 보여줘야 한다.
		if next_radius > 0.0:
			var np := c + Vector2(next_center.x, next_center.z) * s
			draw_arc(np, next_radius * s, 0, TAU, 32, Color(1.0, 1.0, 1.0, 0.8), 1.5)

	# 머니 드랍
	for md in money_drops:
		if is_instance_valid(md):
			var mdp := c + Vector2(md.global_position.x, md.global_position.z) * s
			draw_circle(mdp, 3.5, Color(0.2, 1.0, 0.4, 0.9))
			draw_circle(mdp, 1.8, Color(1.0, 0.9, 0.2))

	# 경쟁사 배달차 (적)
	for r in rivals:
		if is_instance_valid(r):
			var rp := c + Vector2(r.global_position.x, r.global_position.z) * s
			draw_circle(rp, 3.8, Color(1.0, 0.2, 0.25, 0.95))

	# 목표
	var tp := c + Vector2(target.x, target.z) * s
	var pulse: float = 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() / 250.0))
	var tc: Color = Color(1.0, 0.72, 0.3) if has_pkg else Color(0.3, 1.0, 0.6)
	draw_circle(tp, 4.0 + pulse * 5.0, Color(tc.r, tc.g, tc.b, 0.3))
	draw_circle(tp, 3.5, tc)

	# 차 (진행 방향 삼각형)
	var cp := c + Vector2(car.global_position.x, car.global_position.z) * s
	var yaw := car.global_rotation.y
	var f := Vector2(-sin(yaw), -cos(yaw))
	var perp := Vector2(-f.y, f.x)
	var body := PackedVector2Array([
		cp + f * 8.0,
		cp - f * 4.5 + perp * 4.5,
		cp - f * 4.5 - perp * 4.5,
	])
	draw_colored_polygon(body, Color(0.4, 0.95, 1.0) if cold else Color(1.0, 0.28, 0.38))

	# 목표 방향 실선
	draw_line(cp, tp, Color(tc.r, tc.g, tc.b, 0.35), 1.5)

	# 테두리
	draw_rect(Rect2(Vector2.ZERO, sz),
		Color(0.45, 0.85, 1.0, 0.75) if cold else Color(1, 1, 1, 0.45), false, 2.0)
