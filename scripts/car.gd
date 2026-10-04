extends CharacterBody3D
class_name Car

signal crashed(force: float)
signal bumped(force: float)
signal scraped()
signal landed(force: float, hang: float)
signal drift_boosted(tier: int, charge: float, secs: float)

const REVERSE_SPEED := -16.0
const ACCEL := 30.0
const BRAKE := 60.0
const FRICTION := 14.0
const GRAVITY := 38.0
const STEP_HEIGHT := 1.15   # 인도 턱(0.9)을 속도와 무관하게 올라탄다

const BASE_MAX_SPEED := 44.0
const BASE_BOOST_SPEED := 68.0
const BASE_TURN_RATE := 2.5
const BASE_JUMP_FORCE := 17.0
const BASE_BOOST_DRAIN := 34.0
const BASE_BOOST_REGEN := 9.0

# 업그레이드로 바뀌는 값들
var max_speed := BASE_MAX_SPEED
var boost_speed := BASE_BOOST_SPEED
var turn_rate := BASE_TURN_RATE
var jump_force := BASE_JUMP_FORCE
var boost_drain := BASE_BOOST_DRAIN
var boost_regen := BASE_BOOST_REGEN
var crash_shield := 0.0  # 0~0.9, 충돌 페널티 감소율
var mod_speed := 1.0     # 주문 유형에 따른 일시 배율
var mod_turn := 1.0
var mod_grip := 1.0     # 1.0 = 접지 완전. 낮을수록 진행 방향이 차 방향을 늦게 따라간다
var _move_dir := Vector3.ZERO

var speed := 0.0
var boost_fuel := 100.0
var boosting := false
var airborne := false
var air_time := 0.0
var spin := Vector3.ZERO
var crash_cooldown := 0.0
var bump_cooldown := 0.0
var scrape_time := 0.0
var scrape_cooldown := 0.0
var honking := false
var auto_drive := false  # 디버그/데모 자동주행
var last_input := {}
var jumped_once := false
var steps_taken := 0
var step_cooldown := 0.0
var step_enabled := true

var _pivot: Node3D
var _cockpit: Node3D          # 1인칭 전용 핸들·계기판. _pivot 밖에 둔다
var _wheel: Node3D
var _needle_speed: Node3D
var _needle_fuel: Node3D

# ---- 드리프트
const DRIFT_GRIP := 0.30        # 드리프트 중 접지. 낮을수록 많이 흐른다
const DRIFT_TURN := 1.40        # 드리프트 중 조향 배수
const DRIFT_MAX_ANGLE := 52.0   # 이 각을 넘으면 접지가 살아난다. 안 그러면 팽이가 된다
const DRIFT_MIN_SPEED := 13.0   # 이 속도 밑에서는 그냥 핸드브레이크
const DRIFT_CHARGE_MAX := 100.0
const DRIFT_TIERS := [30.0, 62.0, 100.0]        # 파랑 / 주황 / 보라
const DRIFT_BOOST_SECS := [1.1, 1.9, 2.9]
var drifting := false
var drift_charge := 0.0
var drift_tier := 0
var drift_boost_time := 0.0
var drift_secs := 0.0           # 이번 드리프트를 얼마나 물고 있었나
var drifts_done := 0
var _sparks: Array[MeshInstance3D] = []
var debug_input := {}   # 비어 있지 않으면 이걸 입력으로 쓴다 (자동 테스트용)
var _lean := 0.0
var _pitch := 0.0
var _squash := 1.0
var _audio: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0            # 크랭크 회전 위상 0~1

# ---- 엔진 합성
const SND_RATE := 32000.0
const IDLE_RPM := 850.0
const MAX_RPM := 6200.0
# 변속 구간. 속도 비율이 이 경계를 넘을 때마다 rpm 이 아래로 떨어진다 = 변속감.
const GEARS := [0.15, 0.29, 0.45, 0.63, 0.82, 1.0]
# 4기통은 실린더마다 압축이 조금씩 다르다. 이 불균일이 '엔진 소리' 를 만든다.
const CYL_GAIN := [1.0, 0.88, 1.06, 0.93]
var _rpm := IDLE_RPM
var _lp := 0.0               # 배기 머플러 역할 1차 저역통과
var _noise_lp := 0.0
var _turbo_phase := 0.0
var _horn_phase := 0.0
var _bounce_phase := 0.0     # 최고단 끝에서 바늘이 깐닥거리는 흔들림
var _fire_count := 0         # 몇 번째 실린더가 터졌는지
var _last_fp := 0.0
# 블록마다 값이 툭툭 튀면 '걸리는' 소리가 난다. 전부 부드럽게 따라가게 둔다.
var _s_load := 0.0
var _s_cut := 0.12
var _s_vol := 0.12
var _s_noise := 0.1
var _s_turbo := 0.0
var _spool := 0.0            # 터보가 감기는 정도 0~1. 밟자마자 최고 회전이 아니다
var _bov_t := -1.0           # 블로우오프 밸브 '츄' 남은 시간
var _was_boosting := false
var _whine_phase := 0.0
var _crackle := 0.0
var _snd_rng := RandomNumberGenerator.new()
# 샘플마다 sin() 을 8번 부르면 32kHz × 60fps 에서 프레임이 튄다.
# 파형을 1024칸 테이블로 한 번만 구워두고 색인으로 읽는다.
const WT := 1024
static var _wt_tone: PackedFloat32Array
static var _wt_sin: PackedFloat32Array


