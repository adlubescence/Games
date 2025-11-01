extends CharacterBody3D

@export_subgroup("Properties")
@export var movement_speed = 5
@export_range(0, 100) var number_of_jumps:int = 2
@export var jump_strength = 8

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []

var weapon: Weapon
var weapon_index := 0

var mouse_sensitivity = 0.001
var gamepad_sensitivity := 0.075

var mouse_captured := true

var movement_velocity: Vector3
var rotation_target: Vector3

var input_mouse: Vector2

var health:int = 100
var gravity := 0.0

var previously_floored := false

var jumps_remaining:int

var first_person_viewport_offset = Vector3(1.2, -1.1, -2.75)

var tween:Tween

const third_person = "third"
const first_person = "first"

signal health_updated

@onready var first_person_camera = $Head/fpv_camera
@onready var third_person_arm = $TPVPivot/SpringArm3D
@onready var tpv_pivot = $TPVPivot
@onready var fpv_raycast = $Head/fpv_camera/RayCast
@onready var head = $Head

@onready var muzzle = $Head/fpv_camera/SubViewportContainer/SubViewport/CameraItem/Muzzle
@onready var first_person_viewport = $Head/fpv_camera/SubViewportContainer/SubViewport/CameraItem/Container
@onready var sound_footsteps = $SoundFootsteps
@onready var blaster_cooldown = $Cooldown

@export var tilt_limit = deg_to_rad(75)

@export var crosshair:TextureRect

var current_camera = first_person
# Functions

func _ready():
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	weapon = weapons[weapon_index] # Weapon must never be nil
	initiate_change_weapon(weapon_index)

func _process(delta):
	
	# Handle functions
	
	handle_controls(delta)
	handle_gravity(delta)
	
	# Movement
	
	var applied_velocity: Vector3
	
	movement_velocity = transform.basis * movement_velocity # Move forward
	
	applied_velocity = velocity.lerp(movement_velocity, delta * 10)
	applied_velocity.y = -gravity
	
	velocity = applied_velocity
	move_and_slide()
	
	# Rotation 
	first_person_viewport.position = lerp(first_person_viewport.position, first_person_viewport_offset - (basis.inverse() * applied_velocity / 30), delta * 10)
	
	# Movement sound
	
	sound_footsteps.stream_paused = true
	
	if is_on_floor():
		if abs(velocity.x) > 1 or abs(velocity.z) > 1:
			sound_footsteps.stream_paused = false
	
	# Landing after jump or falling
	
	first_person_camera.position.y = lerp(first_person_camera.position.y, 0.0, delta * 5)
	
	if is_on_floor() and gravity > 1 and !previously_floored: # Landed
		Audio.play("sounds/land.ogg")
		first_person_camera.position.y = -0.1
	
	previously_floored = is_on_floor()
	
	# Falling/respawning
	
	if position.y < -10:
		get_tree().reload_current_scene()

# Mouse movement
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		input_mouse = event.relative * mouse_sensitivity
		handle_rotation(event.relative.x, event.relative.y, false)


