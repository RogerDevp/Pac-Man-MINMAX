extends CharacterBody2D
class_name PacMan

signal player_reset
@export var speed := 175
@export var current_dir = "none"
@export var movement_direction := Vector2.ZERO
var movement_enabled = false

var vel := Vector2()
var inputs = {"right": Vector2.RIGHT,
			"left": Vector2.LEFT,
			"up": Vector2.UP,
			"down": Vector2.DOWN}

func get_input():
	if movement_enabled:
		vel = Vector2()
		for input in inputs:
			if Input.is_action_just_pressed(input):
				current_dir = input
				movement_direction = inputs[input]
				animate_movement()
		
		vel = movement_direction * speed


func animate_movement():
	$Sprite2D.play("eating")
	match current_dir:
		"right":
			$Sprite2D.rotation_degrees = 0
			$Sprite2D.flip_h = false
		"left":
			$Sprite2D.rotation_degrees = 0
			$Sprite2D.flip_h = true
		"up":
			$Sprite2D.rotation_degrees = -90
			$Sprite2D.flip_h = false
		"down":
			$Sprite2D.rotation_degrees = 90
			$Sprite2D.flip_h = false


func die():
	movement_enabled = false
	$Sprite2D.play("die")
	$Dead.play()
	var _d = $Sprite2D.connect("animation_finished", Callable(self, "reset"))


func _physics_process(_delta):
	if !movement_enabled:
		return
	
	get_input()
	set_velocity(vel)
	move_and_slide()
	vel = vel
	if vel.length() < 1 and movement_direction != Vector2.ZERO:
		movement_direction = Vector2.ZERO
		current_dir = "none"
		$Sprite2D.playing = false


func warp_to(pos):
	global_position = pos


func reset():
	if $Sprite2D.is_connected("animation_finished", Callable(self, "reset")):
		$Sprite2D.disconnect("animation_finished", Callable(self, "reset"))
	position = Vector2(264, 212)
	$Sprite2D.play("idle")
	current_dir = "none"
	movement_direction = Vector2.ZERO
	emit_signal("player_reset")
