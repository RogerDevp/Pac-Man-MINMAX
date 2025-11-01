extends CharacterBody2D
class_name Ghost

signal player_ate_ghost
signal ghost_ate_player
signal ghost_became_vulnerable
signal ghost_restored

@export var speed := 100
@export var color := "Red"
var state = IN_PEN
var start_pos: Vector2
var path: PackedVector2Array = []

enum {
	IN_PEN,
	CHASE,
	CORNER,
	SCARED,
	EATEN
}


func _ready():
	start_pos = global_position


func _physics_process(delta):
	if path.is_empty():
		if state == EATEN:
			state = CHASE
			emit_signal("ghost_restored")
		return

	# Usar posiciones globales para moverse correctamente en el mapa
	var starting_point := global_position
	var target_point := path[0]

	var distance := starting_point.distance_to(target_point)
	if distance < speed * delta:
		path.remove_at(0)
		if path.is_empty():
			return
		target_point = path[0]

	# Ajustar velocidad según estado
	var speed_multiplier := 1.0
	match state:
		EATEN:
			speed_multiplier = 2.0
		SCARED:
			speed_multiplier = 0.6

	var velocity := (target_point - starting_point).normalized() * speed * speed_multiplier
	animate(velocity)
	set_velocity(velocity)
	move_and_slide()


func start():
	state = CHASE


func chase():
	if state == CORNER or state == SCARED:
		state = CHASE


func corner():
	if state == CHASE or state == SCARED:
		state = CORNER


func scared():
	if state != IN_PEN and state != EATEN:
		state = SCARED
		emit_signal("ghost_became_vulnerable")


func animate(velocity: Vector2):
	match state:
		IN_PEN, CHASE, CORNER:
			if abs(velocity.x) > abs(velocity.y):
				if velocity.x > 0:
					$Animation.play("move_right")
				else:
					$Animation.play("move_left")
			else:
				if velocity.y > 0:
					$Animation.play("move_down")
				else:
					$Animation.play("move_up")
		EATEN:
			if abs(velocity.x) > abs(velocity.y):
				if velocity.x > 0:
					$Animation.play("eye_right")
				else:
					$Animation.play("eye_left")
			else:
				if velocity.y > 0:
					$Animation.play("eye_down")
				else:
					$Animation.play("eye_up")
		SCARED:
			$Animation.play("scared")


func reset():
	global_position = start_pos
	state = IN_PEN
	path.clear()
	$Animation.play("idle")


func set_path(value: PackedVector2Array) -> void:
	path = value


func warp_to(pos: Vector2):
	global_position = pos
	path.clear()


func _on_Area_body_entered(_body):
	if state == SCARED:
		emit_signal("player_ate_ghost", self)
		state = EATEN
	elif state == CHASE or state == CORNER:
		emit_signal("ghost_ate_player", self)
