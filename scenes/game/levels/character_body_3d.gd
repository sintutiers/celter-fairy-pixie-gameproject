extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

## Filled from the children when empty. Needs a PlayerInputComponent or any other InputComponent.
@export var input: InputComponent


func _ready() -> void:
	if not input:
		input = Component.find_descendant_of_type(self, InputComponent, true) as InputComponent
	if not input:
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	var frame: InputFrame = input.get_frame()

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if frame.jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction: Vector3 = (transform.basis * Vector3(frame.move.x, 0, frame.move.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
