extends KinematicCharacter


export(float) var speed = 10
export(float) var feet_dist_delta = 0.2
export(float) var max_left_leg_dist = 0.3
export(float) var step_time := 0.5
export(float) var legs_delta := 1.5
export(float) var step_delta_y := 1.0
export(NodePath) var spawn_point

var forward := false
var backward := false
var left := false
var right := false

var last_l_leg_pos: Vector3
var last_r_leg_pos: Vector3
var dest_l_leg_pos: Vector3
var dest_r_leg_pos: Vector3
var l_leg_pos: Vector3
var r_leg_pos: Vector3

onready var skeleton := $Armature/Skeleton

onready var space_state = get_world().direct_space_state
export(float) var ray_length = 10

var is_animating_legs := false
var legs_anims_t := 0.0

export(float, 0.1, 1.0) var mouse_sensivitiy = 0.3
export(float, -90, 0) var min_pitch = -90
export(float, 0, 90) var max_pitch = 90

onready var camera_pivot := $CameraPivot
onready var camera := $CameraPivot/CameraBoom/Camera

onready var original_hips_pos := get_hips_pos()
onready var normal_hips_pos := get_hips_pos()

export(float) var crouch_delta = 1
var is_crouching := false

export(bool) var first_camera = true

#onready var 

func _ready():
	set_prop_local_legs_pos()
	$Armature/Skeleton/LeftLeg.start()
	$Armature/Skeleton/RightLeg.start()

func get_hips_pos() -> Vector3:
	var hips_id: int = skeleton.find_bone('Hips')
	var hips_rest: Transform = skeleton.get_bone_custom_pose(hips_id)
	
	return hips_rest.origin

func set_hips_pos(pos: Vector3) -> void:
	var hips_id: int = skeleton.find_bone('Hips')
	var hips_rest: Transform = skeleton.get_bone_custom_pose(hips_id)
	var new_transform = Transform(hips_rest)
	new_transform.origin = pos
	#skeleton.set_bone_global_pose_override(hips_id, new_transform, 1.0)
	skeleton.set_bone_custom_pose(hips_id, new_transform)

func set_prop_local_legs_pos() -> void:
	var l_foot_id: int = skeleton.find_bone('Foot.L')
	var l_foot_rest: Transform = skeleton.get_bone_global_pose(l_foot_id)
	$PropLeftLegPos.transform.origin = l_foot_rest.origin
	
	var r_foot_id: int = skeleton.find_bone('Foot.R')
	var r_foot_rest: Transform = skeleton.get_bone_global_pose(r_foot_id)
	$PropRightLegPos.transform.origin = r_foot_rest.origin

func set_leg_pos_to_prop_pos() -> void:
	#print($PropLeftLegPos.global_transform.origin, " ", $PropRightLegPos.global_transform.origin)
	l_leg_pos = $PropLeftLegPosToGround.global_transform.origin + Vector3.UP * feet_dist_delta
	r_leg_pos = $PropRightLegPosToGround.global_transform.origin + Vector3.UP * feet_dist_delta

func _process(delta):
	if transform.origin.y < -20:
		transform.origin = get_node(spawn_point).transform.origin
	set_global_legs_pos()
	set_prop_legs_to_ground()
	move_legs(delta)
	if not is_on_floor():
		set_leg_pos_to_prop_pos()

func set_global_legs_pos() -> void:
	$LeftLegControl.global_transform.origin = l_leg_pos
	$RightLegControl.global_transform.origin = r_leg_pos

func set_prop_legs_to_ground() -> void:
	var legs_pos := get_prop_legs_to_ground()
	$PropLeftLegPosToGround.global_transform.origin = legs_pos[0]
	$PropRightLegPosToGround.global_transform.origin = legs_pos[1]

func get_prop_legs_to_ground() -> Array:
	var l_prop_leg_pos: Vector3 = $PropLeftLegPos.global_transform.origin
	var r_prop_leg_pos: Vector3 = $PropRightLegPos.global_transform.origin
	
	var l_leg_ray = space_state.intersect_ray(
			l_prop_leg_pos + Vector3.UP, l_prop_leg_pos + Vector3.DOWN * ray_length, [self])
	var r_leg_ray = space_state.intersect_ray(
			r_prop_leg_pos + Vector3.UP, r_prop_leg_pos + Vector3.DOWN * ray_length, [self])
	
	
	return [
		l_leg_ray.position if not l_leg_ray.empty() else l_prop_leg_pos,
		r_leg_ray.position if not r_leg_ray.empty() else r_prop_leg_pos
	]