static func _build_tables() -> void:
	if not _wt_tone.is_empty():
		return
	_wt_tone.resize(WT)
	_wt_sin.resize(WT)
	for k in WT:
		var th: float = float(k) / float(WT) * TAU
		_wt_sin[k] = sin(th)
		# 점화 펄스의 배음 구성. 사인 하나만 쓰면 피리 소리가 난다.
		_wt_tone[k] = (sin(th) + sin(th * 2.0) * 0.62 + sin(th * 3.0) * 0.44
			+ sin(th * 4.0) * 0.30 + sin(th * 5.0) * 0.19 + sin(th * 6.0) * 0.12)


static func _wave(tbl: PackedFloat32Array, ph: float) -> float:
	return tbl[int(ph * float(WT)) & (WT - 1)]


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 1.6, 4.6)
	shape.shape = bs
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	_pivot = Node3D.new()
	add_child(_pivot)
	_build_body()
	_build_cockpit()
	for i in 2:
		var sp := MeshInstance3D.new()
		var bm4 := BoxMesh.new()
		bm4.size = Vector3(0.3, 0.3, 1.1)
		sp.mesh = bm4
		var sm := _mat(Color(0.35, 0.75, 1.0), 3.0)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color.a = 0.8
		sp.material_override = sm
		sp.position = Vector3(1.25 if i == 0 else -1.25, 0.45, -2.3)
		sp.visible = false
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pivot.add_child(sp)
		_sparks.append(sp)
	_setup_audio()
	floor_max_angle = deg_to_rad(52)


func _mat(c: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	m.metallic = 0.25
	# 차도 민무늬 단색이면 도시 안에서 혼자 매끈해 보인다. 얇은 철판 결을 깔아준다.
	m.albedo_texture = Tex.get_tex(Tex.Kind.METAL)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.4, 1.4, 1.4)
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m


func _box(size: Vector3, pos: Vector3, c: Color, parent: Node3D, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, emission)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_body() -> void:
	var red := Color(1.0, 0.22, 0.28)
	_box(Vector3(2.4, 0.9, 4.6), Vector3(0, 0.75, 0), red, _pivot)
	_box(Vector3(2.0, 0.9, 2.0), Vector3(0, 1.6, 0.2), Color(0.15, 0.85, 1.0), _pivot)
	# 배달통
	var boxm := _box(Vector3(1.8, 1.6, 1.8), Vector3(0, 2.1, -1.7), Color(1.0, 0.78, 0.1), _pivot)
	boxm.name = "DeliveryBox"
	_box(Vector3(1.9, 0.25, 1.9), Vector3(0, 2.95, -1.7), Color(0.95, 0.35, 0.05), _pivot)
	# 헤드라이트
	_box(Vector3(0.6, 0.35, 0.25), Vector3(0.8, 0.8, 2.35), Color(1.0, 1.0, 0.7), _pivot, 2.0)
	_box(Vector3(0.6, 0.35, 0.25), Vector3(-0.8, 0.8, 2.35), Color(1.0, 1.0, 0.7), _pivot, 2.0)
	# 후미등
	_box(Vector3(0.5, 0.3, 0.25), Vector3(0.85, 0.8, -2.35), Color(1.0, 0.1, 0.1), _pivot, 1.6)
	_box(Vector3(0.5, 0.3, 0.25), Vector3(-0.85, 0.8, -2.35), Color(1.0, 0.1, 0.1), _pivot, 1.6)
	# 바퀴
	for i in 4:
		var wx := 1.25 if i % 2 == 0 else -1.25
		var wz := 1.5 if i < 2 else -1.5
		var w := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.6
		cm.bottom_radius = 0.6
		cm.height = 0.45
		w.mesh = cm
		w.material_override = _mat(Color(0.1, 0.1, 0.13))
		w.rotation_degrees = Vector3(0, 0, 90)
		w.position = Vector3(wx, 0.55, wz)
		_pivot.add_child(w)


func _build_cockpit() -> void:
	# _pivot 에 붙이면 1인칭에서 차체를 숨길 때 같이 사라지고, 차체 스쿼시에 같이 찌그러진다.
	# 그래서 차 노드에 직접 단다.
	_cockpit = Node3D.new()
	_cockpit.visible = false
	add_child(_cockpit)

	var dash_col := Color(0.12, 0.12, 0.16)
	# 대시보드 상판. 눈높이(2.4)보다 한참 아래에 둬야 시야를 안 잡아먹는다.
	_box(Vector3(2.2, 0.20, 1.0), Vector3(0, 1.60, -1.55), dash_col, _cockpit)
	# 계기판 하우징. 핸들 구멍으로 들여다보이는 위치.
	_box(Vector3(0.92, 0.42, 0.14), Vector3(0, 2.02, -1.38), Color(0.06, 0.06, 0.08), _cockpit)
	# 대시 조명 띠. 밤에 이거 하나로 실내 분위기가 산다.
	_box(Vector3(1.9, 0.05, 0.05), Vector3(0, 1.71, -1.10), Color(0.2, 0.9, 1.0), _cockpit, 2.0)

	# 계기 2개. 원판은 납작한 실린더.
	_needle_speed = _gauge(Vector3(-0.22, 2.02, -1.30), Color(0.25, 1.0, 0.55))
	_needle_fuel = _gauge(Vector3(0.22, 2.02, -1.30), Color(1.0, 0.75, 0.2))

	# 핸들
	_wheel = Node3D.new()
	_wheel.position = Vector3(0, 1.93, -1.02)
	_wheel.rotation_degrees = Vector3(-24, 0, 0)   # 운전자 쪽으로 눕힌다
	_cockpit.add_child(_wheel)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.26
	tm.outer_radius = 0.33
	tm.rings = 20
	tm.ring_segments = 8
	rim.mesh = tm
	rim.material_override = _mat(Color(0.09, 0.09, 0.11))
	# TorusMesh 는 XZ 평면에 눕혀 나온다. 핸들은 세워야 한다.
	rim.rotation_degrees = Vector3(90, 0, 0)
	_wheel.add_child(rim)
	for i in 3:
		var spoke := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.30, 0.07, 0.05)
		spoke.mesh = bm2
		spoke.material_override = _mat(Color(0.7, 0.16, 0.22))
		spoke.position = Vector3(cos(TAU * i / 3.0), sin(TAU * i / 3.0), 0.0) * 0.16
		spoke.rotation.z = TAU * i / 3.0
		_wheel.add_child(spoke)
	# 가운데 경적 패드
	_box(Vector3(0.13, 0.13, 0.06), Vector3(0, 0, 0.02), Color(0.85, 0.2, 0.26), _wheel, 0.6)


