extends Node3D
class_name City

const GRID := 7
const BLOCK := 46.0
const ROAD := 28.0
const CELL := BLOCK + ROAD
const PUBG_DISTRICT_INDEX := 1
const MACHO_DISTRICT_INDEX := 2

const THEMES := [
	{"name": "파스텔 지구", "hue": [0.0, 1.0], "sat": [0.42, 0.80], "val": [0.85, 1.00],
	 "road": Color(0.18, 0.19, 0.26), "walk": Color(0.62, 0.64, 0.72), "grass": Color(0.35, 0.82, 0.38),
	 "unlock_cost": 0, "pay_mult": 1.0, "desc": "알록달록 파스텔톤의 평화로운 1일차 배달 구역"},
	{"name": "배그 전장", "hue": [0.12, 0.26], "sat": [0.35, 0.70], "val": [0.55, 0.85],
	 "road": Color(0.16, 0.15, 0.13), "walk": Color(0.50, 0.48, 0.42), "grass": Color(0.38, 0.45, 0.22),
	 "unlock_cost": 100000, "pay_mult": 2.0, "desc": "보라색 자기장과 3렙 뚝배기! 2일차 서바이벌 전장", "is_pubg": true},
	{"name": "마초 트럭장", "hue": [0.0, 0.12], "sat": [0.72, 1.00], "val": [0.78, 1.00],
	 "road": Color(0.13, 0.10, 0.09), "walk": Color(0.46, 0.39, 0.35), "grass": Color(0.52, 0.46, 0.24),
	 "unlock_cost": 300000, "pay_mult": 2.5, "desc": "팔다리 달린 마초 트럭들이 서로 마짱까고 돈다발을 떨구는 3일차 격투장", "is_macho": true},
	{"name": "단풍 구역", "hue": [0.02, 0.14], "sat": [0.55, 0.90], "val": [0.80, 1.00],
	 "road": Color(0.22, 0.18, 0.18), "walk": Color(0.70, 0.62, 0.55), "grass": Color(0.75, 0.55, 0.15),
	 "unlock_cost": 600000, "pay_mult": 3.0, "desc": "노랗고 붉은 낙엽과 가을 정취가 가득한 구역"},
	{"name": "해안 신도시", "hue": [0.44, 0.63], "sat": [0.45, 0.85], "val": [0.85, 1.00],
	 "road": Color(0.14, 0.18, 0.26), "walk": Color(0.72, 0.78, 0.86), "grass": Color(0.30, 0.80, 0.60),
	 "unlock_cost": 1000000, "pay_mult": 3.5, "desc": "시원한 바다빛과 정돈된 마천루의 해안 도시"},
	{"name": "흑백 구역", "hue": [0.0, 1.0], "sat": [0.00, 0.10], "val": [0.55, 1.00],
	 "road": Color(0.14, 0.14, 0.15), "walk": Color(0.55, 0.55, 0.57), "grass": Color(0.45, 0.48, 0.45),
	 "unlock_cost": 2000000, "pay_mult": 4.0, "desc": "비장한 느와르 영화 속 무채색 고수익 구역"},
]

var theme: Dictionary = THEMES[0]
var _lim := Vector2(26.0, 26.0)   # 현재 그리는 블록의 반지름
var _block_c := Vector2.ZERO      # 현재 블록 중심. 전광판을 길 쪽으로 돌릴 때 쓴다
var _marks: Array = []            # 도로 표시. 전부 MultiMesh 한 덩어리로 합친다
var intersections: Array[Vector3] = []
var cows: Array[Node3D] = []
var islands: Array[Vector3] = []
var breakables: Array[Node3D] = []   # 가로등·가로수. 치면 저항 없이 쓰러진다
var _screen_tex: Array = []          # 전광판 채널 텍스처. 여러 건물이 나눠 쓴다
var _screens_hung := 0
var billboards: Array[MeshInstance3D] = []   # 건 전광판들. 디버그 촬영용
var window_mats: Array[StandardMaterial3D] = []   # 창문 머티리얼. 밤에만 불을 켠다

const SCREEN_CHANNELS := 6   # 채널(SubViewport) 수. 이 수만큼만 매 프레임 그린다
const MAX_SCREENS := 16      # 도시에 거는 전광판 총 개수 상한

const BREAKABLE_LAYER := 4   # 3번 레이어. 차 충돌 마스크에 없으므로 막히지 않는다

var _rng := RandomNumberGenerator.new()
var _origin := 0.0


