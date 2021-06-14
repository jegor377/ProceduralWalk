class_name KinematicCharacter
extends KinematicBody


export(float) var gravity = 98
export(float) var velocity_damp = 6
export(float) var velocity_change_rate = 5
export(float) var min_velocity = 0.5
export(Vector3) var up = Vector3.UP

var velocity: Vector3
var static_velocity: Vector3


func _physics_process(delta: float) -> void:
	for i in get_slide_count():
		_handle_collision(get_slide_collision(i), delta)

	apply_gravity(delta)
	apply_dyn_vel_damp(delta)
	
	_manipulate_velocities(delta)
	
	if velocity.length() < min_velocity:
		velocity = Vector3.ZERO

	move_character(delta)
	move_character_static(delta)

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity -= up * gravity * delta
	else:
		velocity.y = max(velocity.y, 0)

func apply_dyn_vel_damp(delta: float) -> void:
	velocity -= Vector3(velocity.x, 0, velocity.z) * velocity_damp * delta

func move_character(delta: float) -> void:
	if velocity.length() > 0:
		if velocity.y > 0:
			velocity = move_and_slide(velocity, up)
		else:
			velocity = move_and_slide_with_snap(velocity, Vector3.DOWN * 2, up)

func move_character_static(delta: float) -> void:
	if static_velocity.length() > 0:
		if static_velocity.y > 0:
			move_and_slide(static_velocity, up)
		else:
			move_and_slide_with_snap(static_velocity, Vector3.DOWN * 2, up)

func apply_impulse(vel: Vector3) -> void:
	velocity += vel

func _manipulate_velocities(delta: float) -> void:
	pass

func _handle_collision(collision: KinematicCollision, delta: float) -> void:
	pass

# bounces character based on its velocity
func bounce(direction: Vector3, absorption: float = 0.17) -> void:
	velocity = direction * velocity.length() * absorption