func _gauge(pos: Vector3, col: Color) -> Node3D:
	var face := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.16
	cm.height = 0.03
	cm.radial_segments = 16
	face.mesh = cm
	face.material_override = _mat(Color(0.10, 0.12, 0.18), 0.8)
	face.rotation_degrees = Vector3(90, 0, 0)
	face.position = pos
	_cockpit.add_child(face)
	# 바늘은 별도 노드. 회전축이 원판 중심이어야 한다.
	var pivot := Node3D.new()
	pivot.position = pos + Vector3(0, 0, 0.03)
	_cockpit.add_child(pivot)
	var nd := MeshInstance3D.new()
	var bm3 := BoxMesh.new()
	bm3.size = Vector3(0.025, 0.15, 0.02)
	nd.mesh = bm3
	nd.material_override = _mat(col, 2.2)
	nd.position = Vector3(0, 0.07, 0)
	pivot.add_child(nd)
	return pivot


func set_cockpit_visible(on: bool) -> void:
	_cockpit.visible = on


func _setup_audio() -> void:
	_audio = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SND_RATE
	gen.buffer_length = 0.2
	_audio.stream = gen
	_audio.volume_db = -11.0
	add_child(_audio)
	_audio.play()
	_playback = _audio.get_stream_playback() as AudioStreamGeneratorPlayback
	_snd_rng.seed = 20260926
	_build_tables()


func read_input() -> Dictionary:
	if not debug_input.is_empty():
		return debug_input
	var throttle := 0.0
	var steer := 0.0
	if auto_drive:
		var t := Time.get_ticks_msec() / 1000.0
		return {
			"throttle": 0.22 if fmod(t, 11.0) < 5.0 else 1.0,
			"steer": sin(t * 0.55) * 0.75,
			"jump": fmod(t, 5.0) < 0.1,
			"boost": fmod(t, 7.0) < 2.0,
			"horn": false,
			"drift": fmod(t, 9.0) < 2.4,
		}
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		throttle -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		steer += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		steer -= 1.0
	var jump := Input.is_key_pressed(KEY_SPACE)
	var boost := Input.is_key_pressed(KEY_E)
	var horn := Input.is_key_pressed(KEY_H)
	var drift := Input.is_key_pressed(KEY_SHIFT)

	# 게임패드
	if Input.get_connected_joypads().size() > 0:
		var pad: int = Input.get_connected_joypads()[0]
		var ax := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		if absf(ax) > 0.18:
			steer += ax
		var rt := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT)
		var lt := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT)
		throttle += rt - lt
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_A):
			jump = true
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_X):
			boost = true
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_B):
			horn = true
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_SHOULDER) \
				or Input.is_joy_button_pressed(pad, JOY_BUTTON_RIGHT_SHOULDER):
			drift = true

	return {
		"throttle": clampf(throttle, -1.0, 1.0),
		"steer": clampf(steer, -1.0, 1.0),
		"jump": jump,
		"boost": boost,
		"horn": horn,
		"drift": drift,
	}


func _process(_delta: float) -> void:
	# 물리 프레임에서만 채우면 메뉴(물리 정지)나 프레임이 떨어질 때 버퍼가 말라 '툭' 끊긴다.
	# 빈 자리만큼만 채우므로 두 군데서 불러도 총 작업량은 같다.
	_update_audio()


