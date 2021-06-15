extends KinematicCharacter


# moving
export(float) var speed = 10
export(float) var speed_change_rate = 15.0

var forward := false
var backward := false
var left := false
var right := false

# animation
# additional distance from the end of foot's bone to the ground
# used to make foot be on the ground instead of in the ground.
export(float) var foot_bone_dist_to_ground = 0
# maximal distance in which the left leg can move away from proper leg position
export(float) var max_left_leg_dist = 0.3
# legs move animation time for both legs
export(float) var step_anim_time := 0.5
# additional distance for moving legs a little bit farther in direction of
# velocity. Allows walk animation to look properly. When human walks he places
# legs a little bit further in direction of walking.
export(float) var directional_delta := 1.5
# the height of lifting foot when animating walk
export(float) var step_anim_height := 1.0
# maximum distance between legs in 2D space.
# it should be calculated but to make it simpler just tweak the value and look
# if it looks good to you.
export(float) var max_legs_spread = 3.0

var last_l_leg_pos: Vector3
var last_r_leg_pos: Vector3
var l_leg_pos: Vector3
var r_leg_pos: Vector3

onready var skeleton := $Armature/Skeleton

var is_animating_legs := false
var legs_anim_timer := 0.0

onready var original_hips_pos := get_hips_pos()
onready var current_hips_pos := get_hips_pos()

export(float) var crouch_delta = 1
var is_crouching := false

# raycast
onready var space_state = get_world().direct_space_state
export(float) var ray_length = 10

# camera
export(float, 0.1, 1.0) var mouse_sensivitiy = 0.3
export(float, -90, 0) var min_pitch = -90
export(float, 0, 90) var max_pitch = 90

onready var camera_pivot := $CameraPivot
onready var camera := $CameraPivot/CameraBoom/Camera

export(bool) var first_camera = true

# respawn
export(NodePath) var spawn_point

func _ready():
	set_proper_local_legs_pos()
	$Armature/Skeleton/LeftLeg.start()
	$Armature/Skeleton/RightLeg.start()

func set_proper_local_legs_pos() -> void:
	var l_foot_id: int = skeleton.find_bone('Foot.L')
	var l_foot_rest: Transform = skeleton.get_bone_global_pose(l_foot_id)
	$PropLeftLegPos.transform.origin = l_foot_rest.origin
	
	var r_foot_id: int = skeleton.find_bone('Foot.R')
	var r_foot_rest: Transform = skeleton.get_bone_global_pose(r_foot_id)
	$PropRightLegPos.transform.origin = r_foot_rest.origin

func get_hips_pos() -> Vector3:
	var hips_id: int = skeleton.find_bone('Hips')
	var hips_rest: Transform = skeleton.get_bone_custom_pose(hips_id)
	
	return hips_rest.origin

func set_hips_pos(pos: Vector3) -> void:
	var hips_id: int = skeleton.find_bone('Hips')
	var hips_rest: Transform = skeleton.get_bone_custom_pose(hips_id)
	var new_transform = Transform(hips_rest)
	new_transform.origin = pos
	skeleton.set_bone_custom_pose(hips_id, new_transform)

func set_legs_pos_to_prop_legs_pointers_pos() -> void:
	l_leg_pos = $PropLeftLegPosToGround.global_transform.origin + Vector3.UP * foot_bone_dist_to_ground
	r_leg_pos = $PropRightLegPosToGround.global_transform.origin + Vector3.UP * foot_bone_dist_to_ground

func _process(delta):
	handle_respawn()
	set_global_legs_pos()
	set_prop_legs_ground_pointers()
	move_legs(delta)
	if is_flying():
		set_legs_pos_to_prop_legs_pointers_pos()

func handle_respawn() -> void:
	if transform.origin.y < -20:
		transform.origin = get_node(spawn_point).transform.origin

func is_flying() -> bool:
	return abs(velocity.y) > 1.0

func set_global_legs_pos() -> void:
	$LeftLegControl.global_transform.origin = l_leg_pos
	$RightLegControl.global_transform.origin = r_leg_pos

func set_prop_legs_ground_pointers() -> void:
	var legs_pos := get_prop_legs_to_ground()
	$PropLeftLegPosToGround.global_transform.origin = legs_pos[0] 
	$PropRightLegPosToGround.global_transform.origin = legs_pos[1]

func get_prop_legs_to_ground() -> Array:
	# prop legs pos moved in direction of characters velocity
	var l_prop_leg_pos: Vector3 = $PropLeftLegPos.global_transform.origin + static_velocity.normalized() * directional_delta
	var r_prop_leg_pos: Vector3 = $PropRightLegPos.global_transform.origin + static_velocity.normalized() * directional_delta
	
	var l_leg_ray = space_state.intersect_ray(
			l_prop_leg_pos + Vector3.UP * ray_length, l_prop_leg_pos + Vector3.DOWN * ray_length, [self])
	var r_leg_ray = space_state.intersect_ray(
			r_prop_leg_pos + Vector3.UP * ray_length, r_prop_leg_pos + Vector3.DOWN * ray_length, [self])
	
	
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
	# doesn't do anything when player is in air
	if is_flying():
		return
	
	# if left legs is too far and leg animation isn't playing the set up the animation.
	if get_left_leg_prop_dist() > max_left_leg_dist and not is_animating_legs:
		last_l_leg_pos = l_leg_pos
		last_r_leg_pos = r_leg_pos
		legs_anim_timer = 0.0
		is_animating_legs = true

	if is_animating_legs:
		var desired_l_leg_pos: Vector3 = $PropLeftLegPosToGround.global_transform.origin + Vector3.DOWN * foot_bone_dist_to_ground
		var desired_r_leg_pos: Vector3 = $PropRightLegPosToGround.global_transform.origin + Vector3.DOWN * foot_bone_dist_to_ground
		# half of animation time goes to left leg
		if legs_anim_timer / step_anim_time <= 0.5:
			var l_leg_interpolation_v := legs_anim_timer / step_anim_time * 2.0
			l_leg_pos = last_l_leg_pos.linear_interpolate(desired_l_leg_pos, l_leg_interpolation_v)
			# moving left leg up
			l_leg_pos = l_leg_pos + Vector3.UP * step_anim_height * sin(PI * l_leg_interpolation_v)
		# half of animation time goes to right leg
		if legs_anim_timer / step_anim_time >= 0.5:
			var r_leg_interpolation_v := (legs_anim_timer / step_anim_time - 0.5) * 2.0
			r_leg_pos = last_r_leg_pos.linear_interpolate(desired_r_leg_pos, r_leg_interpolation_v)
			# moving right leg up
			r_leg_pos = r_leg_pos + Vector3.UP * step_anim_height * sin(PI * r_leg_interpolation_v)
		# moving hips up and down depending on ratio of distance between legs and maximum allowed distance
		set_hips_pos(current_hips_pos + Vector3.DOWN * get_legs_spread() / max_legs_spread * 0.3)
		# increase timer time
		legs_anim_timer += delta
		# if timer time is greater than whole animation time then stop animating
		if legs_anim_timer >= step_anim_time:
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
	# grows static_velocity to desired speed every frame
	static_velocity = static_velocity.linear_interpolate(dir * speed, speed_change_rate * delta)
	if static_velocity.length() < min_velocity:
		static_velocity = Vector3.ZERO


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
			current_hips_pos = original_hips_pos + Vector3.DOWN * crouch_delta
			set_hips_pos(current_hips_pos)
		else:
			current_hips_pos = original_hips_pos
			set_hips_pos(current_hips_pos)