func handle_controls(delta):
	
	# Swap camera
	handle_toggle_camera()
	
	# Mouse capture
	
	if Input.is_action_just_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	
	if Input.is_action_just_pressed("mouse_capture_exit"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
		
		input_mouse = Vector2.ZERO
	
	# Movement
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	movement_velocity = Vector3(input.x, 0, input.y).normalized() * movement_speed
	
	# Handle Controller Rotation
	var rotation_input := Input.get_vector("camera_right", "camera_left", "camera_down", "camera_up")
	if rotation_input:
		handle_rotation(rotation_input.x, rotation_input.y, true, delta)
	
	# Shooting
	
	action_shoot()
	
	# Jumping
	
	if Input.is_action_just_pressed("jump"):
		
		if jumps_remaining:
			action_jump()
		
	# Weapon switching
	
	action_weapon_toggle()
	
# Camera toggle
func handle_toggle_camera():
	if Input.is_action_just_pressed("toggle_camera"):
		if current_camera == first_person:
			current_camera = third_person
			first_person_viewport.visible = false
			muzzle.visible = false
			first_person_camera.reparent(third_person_arm)
		else:
			current_camera = first_person
			first_person_viewport.visible = true
			muzzle.visible = true
			first_person_camera.reparent(head)
			first_person_camera.position = head.position
			

# rotation
func handle_rotation(xRot: float, yRot: float, isController: bool, delta: float = 0.0):
	if isController:
		rotation_target -= Vector3(-yRot, -xRot, 0).limit_length(1.0) * gamepad_sensitivity
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
		first_person_camera.rotation.x = lerp_angle(first_person_camera.rotation.x, rotation_target.x, delta * 25)
		rotation.y = lerp_angle(rotation.y, rotation_target.y, delta * 25)
	else:
		rotation_target += (Vector3(-yRot, -xRot, 0) * mouse_sensitivity)
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
		first_person_camera.rotation.x = rotation_target.x
		rotation.y = rotation_target.y
		head.rotation.x = first_person_camera.rotation.x

# Handle gravity

func handle_gravity(delta):
	gravity += 20 * delta
	
	if gravity > 0 and is_on_floor():
		jumps_remaining = number_of_jumps
		gravity = 0

# Jumping

func action_jump():	
	Audio.play("sounds/jump_a.ogg, sounds/jump_b.ogg, sounds/jump_c.ogg")
	gravity = -jump_strength	
	jumps_remaining -= 1

# Shooting

func action_shoot():
	
	if Input.is_action_pressed("shoot"):
	
		if !blaster_cooldown.is_stopped(): return # Cooldown for shooting
		
		Audio.play(weapon.sound_shoot)
		
		# Set muzzle flash position, play animation
		
		muzzle.play("default")
		
		muzzle.rotation_degrees.z = randf_range(-45, 45)
		muzzle.scale = Vector3.ONE * randf_range(0.40, 0.75)
		
		muzzle.position = first_person_viewport.position - weapon.muzzle_position

		blaster_cooldown.start(weapon.cooldown)
		
		# Shoot the weapon, amount based on shot count
		
		for n in weapon.shot_count:
			fpv_raycast.target_position.x = randf_range(-weapon.spread, weapon.spread)
			fpv_raycast.target_position.y = randf_range(-weapon.spread, weapon.spread)
			
			fpv_raycast.force_raycast_update()
			
			if !fpv_raycast.is_colliding(): continue # Don't create impact when raycast didn't hit
			
			var collider = fpv_raycast.get_collider()
			
			# Hitting an enemy
			
			if collider.has_method("damage"):
				collider.damage(weapon.damage)
			
			# Creating an impact animation
			
			var impact = preload("res://objects/impact.tscn")
			var impact_instance = impact.instantiate()
			
			impact_instance.play("shot")
			
			get_tree().root.add_child(impact_instance)
			
			impact_instance.position = fpv_raycast.get_collision_point() + (fpv_raycast.get_collision_normal() / 10)
			impact_instance.look_at(first_person_camera.global_transform.origin, Vector3.UP, true)
			
		first_person_viewport.position.z += 0.25 # Knockback of weapon visual
		#first_person_camera.rotation.x += 0.025 # Knockback of first_person_camera

		movement_velocity += Vector3(0, 0, weapon.knockback) # Knockback

# Toggle between available weapons (listed in 'weapons')

func action_weapon_toggle():
	
	if Input.is_action_just_pressed("weapon_toggle"):
		
		weapon_index = wrap(weapon_index + 1, 0, weapons.size())
		initiate_change_weapon(weapon_index)
		
		Audio.play("sounds/weapon_change.ogg")

# Initiates the weapon changing animation (tween)

func initiate_change_weapon(index):
	
	weapon_index = index
	
	tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT_IN)
	tween.tween_property(first_person_viewport, "position", first_person_viewport_offset - Vector3(0, 1, 0), 0.1)
	tween.tween_callback(change_weapon) # Changes the model

# Switches the weapon model (off-screen)

func change_weapon():
	
	weapon = weapons[weapon_index]

	# Step 1. Remove previous weapon model(s) from first_person_viewport
	
	for n in first_person_viewport.get_children():
		first_person_viewport.remove_child(n)
	
	# Step 2. Place new weapon model in first_person_viewport
	
	var weapon_model = weapon.model.instantiate()
	first_person_viewport.add_child(weapon_model)
	
	weapon_model.position = weapon.position
	weapon_model.rotation_degrees = weapon.rotation
	
	# Step 3. Set model to only render on layer 2 (the weapon first_person_camera)
	
	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2
		
	# Set weapon data
	
	fpv_raycast.target_position = Vector3(0, 0, -1) * weapon.max_distance
	crosshair.texture = weapon.crosshair

func damage(amount):
	
	health -= amount
	health_updated.emit(health) # Update health on HUD
	
	if health < 0:
		get_tree().reload_current_scene() # Reset when out of health