func _physics_process(delta: float) -> void:
	var inp := read_input()
	last_input = inp
	crash_cooldown = maxf(0.0, crash_cooldown - delta)
	bump_cooldown = maxf(0.0, bump_cooldown - delta)
	scrape_cooldown = maxf(0.0, scrape_cooldown - delta)
	step_cooldown = maxf(0.0, step_cooldown - delta)
	honking = inp["horn"]

	_tick_drift(delta, inp)
	boosting = inp["boost"] and boost_fuel > 0.0 and speed > 4.0
	if boosting:
		boost_fuel = maxf(0.0, boost_fuel - boost_drain * delta)
	else:
		boost_fuel = minf(100.0, boost_fuel + boost_regen * delta)

	var top: float = (boost_speed if boosting else max_speed) * mod_speed
	if drift_boost_time > 0.0:
		# 드리프트 부스터는 부스터보다 한 뼘 더 나간다. 겹치면 더 나간다.
		top = maxf(top, boost_speed * mod_speed * 1.16)
	var throttle: float = inp["throttle"]

	if throttle > 0.01:
		var power: float = ACCEL * (2.1 if boosting else 1.0)
		if drift_boost_time > 0.0:
			power *= 2.4
		speed = move_toward(speed, top * throttle, power * delta)
	elif throttle < -0.01:
		if speed > 1.0:
			speed = move_toward(speed, 0.0, BRAKE * delta)
		else:
			speed = move_toward(speed, REVERSE_SPEED * absf(throttle), ACCEL * 0.7 * delta)
	else:
		speed = move_toward(speed, 0.0, FRICTION * delta)

	# 조향 (속도에 비례, 후진 시 반전)
	var grip: float = clampf(absf(speed) / 13.0, 0.0, 1.0)
	var turn_mult: float = DRIFT_TURN if drifting else 1.0
	var steer_amount: float = -inp["steer"] * turn_rate * mod_turn * turn_mult * grip * signf(speed) * delta
	if not airborne:
		rotate_y(steer_amount)
	else:
		rotate_y(steer_amount * 0.35)

	var fwd := -global_transform.basis.z
	# 접지가 나쁘면 진행 방향이 차 방향을 천천히 따라간다 = 미끄러진다
	if _move_dir.length() < 0.01:
		_move_dir = fwd
	var grip_f: float = mod_grip
	if drifting:
		grip_f = minf(mod_grip, DRIFT_GRIP)
		# 각이 벌어질수록 접지를 되살린다. 안 그러면 그냥 제자리 팽이가 된다.
		var ang_now := slide_angle()
		if ang_now > DRIFT_MAX_ANGLE:
			grip_f = lerpf(grip_f, 1.0, clampf((ang_now - DRIFT_MAX_ANGLE) / 26.0, 0.0, 1.0))
	if grip_f >= 0.999 or airborne:
		_move_dir = fwd
	else:
		var rate: float = clampf(14.0 * grip_f * delta, 0.0, 1.0)
		_move_dir = _move_dir.slerp(fwd, rate).normalized()
	var horizontal := _move_dir * speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y -= GRAVITY * delta

	if is_on_floor():
		if airborne:
			var force: float = absf(velocity.y)
			airborne = false
			_squash = clampf(1.0 - force * 0.016, 0.45, 1.0)
			if air_time > 0.35:
				landed.emit(force, air_time)
			air_time = 0.0
			spin = Vector3.ZERO
		velocity.y = maxf(velocity.y, -1.0)
		if inp["jump"]:
			velocity.y = jump_force
			jumped_once = true
			airborne = true
			spin = Vector3(randf_range(-4.0, 4.0), 0, randf_range(-5.0, 5.0))
	else:
		airborne = true
		air_time += delta

	var before := speed
	move_and_slide()

	# 충돌 = 똥겜의 꽃. 정면으로 들이받은 정도에 따라 3단계로 나뉜다.
	# 먼저 '수직 벽에 막혔는가' 를 판정한다. 바닥 접촉(n.y ~ 1)은 여기서 걸러진다.
	var wall_hit := false
	var impact := 0.0
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if absf(n.y) < 0.6:
			wall_hit = true
			impact = maxf(impact, absf(before) * clampf(-fwd.dot(n), 0.0, 1.0))

	# 턱 올라타기는 '벽에 정면으로 막혔을 때만' 시도한다.
	# 예전엔 바닥 접촉까지 포함해서 평지에서도 매 프레임 튀어올랐다.
	var stepped := false
	if wall_hit and impact > 0.3 and step_cooldown <= 0.0:
		stepped = _try_step_up(horizontal)
		if stepped:
			steps_taken += 1
			step_cooldown = 0.3   # 연속으로 계단 타고 올라가는 것 방지
			wall_hit = false
			impact = 0.0
			scrape_time = 0.0

	if wall_hit:
		if impact > 15.0 and crash_cooldown <= 0.0:
			# 대형사고: 튕겨나가고 공중제비
			speed = -before * 0.32
			velocity.y = maxf(velocity.y, impact * 0.34)
			airborne = true
			spin = Vector3(randf_range(-7, 7), randf_range(-3, 3), randf_range(-9, 9))
			crash_cooldown = 0.45
			bump_cooldown = 1.0
			scrape_time = 0.0
			crashed.emit(impact)
		elif impact > 1.5 and bump_cooldown <= 0.0 and crash_cooldown <= 0.0:
			# 살짝 긁음: 튕기지 않고 속도만 깎이고 잔소리만 듣는다
			speed = before * (0.88 if impact < 6.0 else 0.62)
			bump_cooldown = 0.75
			scrape_time = 0.0
			bumped.emit(impact)
		elif absf(speed) > 5.0:
			# 벽에 비비면서 계속 달리는 중
			scrape_time += delta
			if scrape_time > 0.8 and scrape_cooldown <= 0.0:
				scrape_time = 0.0
				scrape_cooldown = 3.5
				scraped.emit()
	else:
		scrape_time = maxf(0.0, scrape_time - delta * 2.0)

	_update_visual(delta, inp)
	_update_audio()


func drift_tier_of(charge: float) -> int:
	# 0 = 부스터 없음, 1~3 = 파랑/주황/보라
	var t := 0
	for i in DRIFT_TIERS.size():
		if charge >= float(DRIFT_TIERS[i]) - 0.001:
			t = i + 1
	return t


func drift_color(tier: int) -> Color:
	match tier:
		1: return Color(0.35, 0.75, 1.0)
		2: return Color(1.0, 0.6, 0.15)
		3: return Color(0.8, 0.35, 1.0)
		_: return Color(0.75, 0.75, 0.8)


func _tick_drift(delta: float, inp: Dictionary) -> void:
	drift_boost_time = maxf(0.0, drift_boost_time - delta)
	var want: bool = bool(inp["drift"]) and not airborne and absf(speed) > DRIFT_MIN_SPEED
	if want:
		drifting = true
		drift_secs += delta
		# 차 방향과 실제 진행 방향이 벌어진 만큼 차징된다. 직진으로 붙잡고만 있으면 안 찬다.
		var ang: float = minf(slide_angle(), DRIFT_MAX_ANGLE)
		if ang > 7.0:
			var gain: float = (ang / DRIFT_MAX_ANGLE) * (absf(speed) / max_speed) * 56.0
			drift_charge = minf(DRIFT_CHARGE_MAX, drift_charge + gain * delta)
		drift_tier = drift_tier_of(drift_charge)
	elif drifting:
		# 손을 뗀 순간 정산
		drifting = false
		var tier := drift_tier_of(drift_charge)
		if tier > 0:
			var secs: float = float(DRIFT_BOOST_SECS[tier - 1])
			drift_boost_time = secs
			drifts_done += 1
			speed = maxf(speed, max_speed * (0.9 + 0.12 * tier))
			drift_boosted.emit(tier, drift_charge, drift_secs)
		drift_charge = 0.0
		drift_tier = 0
		drift_secs = 0.0
	_update_sparks()


