extends CharacterBody3D
class_name RivalCar

signal destroyed(pos: Vector3, reward: float)
signal hit_taken(current_hp: int)
signal punched_player(from: Node3D)

const SPEED := 28.0
const MAX_HP := 3
const MACHO_SPEED := 29.0

var hp := MAX_HP
var city: City
var macho_mode := false
var brawl_target: Node3D = null
var target_is_player := false
var target_intersection := Vector3.ZERO
var current_intersection := Vector3.ZERO
var alive := true
var _pivot: Node3D
var _flash_timer := 0.0
var _punch_cooldown := 0.0
var _mat_body: StandardMaterial3D
var _mat_box: StandardMaterial3D
var reward_amount := 25000.0
var gun_enabled := false
var gun_cooldown := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# 배달통 윗면(y=3.0)까지 덮는다. 예전엔 2.0 까지라 위쪽을 쏘면 그냥 관통했다.
	bs.size = Vector3(2.6, 3.1, 4.8)
	shape.shape = bs
	shape.position = Vector3(0, 1.55, 0)
	add_child(shape)

	_pivot = Node3D.new()
	add_child(_pivot)
	_build_model()


func _mat(c: Color, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.45
	m.metallic = 0.5
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


func _build_model() -> void:
	# 경쟁사 배달차: 검정 & 보라색 바디 + 적대적 붉은 헤드라이트 + 경쟁사 배달통
	_mat_body = _mat(Color(0.12, 0.08, 0.18))
	_mat_box = _mat(Color(0.85, 0.15, 0.65))

	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 1.0, 4.6)
	body.mesh = bm
	body.material_override = _mat_body
	body.position = Vector3(0, 0.8, 0)
	_pivot.add_child(body)

	# 운전석 창문
	_box(Vector3(2.0, 0.9, 1.8), Vector3(0, 1.65, 0.3), Color(0.9, 0.2, 0.3, 0.85), _pivot, 0.5)

	# 경쟁사 배달통
	var boxm := MeshInstance3D.new()
	var boxbm := BoxMesh.new()
	boxbm.size = Vector3(2.0, 1.7, 2.0)
	boxm.mesh = boxbm
	boxm.material_override = _mat_box
	boxm.position = Vector3(0, 2.15, -1.5)
	_pivot.add_child(boxm)

	# 배달통 상단 안테나 / 깃발
	_box(Vector3(0.1, 1.2, 0.1), Vector3(0, 3.5, -1.5), Color(1.0, 0.2, 0.4), _pivot, 2.0)
	_box(Vector3(0.8, 0.4, 0.1), Vector3(0.4, 3.9, -1.5), Color(1.0, 0.1, 0.3), _pivot, 2.5)

	# 적대적 붉은 헤드라이트
	_box(Vector3(0.6, 0.35, 0.25), Vector3(0.8, 0.85, 2.35), Color(1.0, 0.1, 0.1), _pivot, 3.5)
	_box(Vector3(0.6, 0.35, 0.25), Vector3(-0.8, 0.85, 2.35), Color(1.0, 0.1, 0.1), _pivot, 3.5)

	# 후미등
	_box(Vector3(0.5, 0.3, 0.25), Vector3(0.85, 0.85, -2.35), Color(0.8, 0.1, 1.0), _pivot, 2.0)
	_box(Vector3(0.5, 0.3, 0.25), Vector3(-0.85, 0.85, -2.35), Color(0.8, 0.1, 1.0), _pivot, 2.0)

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
		w.material_override = _mat(Color(0.18, 0.16, 0.22))
		w.rotation_degrees = Vector3(0, 0, 90)
		w.position = Vector3(wx, 0.55, wz)
		_pivot.add_child(w)


func gun_muzzle() -> Vector3:
	return global_position + (-global_transform.basis.z * 2.8) + Vector3(0, 1.5, 0)