func get_left_leg_prop_dist() -> float:
	var left_leg_pos2d := Vector2(
			$PropLeftLegPosToGround.global_transform.origin.x,
			$PropLeftLegPosToGround.global_transform.origin.z)
	var curr_left_leg_pos2d := Vector2(l_leg_pos.x, l_leg_pos.z)
	return left_leg_pos2d.distance_to(curr_left_leg_pos2d)

func move_legs(delta: float) -> void:
	if not is_on_floor():
		return
	var last_is_anim_legs := is_animating_legs
	if get_left_leg_prop_dist() > max_left_leg_dist and not is_animating_legs:
		last_l_leg_pos = l_leg_pos
		last_r_leg_pos = r_leg_pos
		legs_anims_t = 0.0
		is_animating_legs = true
	if is_animating_legs:
		dest_l_leg_pos = $PropLeftLegPosToGround.global_transform.origin + static_velocity.normalized() * legs_delta + Vector3.DOWN * feet_dist_delta
		dest_r_leg_pos = $PropRightLegPosToGround.global_transform.origin + static_velocity.normalized() * legs_delta + Vector3.DOWN * feet_dist_delta
		var max_legs_spread: float = 3.0
		if legs_anims_t / step_time <= 0.5:
			l_leg_pos = last_l_leg_pos.linear_interpolate(dest_l_leg_pos, legs_anims_t / step_time * 2.0)
			l_leg_pos = l_leg_pos + Vector3.UP * step_delta_y * sin(PI * legs_anims_t / step_time * 2.0)
		if legs_anims_t / step_time >= 0.5:
			r_leg_pos = last_r_leg_pos.linear_interpolate(dest_r_leg_pos, (legs_anims_t / step_time - 0.5) * 2.0)
			r_leg_pos = r_leg_pos + Vector3.UP * step_delta_y * sin(PI * (legs_anims_t / step_time - 0.5) * 2.0)
		set_hips_pos(normal_hips_pos + Vector3.DOWN * get_legs_spread() / max_legs_spread * 0.3)
		legs_anims_t += delta
		if legs_anims_t >= step_time:
			is_animating_legs = false

func get_legs_spread() -> float:
	return Vector2(l_leg_pos.x, l_leg_pos.z).distance_to(Vector2(r_leg_pos.x, r_leg_pos.z))

func _manipulate_velocities(delta: float) -> void:
	var dir := Vector3.ZERO
	if forward:
		dir += transform.basis.z
	if backward:
		dir -= transform.basis.z
	if left:
		dir += transform.basis.x
	if right:
		dir -= transform.basis.x
	static_velocity = dir * speed


func _input(event):
	if event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * mouse_sensivitiy
		camera_pivot.rotation_degrees.x += event.relative.y * mouse_sensivitiy
		camera_pivot.rotation_degrees.x = clamp(camera_pivot.rotation_degrees.x, min_pitch, max_pitch)
	if event.is_action_pressed("forward"):
		forward = true
	elif event.is_action_released("forward"):
		forward = false
	if event.is_action_pressed("backward"):
		backward = true
	elif event.is_action_released("backward"):
		backward = false
	if event.is_action_pressed("left"):
		left = true
	elif event.is_action_released("left"):
		left = false
	if event.is_action_pressed("right"):
		right = true
	elif event.is_action_released("right"):
		right = false
	if event.is_action_released("jump"):
		apply_impulse(Vector3.UP * 30)
	if event.is_action_released("change_camera"):
		first_camera = not first_camera
		$CameraPivot/CameraBoom/Camera.current = first_camera
		$Camera.current = not first_camera
	if event.is_action_released("crouch"):
		is_crouching = not is_crouching
		if is_crouching:
			normal_hips_pos = original_hips_pos + Vector3.DOWN * crouch_delta
			set_hips_pos(normal_hips_pos)
		else:
			normal_hips_pos = original_hips_pos
			set_hips_pos(normal_hips_pos)