func _update_sparks() -> void:
	if _sparks.is_empty():
		return
	var on: bool = drifting and drift_tier > 0
	var col := drift_color(drift_tier)
	for sp in _sparks:
		sp.visible = on or drift_boost_time > 0.0
		if not sp.visible:
			continue
		var c: Color = col if on else Color(1.0, 0.95, 0.5)
		var m := sp.material_override as StandardMaterial3D
		m.albedo_color = c
		m.emission = c
		var pulse: float = 0.7 + 0.5 * absf(sin(Time.get_ticks_msec() * 0.03))
		sp.scale = Vector3(pulse, pulse, 1.0 + pulse * (1.6 if drift_boost_time > 0.0 else 0.6))


func _try_step_up(horizontal_vel: Vector3) -> bool:
	if not step_enabled:
		return false
	if airborne or velocity.y > 0.5:
		return false
	var dir := Vector3(horizontal_vel.x, 0.0, horizontal_vel.z)
	if dir.length() < 0.5:
		return false
	dir = dir.normalized()
	var t := global_transform
	# 1) 들어올릴 공간이 있는가
	if test_move(t, Vector3.UP * STEP_HEIGHT):
		return false
	var t_up := Transform3D(t.basis, t.origin + Vector3.UP * STEP_HEIGHT)
	# 2) 올린 높이에서 턱 너머로 갈 수 있는가. 건물이면 여기서 막힌다.
	var probe := dir * 1.3
	if test_move(t_up, probe):
		return false
	# 3) 올려놓을 바닥이 바로 아래에 있는가. 이걸 안 보면 허공이나 지오메트리 안에
	#    올려놓게 되고, 물리 엔진이 밀어내면서 차가 수십 유닛 튀어오른다.
	var t_fwd := Transform3D(t.basis, t_up.origin + probe)
	var land := KinematicCollision3D.new()
	if not test_move(t_fwd, Vector3.DOWN * (STEP_HEIGHT + 0.35), land):
		return false
	# 4) 바닥 바로 위에 놓는다
	global_position = t_fwd.origin + Vector3.DOWN * maxf(land.get_travel().length() - 0.05, 0.0)
	# 턱을 탄 것이지 점프한 게 아니다
	velocity.y = minf(velocity.y, 0.0)
	return true


func _update_visual(delta: float, inp: Dictionary) -> void:
	var grip: float = clampf(absf(speed) / (max_speed * mod_speed), 0.0, 1.0)
	if airborne:
		_pivot.rotation.x += spin.x * delta
		_pivot.rotation.z += spin.z * delta
		_pivot.rotation.y = lerpf(_pivot.rotation.y, 0.0, minf(delta * 3.0, 1.0))
	else:
		var target_lean: float = -inp["steer"] * 0.26 * grip
		_lean = lerpf(_lean, target_lean, minf(delta * 8.0, 1.0))
		var target_pitch: float = -inp["throttle"] * 0.09 * (1.0 - grip * 0.4)
		_pitch = lerpf(_pitch, target_pitch, minf(delta * 6.0, 1.0))
		_pivot.rotation.z = lerp_angle(_pivot.rotation.z, _lean, minf(delta * 10.0, 1.0))
		_pivot.rotation.x = lerp_angle(_pivot.rotation.x, _pitch, minf(delta * 10.0, 1.0))
		_pivot.rotation.y = lerpf(_pivot.rotation.y, 0.0, minf(delta * 6.0, 1.0))

	_squash = lerpf(_squash, 1.0, minf(delta * 6.0, 1.0))
	_pivot.scale = Vector3(1.0 + (1.0 - _squash) * 0.5, _squash, 1.0 + (1.0 - _squash) * 0.3)

	if _cockpit.visible:
		# 핸들은 조향 입력 그대로, 바늘은 속도와 부스터 잔량
		var target_wheel: float = -float(inp["steer"]) * 1.9
		_wheel.rotation.z = lerp_angle(_wheel.rotation.z, target_wheel, minf(delta * 12.0, 1.0))
		var sp_ratio: float = clampf(kmh() / 520.0, 0.0, 1.0)
		_needle_speed.rotation.z = lerpf(2.2, -2.2, sp_ratio)
		_needle_fuel.rotation.z = lerpf(2.2, -2.2, clampf(boost_fuel / 100.0, 0.0, 1.0))

	# 배달통 흔들림
	var box := _pivot.get_node_or_null("DeliveryBox")
	if box:
		var t := Time.get_ticks_msec() / 1000.0
		box.rotation.z = sin(t * 9.0) * 0.06 * grip
		box.rotation.x = cos(t * 7.0) * 0.05 * grip
		box.position.y = 2.1 + sin(t * 13.0) * 0.06 * grip