func rebuild(seed_value: int, theme_idx: int = -1) -> void:
	# 판마다 도시를 새로 만든다. queue_free 는 지연되므로 트리에서 먼저 떼어낸다.
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	intersections.clear()
	cows.clear()
	window_mats.clear()
	_screen_tex.clear()
	_screens_hung = 0
	islands.clear()
	breakables.clear()
	build_with_theme(seed_value, theme_idx)


func build(seed_value: int) -> void:
	build_with_theme(seed_value, 0)


func build_with_theme(seed_value: int, theme_idx: int) -> void:
	_rng.seed = seed_value
	theme = THEMES[0] if theme_idx < 0 else THEMES[theme_idx % THEMES.size()]
	_origin = -GRID * CELL * 0.5
	_make_ground()
	_setup_screens()
	for i in GRID:
		for j in GRID:
			_make_block(i, j)
	for i in range(1, GRID):
		for j in range(1, GRID):
			intersections.append(Vector3(_origin + i * CELL, 0.0, _origin + j * CELL))
	_make_props()
	_make_bounds()
	_flush_marks()


func set_night(v: float) -> void:
	# v: 0 = 한낮, 1 = 한밤. 창문 불빛 세기를 여기서만 건드린다.
	var e: float = clampf(v, 0.0, 1.0) * 0.7
	for m in window_mats:
		m.emission_energy_multiplier = e


func road_width(i: int) -> float:
	# 3칸마다 대로. 격자가 균일하면 도시가 아니라 바둑판으로 보인다.
	return ROAD * 1.8 if i % 3 == 0 else ROAD


func _block_rect(i: int, j: int) -> Rect2:
	var x0: float = _origin + i * CELL + road_width(i) * 0.5
	var x1: float = _origin + (i + 1) * CELL - road_width(i + 1) * 0.5
	var z0: float = _origin + j * CELL + road_width(j) * 0.5
	var z1: float = _origin + (j + 1) * CELL - road_width(j + 1) * 0.5
	return Rect2(x0, z0, x1 - x0, z1 - z0)


func _mark(size: Vector3, pos: Vector3, c: Color, rot_y := 0.0) -> void:
	# 바닥 표시는 수천 개라 하나씩 MeshInstance 로 놓으면 드로우콜이 폭발한다.
	_marks.append({"size": size, "pos": pos, "color": c, "rot": rot_y})


func _flush_marks() -> void:
	if _marks.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	mm.instance_count = _marks.size()
	for i in _marks.size():
		var m: Dictionary = _marks[i]
		var basis := Basis(Vector3.UP, float(m["rot"])).scaled(m["size"])
		mm.set_instance_transform(i, Transform3D(basis, m["pos"]))
		mm.set_instance_color(i, m["color"])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# albedo_color 는 엔진이 sRGB -> 선형 변환을 해주지만 정점 색은 안 해준다.
	# 이걸 안 켜면 색이 틀어져서 어둡게 깔린다.
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.9
	mmi.material_override = mat
	add_child(mmi)
	_marks.clear()


func _setup_screens() -> void:
	# 채널 수만큼만 SubViewport 를 만들고, 건물 전광판들이 그 텍스처를 돌려 쓴다.
	# 전광판마다 뷰포트를 하나씩 주면 프레임마다 16장을 다시 그려야 해서 못 쓴다.
	_screen_tex.clear()
	_screens_hung = 0
	billboards.clear()
	for k in SCREEN_CHANNELS:
		var vp := SubViewport.new()
		vp.size = Vector2i(int(ScreenArt.W), int(ScreenArt.H))
		vp.transparent_bg = false
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var art := ScreenArt.new()
		art.kind = k
		art.accent = Color.from_hsv(fmod(float(k) * 0.17 + 0.03, 1.0), 0.85, 1.0)
		vp.add_child(art)
		add_child(vp)
		_screen_tex.append(vp.get_texture())


func _billboard(pos: Vector3, width: float, yaw: float) -> void:
	if _screen_tex.is_empty() or _screens_hung >= MAX_SCREENS:
		return
	_screens_hung += 1
	var tex: Texture2D = _screen_tex[_rng.randi() % _screen_tex.size()]
	var hgt: float = width * 0.5   # 화면 비율 2:1
	var face := Vector3(0, 0, 1).rotated(Vector3.UP, yaw)

	# 뒤에 받치는 검은 판. 이게 없으면 화면이 공중에 뜬 종이처럼 보인다.
	var frame := _box(Vector3(width + 1.6, hgt + 1.6, 0.6), pos - face * 0.35,
		Color(0.07, 0.07, 0.09), false, 0.0, yaw)
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, hgt)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	# 자체발광 화면이라 조명을 안 받는다. 밤에도 낮에도 같은 밝기로 보인다.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	billboards.append(mi)

	# 화면이 뿜는 빛. 쿼드는 UNSHADED 라 주변을 못 밝히므로 따로 달아준다.
	var lt := OmniLight3D.new()
	lt.light_color = Color(0.85, 0.9, 1.0)
	lt.light_energy = 2.2
	lt.omni_range = width * 2.0
	lt.shadow_enabled = false
	lt.position = pos + face * 2.0
	add_child(lt)