func set_macho_mode(on: bool) -> void:
	macho_mode = on
	hp = MAX_HP + (3 if on else 0)
	reward_amount = 45000.0 if on else 25000.0
	var macho := _pivot.get_node_or_null("MachoParts")
	if on and macho == null:
		var root := Node3D.new()
		root.name = "MachoParts"
		_pivot.add_child(root)
		_mat_body.albedo_color = Color(0.45, 0.18, 0.08)
		_mat_box.albedo_color = Color(1.0, 0.55, 0.08)

		# 팔다리 달린 마초 트럭. 공격 모션은 팔/몸 흔들림으로 표현한다.
		_box(Vector3(0.7, 0.55, 3.1), Vector3(1.85, 1.45, 0.0), Color(0.95, 0.58, 0.28), root, 0.4)
		_box(Vector3(0.7, 0.55, 3.1), Vector3(-1.85, 1.45, 0.0), Color(0.95, 0.58, 0.28), root, 0.4)
		_box(Vector3(0.95, 0.75, 0.95), Vector3(2.25, 1.42, 1.75), Color(0.72, 0.25, 0.08), root, 0.7)
		_box(Vector3(0.95, 0.75, 0.95), Vector3(-2.25, 1.42, 1.75), Color(0.72, 0.25, 0.08), root, 0.7)
		_box(Vector3(0.75, 1.65, 0.75), Vector3(0.95, -0.25, 1.15), Color(0.80, 0.35, 0.12), root, 0.2)
		_box(Vector3(0.75, 1.65, 0.75), Vector3(-0.95, -0.25, 1.15), Color(0.80, 0.35, 0.12), root, 0.2)
		_box(Vector3(1.05, 0.45, 1.15), Vector3(0.95, -1.2, 1.5), Color(0.18, 0.13, 0.10), root)
		_box(Vector3(1.05, 0.45, 1.15), Vector3(-0.95, -1.2, 1.5), Color(0.18, 0.13, 0.10), root)
		_box(Vector3(1.8, 0.35, 0.2), Vector3(0, 3.05, 0.65), Color(1.0, 0.9, 0.35), root, 1.6)
	elif not on and macho != null:
		macho.queue_free()


func setup(c: City, start_p: Vector3) -> void:
	city = c
	current_intersection = start_p
	global_position = start_p + Vector3(0, 0.2, 0)
	_pick_next_intersection()


func _pick_next_intersection() -> void:
	if city == null or city.intersections.is_empty():
		return
	# 현재 교차로에서 인접한 (같은 X 또는 같은 Z 축 상의) 교차로 선택
	var candidates: Array[Vector3] = []
	for p in city.intersections:
		if p.distance_to(current_intersection) < 1.0:
			continue
		var dx := absf(p.x - current_intersection.x)
		var dz := absf(p.z - current_intersection.z)
		# 대략 직교 도로 거리 (격자 1~2칸 거리)
		if (dx < 2.0 and dz < City.CELL * 2.5) or (dz < 2.0 and dx < City.CELL * 2.5):
			candidates.append(p)
	if candidates.is_empty():
		target_intersection = city.random_point()
	else:
		target_intersection = candidates[randi() % candidates.size()]


func _physics_process(delta: float) -> void:
	if not alive:
		return

	_punch_cooldown = maxf(0.0, _punch_cooldown - delta)
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_mat_body.albedo_color = Color(0.45, 0.18, 0.08) if macho_mode else Color(0.12, 0.08, 0.18)
			_mat_body.emission_enabled = false

	if macho_mode and is_instance_valid(brawl_target) and (target_is_player or (brawl_target as RivalCar).alive):
		_tick_macho_brawl(delta)
		return

	var to_target := target_intersection - global_position
	to_target.y = 0.0
	var dist := to_target.length()

	if dist < 6.0:
		current_intersection = target_intersection
		_pick_next_intersection()
		to_target = target_intersection - global_position
		to_target.y = 0.0

	if to_target.length() > 0.5:
		var target_yaw := atan2(-to_target.x, -to_target.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 5.0, 1.0))

	var fwd := -global_transform.basis.z
	velocity = fwd * SPEED
	velocity.y = 0.0
	move_and_slide()


func _tick_macho_brawl(delta: float) -> void:
	var to_target := brawl_target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > 0.5:
		var target_yaw := atan2(-to_target.x, -to_target.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 8.0, 1.0))
	var fwd := -global_transform.basis.z
	velocity = fwd * (MACHO_SPEED if dist > 5.2 else 0.0)
	velocity.y = 0.0
	move_and_slide()

	var macho := _pivot.get_node_or_null("MachoParts")
	if macho != null:
		macho.rotation.z = sin(Time.get_ticks_msec() * 0.018) * (0.18 if dist < 7.0 else 0.07)

	if dist < 6.4 and _punch_cooldown <= 0.0:
		_punch_cooldown = 1.25
		if target_is_player:
			punched_player.emit(self)
		else:
			(brawl_target as RivalCar).take_damage(1)


func take_damage(dmg: int = 1) -> void:
	if not alive:
		return
	hp -= dmg
	_flash_timer = 0.18
	_mat_body.albedo_color = Color(1.0, 1.0, 1.0)
	_mat_body.emission_enabled = true
	_mat_body.emission = Color(1.0, 0.2, 0.2)
	_mat_body.emission_energy_multiplier = 4.0
	hit_taken.emit(hp)

	if hp <= 0:
		explode()


func explode() -> void:
	alive = false
	destroyed.emit(global_position, reward_amount)
	# 폭발 트윈 연출
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_pivot, "scale", Vector3.ONE * 1.8, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(_pivot, "position:y", 3.5, 0.25)
	tw.chain().tween_property(_pivot, "scale", Vector3.ZERO, 0.2)
	await tw.finished
	queue_free()