func engine_rpm() -> float:
	# 속도 비율을 기어 구간으로 쪼개서 rpm 을 만든다.
	# 속도에 비례하는 한 가지 음만 쓰면 사이렌이지 자동차가 아니다.
	var v: float = clampf(absf(speed) / maxf(1.0, max_speed * mod_speed), 0.0, 1.0)
	var low := 0.0
	var high: float = float(GEARS[GEARS.size() - 1])
	for g in GEARS.size():
		if v <= float(GEARS[g]):
			high = float(GEARS[g])
			low = 0.0 if g == 0 else float(GEARS[g - 1])
			break
	var frac: float = 0.0 if high <= low else clampf((v - low) / (high - low), 0.0, 1.0)
	var target: float = IDLE_RPM + frac * (MAX_RPM - IDLE_RPM)
	# 부스터는 rpm(= 음높이)을 올리지 않는다. 터보는 가속을 돕는 물건이지
	# 같은 속도에서 엔진을 더 돌리는 물건이 아니다. 올리면 소리가 붕 뜬다.
	# 대신 최고단 끝에서는 바늘이 리미터에 깐닥거린다.
	if v > 0.985:
		target += sin(_bounce_phase * TAU) * 110.0
	return target


func _update_audio() -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	for f in synth_frames(frames):
		_playback.push_frame(f)


# 소리를 만드는 곳은 여기 하나뿐이다. 오프라인 녹음(enginewav=)도 같은 함수를 쓴다.
# 안 그러면 녹음이 실제 게임 소리를 증명하지 못한다.
func synth_frames(frames: int) -> PackedVector2Array:
	var buf := PackedVector2Array()
	buf.resize(frames)

	_bounce_phase += 7.0 * float(frames) / SND_RATE
	if _bounce_phase >= 1.0:
		_bounce_phase -= 1.0

	# rpm 은 바로 안 따라간다. 즉시 바뀌면 변속할 때 '딱' 하고 끊긴다.
	var target_rpm := engine_rpm()
	var follow: float = 0.22 if target_rpm > _rpm else 0.12
	_rpm = lerpf(_rpm, target_rpm, follow)

	var load: float = clampf(absf(float(last_input.get("throttle", 0.0))), 0.0, 1.0)
	if boosting:
		load = 1.0
	# 블록 경계에서 값이 계단처럼 뛰면 '툭툭 걸리는' 소리가 된다.
	_s_load = lerpf(_s_load, load, 0.18)
	_s_turbo = lerpf(_s_turbo, 1.0 if boosting else 0.0, 0.10)
	# 터보는 밟는 순간 다 감기지 않는다. 0.8초쯤 걸려 올라가고 뗄 때는 빨리 빠진다.
	var dt: float = float(frames) / SND_RATE
	_spool = move_toward(_spool, 1.0 if boosting else 0.0, dt * (1.3 if boosting else 2.6))
	# 뗄 때 블로우오프 밸브가 '츄' 하고 터진다. 부스터를 쓴 티가 제일 크게 나는 소리다.
	if _was_boosting and not boosting and _spool > 0.35:
		_bov_t = 0.38
	_was_boosting = boosting
	if _bov_t > 0.0:
		_bov_t = maxf(0.0, _bov_t - dt)
	var rev: float = clampf((_rpm - IDLE_RPM) / (MAX_RPM - IDLE_RPM), 0.0, 1.0)

	# 4행정 4기통: 크랭크 1회전에 2번 점화
	var crank_hz: float = _rpm / 60.0
	var turbo_hz: float = crank_hz * 11.0
	# 스로틀을 닫으면 머플러에 먹혀 먹먹해진다
	# 부스터를 켜면 배기가 트이면서 고역이 살아난다
	_s_cut = lerpf(_s_cut, 0.10 + _s_load * 0.34 + rev * 0.14 + _spool * 0.16, 0.2)
	_s_noise = lerpf(_s_noise,
		(0.10 + _s_load * 0.26 + _s_turbo * 0.14) * (0.4 + rev * 0.9), 0.2)
	var want_vol: float = 0.12 + rev * 0.26 + _s_load * 0.08 + _spool * 0.10
	if airborne:
		# 바퀴가 떴으면 부하가 없다. 공회전처럼 가볍게 돈다.
		want_vol *= 0.8
	_s_vol = lerpf(_s_vol, want_vol, 0.2)
	var cutoff := _s_cut
	var noise_amt := _s_noise
	var vol := _s_vol

	for i in frames:
		_phase += crank_hz / SND_RATE
		if _phase >= 1.0:
			_phase -= 1.0

		# 한 크랭크 회전 안의 점화 2번. 실린더마다 세기가 다르다.
		var fire := _phase * 2.0
		var fp: float = fire - floor(fire)
		if fp < _last_fp:
			_fire_count += 1       # 점화가 한 번 끝났다
		_last_fp = fp
		var gain: float = float(CYL_GAIN[_fire_count & 3])

		# 점화 펄스 (구워둔 배음 테이블)
		var tone: float = _wave(_wt_tone, fp) * gain
		# 배기관 울림: 반 옥타브 아래 저음을 섞어 배기음을 묵직하게
		tone += _wave(_wt_sin, _phase) * 0.55

		# 흡기·배기 소음
		var n: float = _snd_rng.randf_range(-1.0, 1.0)
		_noise_lp += (n - _noise_lp) * 0.16
		tone += _noise_lp * noise_amt * 3.4

		# 터보. 엔진 음높이는 안 건드리고 위에 세 가지를 얹는다.
		if _spool > 0.004 or _bov_t > 0.0:
			# 1) 스풀 휘파람. 감길수록 높아진다. 살짝 어긋난 두 음이라 더 쇳소리가 난다.
			_turbo_phase += (turbo_hz * (0.55 + _spool * 0.75)) / SND_RATE
			if _turbo_phase >= 1.0:
				_turbo_phase -= 1.0
			_whine_phase += (turbo_hz * (0.55 + _spool * 0.75) * 1.007) / SND_RATE
			if _whine_phase >= 1.0:
				_whine_phase -= 1.0
			var whine: float = (_wave(_wt_sin, _turbo_phase)
				+ _wave(_wt_sin, _whine_phase) * 0.7
				+ _wave(_wt_sin, _turbo_phase * 2.0) * 0.3)
			tone += whine * 0.30 * _spool * (0.35 + rev * 0.8)

			# 2) 흡기 바람소리. 저역통과를 뺀 나머지(고역)를 쓴다.
			tone += (n - _noise_lp) * 0.55 * _spool

			# 3) 블로우오프 '츄'. 짧고 세게 터졌다가 꺼진다.
			if _bov_t > 0.0:
				var env: float = _bov_t / 0.38
				tone += (n - _noise_lp) * 2.6 * env * env
				tone += _wave(_wt_sin, _turbo_phase) * 0.5 * env

			# 4) 가끔 터지는 애프터파이어
			if _spool > 0.6 and _snd_rng.randf() < 0.00012:
				_crackle = 1.0
		if _crackle > 0.0:
			_crackle = maxf(0.0, _crackle - 90.0 / SND_RATE)
			tone += n * 1.8 * _crackle * _crackle

		# 연료를 끊어 털털거리는 하드 리미터는 뺐다.
		# 최고 속도에서 계속 터져서 소리가 '걸리는' 느낌의 주범이었다.
		# 대신 engine_rpm() 에서 바늘만 7Hz 로 깐닥거린다.
		var raw: float = tone * vol
		# soft clip. 그냥 자르면 지직거린다.
		raw = raw / (1.0 + absf(raw) * 0.8)
		_lp += (raw - _lp) * cutoff
		var out: float = _lp

		if honking:
			# 경적은 2음 화음. 한 음만 쓰면 삐 소리가 난다.
			_horn_phase += 1.0 / SND_RATE
			if _horn_phase >= 1.0:
				_horn_phase -= 1.0
			var a: float = _horn_phase * 440.0
			var b: float = _horn_phase * 554.37
			var horn: float = (_wave(_wt_sin, a) + _wave(_wt_sin, a * 2.0) * 0.5
				+ _wave(_wt_sin, a * 3.0) * 0.28 + _wave(_wt_sin, b)
				+ _wave(_wt_sin, b * 2.0) * 0.5 + _wave(_wt_sin, b * 3.0) * 0.28) * 0.14
			out = out * 0.35 + horn

		# 좌우를 살짝 다르게 해서 폭을 준다
		buf[i] = Vector2(out, out * 0.94 + _noise_lp * noise_amt * 0.25)
	return buf