func _mat(c: Color, emission := 0.0, kind := -1, tile := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	m.metallic = 0.0
	if kind >= 0:
		# 삼면 투영이라 박스 크기가 제각각이어도 무늬 크기가 일정하다.
		# UV 를 손으로 맞추면 건물마다 타일이 늘어난다.
		m.albedo_texture = Tex.get_tex(kind)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(tile, tile, tile)
		if kind == Tex.Kind.WINDOWS:
			# 창문 일부만 불이 켜진 마스크를 발광으로 깐다.
			# 낮엔 햇빛에 묻히고 밤에만 티가 난다. 매 프레임 갱신할 필요가 없다.
			m.emission_enabled = true
			m.emission = Color(1.0, 0.88, 0.62)
			m.emission_texture = Tex.get_window_emission()
			# 낮에는 꺼둔다. 햇빛 아래서 창문이 빛나면 건물색이 전부 크림색으로 뜬다.
			m.emission_energy_multiplier = 0.0
			window_mats.append(m)
			return m
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m


func _box(size: Vector3, pos: Vector3, c: Color, solid := true, emission := 0.0,
		rot_y := 0.0, glass := false, kind := -1, tile := 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := _mat(c, emission, kind, tile)
	if glass:
		m.roughness = 0.12
		m.metallic = 0.65
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		body.position = pos
		body.rotation.y = rot_y
		add_child(body)
	return mi


func _make_ground() -> void:
	var span := GRID * CELL + ROAD * 4.0
	_box(Vector3(span, 2.0, span), Vector3(0, -1.0, 0), theme["road"], true, 0.0, 0.0, false,
		Tex.Kind.ASPHALT, 0.33)

	var line_c := Color(1.0, 0.85, 0.15)
	var edge_c := Color(0.92, 0.93, 0.97, 0.75)

	for i in GRID + 1:
		var p := _origin + i * CELL
		var w := road_width(i)
		var wide := w > ROAD * 1.5

		# 도로 가장자리 흰 선
		for sgn in [-1.0, 1.0]:
			_mark(Vector3(0.45, 0.1, span), Vector3(p + sgn * (w * 0.5 - 1.0), 0.06, 0), edge_c)
			_mark(Vector3(span, 0.1, 0.45), Vector3(0, 0.06, p + sgn * (w * 0.5 - 1.0)), edge_c)

		if wide:
			# 대로는 중앙 점선 2줄과 차선 분할선으로 쾌적하게 주행 가능 (중앙분리대 제거)
			_dashes(p - 1.2, true, span, line_c)
			_dashes(p + 1.2, true, span, line_c)
			_dashes(p - w * 0.25, true, span, edge_c)
			_dashes(p + w * 0.25, true, span, edge_c)
			_dashes(p - 1.2, false, span, line_c)
			_dashes(p + 1.2, false, span, line_c)
			_dashes(p - w * 0.25, false, span, edge_c)
			_dashes(p + w * 0.25, false, span, edge_c)
		else:
			# 일반 도로는 점선 차선
			_dashes(p, true, span, line_c)
			_dashes(p, false, span, line_c)


	_crosswalks()


func _dashes(p: float, vertical: bool, span: float, c: Color) -> void:
	var seg := 6.0
	var gap := 9.0
	var n: int = int(span / (seg + gap))
	for k in n:
		var t := -span * 0.5 + float(k) * (seg + gap) + seg * 0.5
		if vertical:
			_mark(Vector3(0.55, 0.1, seg), Vector3(p, 0.06, t), c)
		else:
			_mark(Vector3(seg, 0.1, 0.55), Vector3(t, 0.06, p), c)


func _breakable_root(base: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = base
	add_child(root)
	breakables.append(root)
	return root


func _part(parent: Node3D, size: Vector3, pos: Vector3, c: Color, emission := 0.0,
		kind := -1, tile := 0.6) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, emission, kind, tile)
	mi.position = pos
	parent.add_child(mi)


func _breakable_body(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	# 전용 레이어에만 올린다. 차와는 안 부딪히고 총알·감지 쿼리만 잡는다.
	var body := StaticBody3D.new()
	body.collision_layer = BREAKABLE_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = pos
	parent.add_child(body)


func _lamp(base: Vector3) -> void:
	var glow := Color(1.0, 0.92, 0.6)
	var h := 7.5
	var root := _breakable_root(base)
	_part(root, Vector3(0.5, h, 0.5), Vector3(0, h * 0.5, 0), Color(0.28, 0.28, 0.34),
		0.0, Tex.Kind.METAL, 1.2)
	_part(root, Vector3(0.9, 0.35, 0.9), Vector3(0, 0.2, 0), Color(0.2, 0.2, 0.26),
		0.0, Tex.Kind.METAL, 1.2)
	_part(root, Vector3(1.5, 0.45, 0.8), Vector3(0, h, 0), glow, 3.2)
	_breakable_body(root, Vector3(1.4, h, 1.4), Vector3(0, h * 0.5, 0))


func _crosswalks() -> void:
	var c := Color(0.95, 0.96, 1.0)
	for i in GRID + 1:
		for j in GRID + 1:
			if i == 0 or j == 0 or i == GRID or j == GRID:
				continue
			var px := _origin + i * CELL
			var pz := _origin + j * CELL
			var wx := road_width(i)
			var wz := road_width(j)
			var off_z := wz * 0.5 + 3.4
			var off_x := wx * 0.5 + 3.4
			for sgn in [-1.0, 1.0]:
				var bars: int = int(wx / 4.6)
				for k in bars:
					var t := px - wx * 0.5 + 2.3 + float(k) * 4.6
					_mark(Vector3(2.0, 0.1, 4.6), Vector3(t, 0.07, pz + sgn * off_z), c)
				var bars2: int = int(wz / 4.6)
				for k2 in bars2:
					var t2 := pz - wz * 0.5 + 2.3 + float(k2) * 4.6
					_mark(Vector3(4.6, 0.1, 2.0), Vector3(px + sgn * off_x, 0.07, t2), c)


func _building(cx: float, cz: float, w: float, d: float, h: float, yaw: float, hue: float) -> void:
	var hr: Array = theme["hue"]
	var sr: Array = theme["sat"]
	var vr: Array = theme["val"]
	var th_hue: float = lerpf(float(hr[0]), float(hr[1]), fmod(hue, 1.0))
	var col := Color.from_hsv(th_hue,
		_rng.randf_range(float(sr[0]), float(sr[1])),
		_rng.randf_range(float(vr[0]), float(vr[1])))
	var glass := h > 34.0 and _rng.randf() < 0.35
	# 표면 무늬. 높은 건물은 통창, 낮은 건물은 벽돌이나 콘크리트.
	var skin: int = Tex.Kind.WINDOWS
	if h < 22.0:
		skin = Tex.Kind.BRICK if _rng.randf() < 0.5 else Tex.Kind.CONCRETE
	elif _rng.randf() < 0.25:
		skin = Tex.Kind.PANEL
	var skin_tile: float = 0.22 if skin == Tex.Kind.WINDOWS else 0.42
	var base_h := h
	var tiers := 1
	if h > 30.0 and _rng.randf() < 0.45:
		tiers = _rng.randi_range(2, 3)
	if tiers > 1:
		var remaining := h
		var cw := w
		var cd := d
		var y := 0.9
		for t in tiers:
			var seg: float = remaining * (0.55 if t < tiers - 1 else 1.0)
			_box(Vector3(cw, seg, cd), Vector3(cx, y + seg * 0.5, cz),
				col.lightened(t * 0.08), true, 0.0, yaw, glass, skin, skin_tile)
			y += seg
			remaining -= seg
			cw *= _rng.randf_range(0.6, 0.82)
			cd *= _rng.randf_range(0.6, 0.82)
		base_h = y - 0.9
	else:
		_box(Vector3(w, h, d), Vector3(cx, h * 0.5 + 0.9, cz), col, true, 0.0, yaw, glass,
			skin, skin_tile)

	if _rng.randf() < 0.6:
		_box(Vector3(w * _rng.randf_range(0.2, 0.4), _rng.randf_range(2.0, 5.0), d * 0.3),
			Vector3(cx, base_h + 2.4, cz), col.lightened(0.3), false, 0.0, yaw, false,
			Tex.Kind.METAL, 0.5)
	if base_h > 20.0 and _rng.randf() < 0.45:
		# 간판은 블록 바깥(= 도로) 쪽 면에 건다. 아무 면에나 붙이면 옆 건물 벽만 쳐다본다.
		var outward := Vector2(cx, cz) - _block_c
		if outward.length() < 1.0:
			outward = Vector2(1, 0).rotated(_rng.randf() * TAU)
		var best_k := 0
		var best_dot := -INF
		for k in 4:
			var fy: float = yaw + float(k) * PI * 0.5
			var dir := Vector2(sin(fy), cos(fy))   # +Z 를 yaw 만큼 돌린 방향의 (x,z)
			var dt: float = dir.dot(outward.normalized())
			if dt > best_dot:
				best_dot = dt
				best_k = k
		var best_yaw: float = yaw + float(best_k) * PI * 0.5
		# k 가 짝수면 ±Z 면(폭 w, 두께 d), 홀수면 ±X 면(폭 d, 두께 w)
		var best_half: float = (d if best_k % 2 == 0 else w) * 0.5
		var face_w: float = w if best_k % 2 == 0 else d
		var off := Vector3(0, 0, best_half + 0.3).rotated(Vector3.UP, best_yaw)
		var sign_pos := Vector3(cx, base_h * _rng.randf_range(0.5, 0.8), cz) + off
		if _screens_hung < MAX_SCREENS and _rng.randf() < 0.55:
			_billboard(sign_pos, clampf(face_w * 0.8, 6.0, 22.0), best_yaw)
		else:
			var sign_col := Color.from_hsv(fmod(th_hue + 0.5, 1.0), 0.9, 1.0)
			_box(Vector3(face_w * 0.75, 4.0, 0.5), sign_pos, sign_col, false, 1.6, best_yaw)


func _make_block(i: int, j: int) -> void:
	var r := _block_rect(i, j)
	if r.size.x < 12.0 or r.size.y < 12.0:
		return
	var cx := r.position.x + r.size.x * 0.5
	var cz := r.position.y + r.size.y * 0.5
	_lim = Vector2(r.size.x * 0.5 - 5.5, r.size.y * 0.5 - 5.5)
	_block_c = Vector2(cx, cz)

	_box(Vector3(r.size.x + 3.0, 0.9, r.size.y + 3.0), Vector3(cx, 0.45, cz), theme["walk"], true,
		0.0, 0.0, false, Tex.Kind.PAVEMENT, 0.33)
	_street_furniture(cx, cz, r)

	var roll := _rng.randf()
	if roll < 0.07:
		_layout_park(cx, cz)
	elif roll < 0.30:
		_layout_tower(cx, cz)
	elif roll < 0.62:
		_layout_row(cx, cz)
	elif roll < 0.94:
		_layout_cluster(cx, cz)
	else:
		_layout_plaza(cx, cz)


func _street_furniture(cx: float, cz: float, r: Rect2) -> void:
	# 인도 가장자리를 따라 가로등과 가로수를 번갈아 놓는다.
	# 예전에는 도로 전체 길이를 30 간격으로 훑어서 교차로 한복판에 가로등이 떠 있었다.
	var inset := 7.0
	var step := 15.0
	var m := 1.2   # 블록 경계에서 인도 쪽으로 밀어넣는 양
	var edges := [
		# [시작, 끝, 고정축 값, 세로축인가]
		[r.position.x + inset, r.position.x + r.size.x - inset, r.position.y - m, false],
		[r.position.x + inset, r.position.x + r.size.x - inset, r.position.y + r.size.y + m, false],
		[r.position.y + inset, r.position.y + r.size.y - inset, r.position.x - m, true],
		[r.position.y + inset, r.position.y + r.size.y - inset, r.position.x + r.size.x + m, true],
	]
	for e in edges:
		var a: float = e[0]
		var b: float = e[1]
		var fixed: float = e[2]
		var vertical: bool = e[3]
		if b - a < step:
			continue
		var n: int = maxi(1, int((b - a) / step))
		for k in n + 1:
			var t: float = a + (b - a) * float(k) / float(n)
			var pos: Vector3 = Vector3(fixed, 0.9, t) if vertical else Vector3(t, 0.9, fixed)
			if k % 2 == 0:
				_lamp(pos)
			elif _rng.randf() < 0.75:
				_tree(pos, 0.72)


func _tree(base: Vector3, scale_f := 1.0) -> void:
	var th: float = _rng.randf_range(4.0, 6.5) * scale_f
	var leaf: float = _rng.randf_range(4.0, 5.6) * scale_f
	var root := _breakable_root(base)
	_part(root, Vector3(0.9, th, 0.9) * scale_f, Vector3(0, th * 0.5, 0), Color(0.42, 0.29, 0.2),
		0.0, Tex.Kind.BARK, 1.1)
	_part(root, Vector3(leaf, leaf, leaf), Vector3(0, th + leaf * 0.38, 0),
		Color(theme["grass"]).darkened(_rng.randf_range(0.05, 0.3)), 0.0, Tex.Kind.LEAF, 0.7)
	_breakable_body(root, Vector3(maxf(1.6, leaf * 0.5), th + leaf, maxf(1.6, leaf * 0.5)),
		Vector3(0, (th + leaf) * 0.5, 0))


# 블록 중심에서 건물이 넘어가면 안 되는 한계는 _lim (블록마다 다름)


func _half_extent(w: float, d: float, yaw: float) -> Vector2:
	# 회전한 박스를 감싸는 축정렬 반지름. 반대각선을 쓰면 과하게 잡혀서 건물이 거의 안 놓인다.
	var co: float = absf(cos(yaw))
	var si: float = absf(sin(yaw))
	return Vector2((w * co + d * si) * 0.5, (w * si + d * co) * 0.5)


func _clamp_in_block(off_x: float, off_z: float, w: float, d: float, yaw: float) -> Vector2:
	# 블록 밖으로 나가면 버리지 말고 안쪽으로 밀어넣는다. 못 들어가면 (INF, INF).
	var h := _half_extent(w, d, yaw)
	if h.x > _lim.x or h.y > _lim.y:
		return Vector2(INF, INF)
	return Vector2(
		clampf(off_x, -(_lim.x - h.x), _lim.x - h.x),
		clampf(off_z, -(_lim.y - h.y), _lim.y - h.y))


func _layout_park(cx: float, cz: float) -> void:
	_box(Vector3(_lim.x * 2.0, 1.1, _lim.y * 2.0), Vector3(cx, 0.55, cz), theme["grass"], false,
		0.0, 0.0, false, Tex.Kind.GRASS, 0.4)
	# 연못
	if _rng.randf() < 0.45:
		_box(Vector3(_lim.x * _rng.randf_range(0.5, 0.9), 1.16, _lim.y * _rng.randf_range(0.4, 0.7)),
			Vector3(cx + _rng.randf_range(-4, 4), 0.58, cz + _rng.randf_range(-4, 4)),
			Color(0.25, 0.62, 0.95, 0.85), false, 0.35)
	for k in _rng.randi_range(4, 7):
		_tree(Vector3(cx + _rng.randf_range(-_lim.x * 0.8, _lim.x * 0.8), 1.1,
			cz + _rng.randf_range(-_lim.y * 0.8, _lim.y * 0.8)))


func _layout_tower(cx: float, cz: float) -> void:
	# 가운데 고층 하나 + 주변 저층
	var hue := _rng.randf()
	var w := _rng.randf_range(18.0, 27.0)
	var d := _rng.randf_range(18.0, 27.0)
	_building(cx, cz, w, d, _rng.randf_range(42.0, 78.0), _rng.randf_range(-0.12, 0.12), hue)
	for k in _rng.randi_range(3, 5):
		var ow := _rng.randf_range(9.0, 16.0)
		var od := _rng.randf_range(9.0, 16.0)
		var oyaw := _rng.randf_range(-0.5, 0.5)
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(17.0, 25.0)
		var pos := _clamp_in_block(cos(ang) * r, sin(ang) * r, ow, od, oyaw)
		if pos.x == INF:
			continue
		_building(cx + pos.x, cz + pos.y, ow, od, _rng.randf_range(7.0, 18.0),
			oyaw, fmod(hue + _rng.randf_range(-0.12, 0.12), 1.0))


func _layout_row(cx: float, cz: float) -> void:
	# 한 축을 따라 폭이 제각각인 건물이 늘어선다
	var along_x := _rng.randf() < 0.5
	var hue := _rng.randf()
	var rows := 1 if _rng.randf() < 0.35 else 2
	for r in rows:
		var n := _rng.randi_range(3, 5)
		var depth: float = _rng.randf_range(16.0, 24.0) if rows == 2 else _rng.randf_range(24.0, 44.0)
		var lane: float = 0.0
		if rows == 2:
			lane = (_lim.y - depth * 0.5) * (-1.0 if r == 0 else 1.0)
		var span: float = (_lim.x if along_x else _lim.y) * 2.0
		var cursor: float = -span * 0.5
		for k in n:
			var slot := span / float(n)
			var size_a: float = slot * _rng.randf_range(0.72, 0.97)
			var center := cursor + slot * 0.5
			cursor += slot
			var w: float = size_a if along_x else depth
			var d: float = depth if along_x else size_a
			var yaw := _rng.randf_range(-0.05, 0.05)
			var ox: float = center if along_x else lane
			var oz: float = lane if along_x else center
			var pos := _clamp_in_block(ox, oz, w, d, yaw)
			if pos.x == INF:
				continue
			_building(cx + pos.x, cz + pos.y, w, d, _rng.randf_range(10.0, 50.0),
				yaw, fmod(hue + _rng.randf_range(-0.1, 0.1), 1.0))


func _layout_cluster(cx: float, cz: float) -> void:
	# 제각각 돌아간 건물이 빽빽하게
	var hue := _rng.randf()
	var tries := _rng.randi_range(8, 13)
	for k in tries:
		var w := _rng.randf_range(9.0, 20.0)
		var d := _rng.randf_range(9.0, 20.0)
		var yaw := _rng.randf_range(-0.45, 0.45)
		var pos := _clamp_in_block(_rng.randf_range(-_lim.x, _lim.x), _rng.randf_range(-_lim.y, _lim.y),
			w, d, yaw)
		if pos.x == INF:
			continue
		_building(cx + pos.x, cz + pos.y, w, d, _rng.randf_range(8.0, 54.0),
			yaw, fmod(hue + _rng.randf_range(-0.18, 0.18), 1.0))


func _layout_plaza(cx: float, cz: float) -> void:
	# 가운데를 비우고 가장자리에만
	var hue := _rng.randf()
	_box(Vector3(_lim.x * 1.1, 1.05, _lim.y * 1.1), Vector3(cx, 0.52, cz), Color(0.78, 0.76, 0.84), false)
	_box(Vector3(_lim.x * 0.35, 1.3, _lim.y * 0.35), Vector3(cx, 0.65, cz),
		Color(theme["grass"]), false)
	for k in _rng.randi_range(4, 6):
		var ang := _rng.randf() * TAU
		var r := _rng.randf_range(19.0, 25.0)
		var w := _rng.randf_range(11.0, 18.0)
		var d := _rng.randf_range(11.0, 18.0)
		var yaw := ang + PI * 0.5
		var pos := _clamp_in_block(cos(ang) * r, sin(ang) * r, w, d, yaw)
		if pos.x == INF:
			continue
		_building(cx + pos.x, cz + pos.y, w, d, _rng.randf_range(9.0, 36.0),
			yaw, fmod(hue + _rng.randf_range(-0.15, 0.15), 1.0))


func _cyl(radius: float, height: float, pos: Vector3, c: Color, segments: int,
		solid := true, emission := 0.0, yaw := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segments
	mi.mesh = cm
	mi.material_override = _mat(c, emission)
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		# 삼각형이면 외접원이 아니라 내접원에 가깝게 잡아야 안 억울하다
		sh.radius = radius * (0.62 if segments == 3 else 0.96)
		sh.height = height
		cs.shape = sh
		body.add_child(cs)
		body.position = pos
		add_child(body)


func _collider(size: Vector3, pos: Vector3) -> void:
	# 메시 없이 충돌체만
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = pos
	add_child(body)


func _make_props() -> void:
	# 도로 위 삼각뿔 콘 + 소. 치면 날아감.
	for k in 46:
		var p: Vector3 = intersections[_rng.randi() % intersections.size()]
		var off := Vector3(_rng.randf_range(-CELL * 0.4, CELL * 0.4), 0, _rng.randf_range(-6, 6))
		if _rng.randf() < 0.5:
			off = Vector3(off.z, 0, off.x)
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = 1.0
		cm.height = 2.2
		cone.mesh = cm
		cone.material_override = _mat(Color(1.0, 0.45, 0.05), 0.5)
		cone.position = p + off + Vector3(0, 1.1, 0)
		add_child(cone)
		cows.append(cone)

	for k in 16:
		var p2: Vector3 = intersections[_rng.randi() % intersections.size()]
		var base := p2 + Vector3(_rng.randf_range(-CELL * 0.35, CELL * 0.35), 0, _rng.randf_range(-5, 5))
		var cow := Node3D.new()
		cow.position = base + Vector3(0, 2.2, 0)
		add_child(cow)
		_attach_box(cow, Vector3(4.2, 2.2, 2.2), Vector3.ZERO, Color(0.97, 0.97, 0.99))
		_attach_box(cow, Vector3(1.6, 1.6, 1.8), Vector3(2.6, 0.4, 0), Color(0.97, 0.97, 0.99))
		_attach_box(cow, Vector3(1.4, 1.0, 1.4), Vector3(0.4, 1.2, 0.4), Color(0.12, 0.12, 0.16))
		for leg in 4:
			var lx := 1.4 if leg < 2 else -1.4
			var lz := 0.8 if leg % 2 == 0 else -0.8
			_attach_box(cow, Vector3(0.5, 2.2, 0.5), Vector3(lx, -2.0, lz), Color(0.2, 0.2, 0.24))
		cows.append(cow)


func _make_bounds() -> void:
	var span := GRID * CELL + ROAD * 2.0
	var half := span * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.85, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.2, 0.85)
	mat.emission_energy_multiplier = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var walls := [
		[Vector3(span, 46.0, 3.0), Vector3(0, 23.0, -half)],
		[Vector3(span, 46.0, 3.0), Vector3(0, 23.0, half)],
		[Vector3(3.0, 46.0, span), Vector3(-half, 23.0, 0)],
		[Vector3(3.0, 46.0, span), Vector3(half, 23.0, 0)],
	]
	var neon := StandardMaterial3D.new()
	neon.albedo_color = Color(1.0, 0.25, 0.9)
	neon.emission_enabled = true
	neon.emission = Color(1.0, 0.25, 0.9)
	neon.emission_energy_multiplier = 2.6
	for w in walls:
		var size: Vector3 = w[0]
		var pos: Vector3 = w[1]
		var vis_h := 7.0
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x, vis_h, size.z)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(pos.x, vis_h * 0.5, pos.z)
		add_child(mi)
		var bar := MeshInstance3D.new()
		var bbm := BoxMesh.new()
		bbm.size = Vector3(maxf(size.x, 1.2), 0.6, maxf(size.z, 1.2))
		bar.mesh = bbm
		bar.material_override = neon
		bar.position = Vector3(pos.x, vis_h, pos.z)
		add_child(bar)
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)
		body.position = pos
		add_child(body)


func _attach_box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)


