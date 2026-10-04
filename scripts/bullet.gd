extends Node3D
class_name Bullet

signal hit_player()

const SPEED := 180.0
const MAX_RANGE := 220.0

var direction := Vector3.FORWARD
var traveled := 0.0
var ignore: Array[RID] = []   # 쏜 사람 자기 차는 무시
var hostile := false          # 트럭이 쏜 탄환. 플레이어를 맞힌다
var player_rid: RID
var _mesh: MeshInstance3D


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = 0.15
	cm.height = 1.4
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.25, 0.3) if hostile else Color(1.0, 0.9, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.15, 0.25) if hostile else Color(1.0, 0.7, 0.1)
	m.emission_energy_multiplier = 4.0
	mi.material_override = m
	mi.rotation_degrees.x = 90.0
	add_child(mi)
	_mesh = mi


func setup(from: Vector3, dir: Vector3) -> void:
	global_position = from
	direction = dir.normalized()
	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	var step := direction * SPEED * delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step)
	query.exclude = ignore
	var result := space.intersect_ray(query)

	if result.size() > 0:
		var collider: Object = result.get("collider")
		if hostile:
			if collider is PhysicsBody3D and (collider as PhysicsBody3D).get_rid() == player_rid:
				hit_player.emit()
			queue_free()
			return
		if Engine.has_meta("bullet_debug"):
			var nm: String = collider.get_class()
			if collider is RivalCar:
				nm = "RivalCar"
			print("[bul] 피격: %s  위치=%s (y=%.2f)" % [nm, str(result.get("position").round()), result.get("position").y])
		if collider is RivalCar:
			(collider as RivalCar).take_damage(1)
		elif collider is Node and collider.get_parent() is RivalCar:
			(collider.get_parent() as RivalCar).take_damage(1)
		queue_free()
		return

	global_position += step
	traveled += SPEED * delta
	if traveled >= MAX_RANGE:
		queue_free()