func apply_upgrades(lv: Dictionary) -> void:
	var engine: int = lv.get("engine", 0)
	var boost: int = lv.get("boost", 0)
	var tire: int = lv.get("tire", 0)
	var rocket: int = lv.get("rocket", 0)
	var pack: int = lv.get("pack", 0)

	max_speed = BASE_MAX_SPEED + engine * 5.0
	boost_speed = BASE_BOOST_SPEED + engine * 7.0 + boost * 5.0
	turn_rate = BASE_TURN_RATE + tire * 0.45
	jump_force = BASE_JUMP_FORCE + rocket * 4.5
	boost_regen = BASE_BOOST_REGEN + boost * 6.0
	boost_drain = BASE_BOOST_DRAIN * pow(0.8, boost)
	crash_shield = clampf(pack * 0.3, 0.0, 0.9)
	_restyle(lv)


func _restyle(lv: Dictionary) -> void:
	# 스포일러
	var spoiler := _pivot.get_node_or_null("Spoiler")
	if lv.get("engine", 0) >= 1 and spoiler == null:
		var sp := _box(Vector3(2.4, 0.22, 0.7), Vector3(0, 2.0, -2.2), Color(0.12, 0.12, 0.16), _pivot)
		sp.name = "Spoiler"
		_box(Vector3(0.25, 0.9, 0.3), Vector3(0.9, 1.6, -2.2), Color(0.12, 0.12, 0.16), _pivot)
		_box(Vector3(0.25, 0.9, 0.3), Vector3(-0.9, 1.6, -2.2), Color(0.12, 0.12, 0.16), _pivot)

	# 네온 언더글로우
	var glow := _pivot.get_node_or_null("Underglow")
	if lv.get("boost", 0) >= 1 and glow == null:
		var g := _box(Vector3(2.7, 0.12, 4.9), Vector3(0, 0.22, 0), Color(0.2, 1.0, 1.0), _pivot, 4.0)
		g.name = "Underglow"

	# 로켓 노즐
	var noz := _pivot.get_node_or_null("Nozzle")
	if lv.get("rocket", 0) >= 1 and noz == null:
		var n := _box(Vector3(0.7, 0.7, 0.7), Vector3(0.7, 0.35, -2.5), Color(1.0, 0.55, 0.1), _pivot, 3.0)
		n.name = "Nozzle"
		_box(Vector3(0.7, 0.7, 0.7), Vector3(-0.7, 0.35, -2.5), Color(1.0, 0.55, 0.1), _pivot, 3.0)

	# 범퍼
	var bump_g := _pivot.get_node_or_null("Bumper")
	if lv.get("pack", 0) >= 1 and bump_g == null:
		var b := _box(Vector3(2.9, 0.7, 0.6), Vector3(0, 0.6, 2.5), Color(1.0, 0.85, 0.2), _pivot, 0.8)
		b.name = "Bumper"
		_box(Vector3(2.9, 0.7, 0.6), Vector3(0, 0.6, -2.5), Color(1.0, 0.85, 0.2), _pivot, 0.8)

	# 광폭 타이어
	if lv.get("tire", 0) >= 1:
		var scale_f: float = 1.0 + lv.get("tire", 0) * 0.13
		for ch in _pivot.get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is CylinderMesh:
				(ch as MeshInstance3D).scale = Vector3(scale_f, 1.0 + lv.get("tire", 0) * 0.2, scale_f)

	# 방탄 강판
	var armor := _pivot.get_node_or_null("Armor")
	if lv.get("armor", 0) >= 1 and armor == null:
		var ar := Node3D.new()
		ar.name = "Armor"
		_pivot.add_child(ar)
		var steel := Color(0.46, 0.48, 0.54)
		_box(Vector3(0.35, 0.8, 4.4), Vector3(1.3, 0.85, 0), steel, ar)
		_box(Vector3(0.35, 0.8, 4.4), Vector3(-1.3, 0.85, 0), steel, ar)
		_box(Vector3(2.5, 0.35, 0.4), Vector3(0, 1.35, 2.3), steel.darkened(0.15), ar)
		_box(Vector3(2.5, 0.35, 0.4), Vector3(0, 1.35, -2.3), steel.darkened(0.15), ar)

	# 단골 스티커
	var sticker := _pivot.get_node_or_null("Sticker")
	if lv.get("pay", 0) >= 1 and sticker == null:
		var st := _box(Vector3(1.2, 0.5, 0.12), Vector3(0, 2.1, -0.78), Color(1.0, 0.85, 0.15), _pivot, 2.0)
		st.name = "Sticker"

	# 보온가방
	var box := _pivot.get_node_or_null("DeliveryBox") as MeshInstance3D
	if box and lv.get("warm", 0) >= 1:
		box.scale = Vector3.ONE * (1.0 + lv.get("warm", 0) * 0.12)