func random_point() -> Vector3:
	return intersections[_rng.randi() % intersections.size()]


func spawn_spot(player: Vector3, others: Array, min_player := 110.0, min_other := 60.0) -> Vector3:
	# 같은 자리에 겹쳐 스폰되면 서로를 밀어내는 물리 복원이 수직으로 걸려서
	# 지면을 뚫고 내려가고, 그대로 굳는다. 보이지 않는 트럭이 레이더에만 남는다.
	# 그래서 플레이어와 다른 트럭 모두에게서 떨어진 교차로를 고른다.
	var best := random_point()
	var best_score := -INF
	for attempt in 80:
		var p := random_point()
		var dp := p.distance_to(player)
		var do_ := INF
		for o in others:
			do_ = minf(do_, p.distance_to(o))
		if dp >= min_player and do_ >= min_other:
			return p
		var score: float = minf(dp, do_)
		if score > best_score:
			best_score = score
			best = p
	return best


func point_near(center: Vector3, radius: float) -> Vector3:
	# 자기장 안쪽 교차로. 없으면 그냥 가장 가까운 곳.
	var best := Vector3.ZERO
	var best_d := INF
	var inside: Array[Vector3] = []
	for p in intersections:
		var d: float = Vector2(p.x, p.z).distance_to(Vector2(center.x, center.z))
		if d <= radius:
			inside.append(p)
		if d < best_d:
			best_d = d
			best = p
	if inside.is_empty():
		return best
	return inside[_rng.randi() % inside.size()]