func set_body_visible(on: bool) -> void:
	# 1인칭에서는 차체가 카메라를 가린다. 통째로 숨긴다.
	_pivot.visible = on


func set_fists(on: bool) -> void:
	var arms := _pivot.get_node_or_null("Fists")
	if on and arms == null:
		var root := Node3D.new()
		root.name = "Fists"
		_pivot.add_child(root)
		var skin := Color(1.0, 0.55, 0.28)
		var glove := Color(0.85, 0.15, 0.2)
		# 양쪽 팔 + 글러브
		_box(Vector3(0.62, 0.5, 2.8), Vector3(1.6, 1.35, 0.1), skin, root, 0.25)
		_box(Vector3(0.62, 0.5, 2.8), Vector3(-1.6, 1.35, 0.1), skin, root, 0.25)
		_box(Vector3(0.9, 0.75, 0.9), Vector3(1.95, 1.32, 1.6), glove, root, 0.6)
		_box(Vector3(0.9, 0.75, 0.9), Vector3(-1.95, 1.32, 1.6), glove, root, 0.6)
	elif not on and arms != null:
		arms.queue_free()


func punch_anim() -> void:
	var arms := _pivot.get_node_or_null("Fists") as Node3D
	if arms == null:
		return
	arms.position.z = 0.0
	var tw := create_tween()
	tw.tween_property(arms, "position:z", 1.5, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(arms, "position:z", 0.0, 0.22).set_ease(Tween.EASE_IN)


func set_pubg_mode(on: bool) -> void:
	var helmet := _pivot.get_node_or_null("HelmetL3")
	if on and helmet == null:
		var h_node := Node3D.new()
		h_node.name = "HelmetL3"
		h_node.position = Vector3(0, 2.35, 0.2)
		_pivot.add_child(h_node)

		var metal := Color(0.24, 0.25, 0.28)
		# 뚝배기 둥근 돔 (헬멧 본체)
		_box(Vector3(2.2, 1.3, 2.3), Vector3(0, 0.4, 0), metal, h_node)
		# 이마 챙
		_box(Vector3(2.3, 0.25, 0.8), Vector3(0, 0.2, 1.25), metal.darkened(0.2), h_node)
		# 측면/후면 귀 가리개
		_box(Vector3(2.35, 0.9, 2.1), Vector3(0, 0.05, -0.2), metal.darkened(0.15), h_node)
		# 용접마스크 페이스 실드 (3렙 뚝배기 특유의 전면 바이저)
		_box(Vector3(1.8, 1.0, 0.4), Vector3(0, 0.0, 1.2), Color(0.12, 0.12, 0.14), h_node)
		# 뚝배기 눈 슬릿 (빛나는 좁은 가로 틈)
		_box(Vector3(1.4, 0.16, 0.45), Vector3(0, 0.15, 1.22), Color(0.2, 0.95, 0.85), h_node, 2.5)
	elif not on and helmet != null:
		helmet.queue_free()


func get_muzzle_pos() -> Vector3:
	return global_position + (-global_transform.basis.z * 2.6) + Vector3(0, 1.2, 0)


func set_cargo_special(on: bool) -> void:
	var box := _pivot.get_node_or_null("DeliveryBox") as MeshInstance3D
	if box == null:
		return
	var m := box.material_override as StandardMaterial3D
	if m == null:
		return
	if on:
		m.albedo_color = Color(0.07, 0.08, 0.11)
		m.emission_enabled = true
		m.emission = Color(0.12, 1.0, 0.35)
		m.emission_energy_multiplier = 1.5
	else:
		m.albedo_color = Color(1.0, 0.78, 0.1)
		m.emission_enabled = false


func slide_angle() -> float:
	# 차 방향과 실제 진행 방향의 각도 (도)
	if _move_dir.length() < 0.01 or absf(speed) < 1.0:
		return 0.0
	return rad_to_deg((-global_transform.basis.z).angle_to(_move_dir))


func reset_to(pos: Vector3) -> void:
	global_position = pos + Vector3(0, 2.0, 0)
	rotation = Vector3.ZERO
	_pivot.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	speed = 0.0
	_move_dir = -global_transform.basis.z
	airborne = false
	spin = Vector3.ZERO


func kmh() -> float:
	return absf(speed) * 3.0