func point_in_circle(center: Vector3, radius: float, origin: Vector3, min_dist: float,
		center2: Vector3 = Vector3.ZERO, radius2: float = -1.0) -> Vector3:
	# 원 안쪽 교차로 중에서 origin 과 충분히 떨어진 곳. 자기장 안에만 목적지를 잡을 때 쓴다.
	# center2/radius2 를 주면 두 원이 겹치는 곳만 고른다(지금 자기장 ∩ 다음 자기장).
	var both: Array[Vector3] = []
	var both_far: Array[Vector3] = []
	var inside: Array[Vector3] = []
	var far: Array[Vector3] = []
	var c1 := Vector2(center.x, center.z)
	var c2 := Vector2(center2.x, center2.z)
	for p in intersections:
		var fp := Vector2(p.x, p.z)
		if fp.distance_to(c1) > radius:
			continue
		var is_far: bool = p.distance_to(origin) > min_dist
		inside.append(p)
		if is_far:
			far.append(p)
		if radius2 > 0.0 and fp.distance_to(c2) <= radius2:
			both.append(p)
			if is_far:
				both_far.append(p)
	for pool in [both_far, both, far, inside]:
		if not pool.is_empty():
			return pool[_rng.randi() % pool.size()]
	# 원이 교차로 사이에 끼어 아무것도 안 걸리면 가장 가까운 교차로로 떨어진다.
	return point_near(center, radius)


func point_far_from(origin: Vector3, min_dist: float) -> Vector3:
	for attempt in 40:
		var p := random_point()
		if p.distance_to(origin) > min_dist:
			return p
	return random_point()
