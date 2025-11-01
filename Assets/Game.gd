extends Node2D

const tile_size = 8

@export var pellet_prefab: Resource
@export var vulnerable_time := 7.0

var pellets_left = 244
var starting_pellets = pellets_left
var current_ghost := 0
var ghost_names = ["Red", "Pink", "Blue", "Orange"]
var lives := 5
var vulnearable_ghosts := 0
var eaten_ghosts := 0
var ghost_bonus = 200
var mortal = true
var map

@onready var ghosts = [$Enemies/Red, $Enemies/Pink, $Enemies/Blue, $Enemies/Orange]
@onready var draw_lines = [$Enemies/Red_Line, $Enemies/Pink_Line, $Enemies/Blue_Line, $Enemies/Orange_Line]
@onready var player : PacMan = $"Pac-Man"

var scattering := false


func _init():
	Console.add_command("toggle_navigation_draw", self, "toggle_debug_draw").register()
	Console.add_command("skip_level", self, "level_won").register()
	Console.add_command("invulnerability", self, "toggle_invulnerability").register()


func _ready():
	map = get_world_2d().navigation_map
	
	# --- CÓDIGO DE CONEXIÓN DE SEÑALES ---
	# Arregla el problema de que Pac-Man no pierde vidas.
	for ghost in ghosts:
		ghost.connect("ghost_ate_player", Callable(self, "_on_ghost_ate_player"))
		ghost.connect("player_ate_ghost", Callable(self, "_on_player_ate_ghost"))
		ghost.connect("ghost_became_vulnerable", Callable(self, "_on_ghost_became_vulnerable"))
		ghost.connect("ghost_restored", Callable(self, "_on_ghost_restored"))
	# --- FIN DEL CÓDIGO DE CONEXIÓN ---


func level_won():
	$UI.level_won()
	reset()


func reset():
	stop_ghost_audio()
	for ghost in ghosts:
		ghost.reset()
	vulnearable_ghosts = 0
	eaten_ghosts = 0
	$Pellets.queue_free()
	await get_tree().create_timer(1.0).timeout
	player.reset()
	await get_tree().create_timer(0.10).timeout
	var pellets = pellet_prefab.instantiate()
	add_child(pellets)
	pellets.connect("pellet_eaten", Callable(self, "_on_Pellet_eaten"))
	pellets.connect("power_pellet_eaten", Callable(self, "_on_Power_Pellet_eaten"))
	pellets_left = 244
	starting_pellets = pellets_left


# --------------------------------------------------------------------
# --- IA COMÚN: HEURÍSTICA Y MOVIMIENTOS -----------------------------
# --------------------------------------------------------------------

const MINIMAX_DEPTH = 4 # Profundidad de búsqueda. ¡Cuidado con valores altos!

# --- HEURÍSTICA MODIFICADA (PERSEGUIR O HUIR) ---
func evaluate_state(ghost_pos: Vector2, pacman_pos: Vector2, ghost_state: int) -> float:
	var distance = ghost_pos.distance_to(pacman_pos)
	
	if ghost_state == Ghost.SCARED:
		# --- Lógica de HUIDA ---
		# El fantasma (MAX) quiere MAXIMIZAR la distancia.
		if distance < 1.0:
			return -INF # Ser comido es la peor puntuación
		return distance # La puntuación es la propia distancia
	else:
		# --- Lógica de PERSECUCIÓN ---
		# El fantasma (MAX) quiere MINIMIZAR la distancia.
		if distance < 1.0:
			return INF # Comer es la mejor puntuación
		# Maximizar (1/distancia) es lo mismo que minimizar la distancia
		return 10000.0 / max(distance, 0.1)


# Movimientos posibles desde una posición (USA EL MAPA)
func get_possible_moves(pos: Vector2) -> Array[Vector2]:
	var moves: Array[Vector2] = []
	var directions = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	
	for dir in directions:
		var target_pos = pos + dir * tile_size
		var path_to_neighbor = NavigationServer2D.map_get_path(map, pos, target_pos, true)
		if not path_to_neighbor.is_empty() and path_to_neighbor.size() < 5:
			moves.append(dir)
			
	return moves


# --- LÓGICA MINIMAX CLÁSICO (SIN PODA) PARA EL FANTASMA ROSADO ------


# Función principal que inicia la búsqueda (DEVUELVE DIRECCIÓN)
func get_minimax_move_classic(ghost_pos: Vector2, pacman_pos: Vector2, ghost_state: int) -> Vector2:
	var best_score = -INF
	var best_move_dir = Vector2.ZERO
	
	for move in get_possible_moves(ghost_pos):
		var new_ghost_pos = ghost_pos + move * tile_size
		var score = minimax_classic(new_ghost_pos, pacman_pos, MINIMAX_DEPTH - 1, false, ghost_state)
		
		if score > best_score:
			best_score = score
			best_move_dir = move
			
	if best_move_dir == Vector2.ZERO:
		return Vector2.ZERO
		
	return best_move_dir

# El algoritmo Minimax recursivo CLÁSICO (SIN PODA)
func minimax_classic(ghost_pos: Vector2, pacman_pos: Vector2, depth: int, is_maximizing: bool, ghost_state: int) -> float:
	if depth == 0 or ghost_pos.distance_to(pacman_pos) < tile_size:
		return evaluate_state(ghost_pos, pacman_pos, ghost_state)

	if is_maximizing: # Turno del Fantasma (MAX)
		var max_eval = -INF
		for move in get_possible_moves(ghost_pos):
			var new_ghost_pos = ghost_pos + move * tile_size
			var eval = minimax_classic(new_ghost_pos, pacman_pos, depth - 1, false, ghost_state)
			max_eval = max(max_eval, eval)
		return max_eval
	else: # Turno de Pac-Man (MIN)
		var min_eval = INF
		for move in get_possible_moves(pacman_pos):
			var new_pacman_pos = pacman_pos + move * tile_size
			var eval = minimax_classic(ghost_pos, new_pacman_pos, depth - 1, true, ghost_state)
			min_eval = min(min_eval, eval)
		return min_eval


# --- LÓGICA MINIMAX CON PODA ALFA-BETA (ROJO) -----------------------


# Función principal que inicia la búsqueda (DEVUELVE DIRECCIÓN)
func get_minimax_move_alphabeta(ghost_pos: Vector2, pacman_pos: Vector2, ghost_state: int) -> Vector2:
	var best_score = -INF
	var best_move_dir = Vector2.ZERO
	var alpha = -INF
	var beta = INF
	
	for move in get_possible_moves(ghost_pos):
		var new_ghost_pos = ghost_pos + move * tile_size
		var score = minimax_alphabeta(new_ghost_pos, pacman_pos, MINIMAX_DEPTH - 1, false, alpha, beta, ghost_state)
		
		if score > best_score:
			best_score = score
			best_move_dir = move
		
		alpha = max(alpha, best_score)
	
	if best_move_dir == Vector2.ZERO:
		return Vector2.ZERO
		
	return best_move_dir

# El algoritmo Minimax recursivo con PODA ALFA-BETA
func minimax_alphabeta(ghost_pos: Vector2, pacman_pos: Vector2, depth: int, is_maximizing: bool, alpha: float, beta: float, ghost_state: int) -> float:
	if depth == 0 or ghost_pos.distance_to(pacman_pos) < tile_size:
		return evaluate_state(ghost_pos, pacman_pos, ghost_state)

	if is_maximizing: # Turno del Fantasma (MAX)
		var max_eval = -INF
		for move in get_possible_moves(ghost_pos):
			var new_ghost_pos = ghost_pos + move * tile_size
			var eval = minimax_alphabeta(new_ghost_pos, pacman_pos, depth - 1, false, alpha, beta, ghost_state)
			max_eval = max(max_eval, eval)
			alpha = max(alpha, eval)
			if beta <= alpha:
				break
		return max_eval
	else: # Turno de Pac-Man (MIN)
		var min_eval = INF
		for move in get_possible_moves(pacman_pos):
			var new_pacman_pos = pacman_pos + move * tile_size
			var eval = minimax_alphabeta(ghost_pos, new_pacman_pos, depth - 1, true, alpha, beta, ghost_state)
			min_eval = min(min_eval, eval)
			beta = min(beta, eval)
			if beta <= alpha:
				break
		return min_eval


# --- LOGICA EXPECTIMAX (MAX-CHANCE) PARA EL FANTASMA AZUL -----------


# Función principal que inicia la búsqueda (DEVUELVE DIRECCIÓN)
func get_minimax_move_expectimax(ghost_pos: Vector2, pacman_pos: Vector2, ghost_state: int) -> Vector2:
	var best_score = -INF
	var best_move_dir = Vector2.ZERO
	
	# El nodo raíz es un nodo MAX (el fantasma)
	for move in get_possible_moves(ghost_pos):
		var new_ghost_pos = ghost_pos + move * tile_size
		# Llamamos a la recursión. 'false' significa que es el turno del jugador (CHANCE).
		var score = expectimax(new_ghost_pos, pacman_pos, MINIMAX_DEPTH - 1, false, ghost_state)
		
		if score > best_score:
			best_score = score
			best_move_dir = move
			
	if best_move_dir == Vector2.ZERO:
		return Vector2.ZERO
		
	return best_move_dir

# El algoritmo Expectimax recursivo
func expectimax(ghost_pos: Vector2, pacman_pos: Vector2, depth: int, is_maximizing: bool, ghost_state: int) -> float:
	if depth == 0 or ghost_pos.distance_to(pacman_pos) < tile_size:
		return evaluate_state(ghost_pos, pacman_pos, ghost_state)

	if is_maximizing: # Turno del Fantasma (MAX)
		var max_eval = -INF
		for move in get_possible_moves(ghost_pos):
			var new_ghost_pos = ghost_pos + move * tile_size
			var eval = expectimax(new_ghost_pos, pacman_pos, depth - 1, false, ghost_state)
			max_eval = max(max_eval, eval)
		return max_eval
	else: # Turno de Pac-Man (CHANCE / POSIBILIDAD)
		var total_score = 0.0
		var possible_moves = get_possible_moves(pacman_pos)
		
		# Si Pac-Man no tiene a dónde moverse, solo evaluamos el estado actual
		if possible_moves.is_empty():
			return evaluate_state(ghost_pos, pacman_pos, ghost_state)
		
		# Sumamos la utilidad de todos los resultados posibles
		for move in possible_moves:
			var new_pacman_pos = pacman_pos + move * tile_size
			# 'true' significa que es el turno del fantasma (MAX)
			total_score += expectimax(ghost_pos, new_pacman_pos, depth - 1, true, ghost_state)
		
		# Devolvemos el promedio ponderado (en este caso, todos tienen la misma probabilidad)
		return total_score / possible_moves.size()


# --------------------------------------------------------------------
# --- REPATH DE LOS FANTASMAS (VERSIÓN CORREGIDA) --------------------
# --------------------------------------------------------------------
func ghost_repath():
	current_ghost += 1
	if current_ghost >= ghosts.size():
		current_ghost = 0
	
	var ghost: Ghost = ghosts[current_ghost]
	var ghost_snapped_pos = NavigationServer2D.map_get_closest_point(map, ghost.global_position)

	match ghost.state:
		Ghost.CHASE:
			var new_path := PackedVector2Array()
			match ghost_names[current_ghost]:
				"Red":
					# --- Estrategia: Minimax con PODA ALFA-BETA ---
					var best_dir = get_minimax_move_alphabeta(ghost_snapped_pos, player.global_position, ghost.state)
					if best_dir != Vector2.ZERO:
						var far_target = ghost_snapped_pos + best_dir * 1000.0
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, far_target, true)
					if new_path.is_empty():
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, player.global_position, true)
					
					if not new_path.is_empty():
						var local_points := PackedVector2Array()
						for p in new_path:
							local_points.append(draw_lines[current_ghost].to_local(p))
						draw_lines[current_ghost].points = local_points
						ghost.path = new_path

				"Pink":
					# --- Estrategia: Minimax CLÁSICO (sin poda) ---
					var best_dir = get_minimax_move_classic(ghost_snapped_pos, player.global_position, ghost.state)
					if best_dir != Vector2.ZERO:
						var far_target = ghost_snapped_pos + best_dir * 1000.0
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, far_target, true)
					if new_path.is_empty():
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, player.global_position, true)

					if not new_path.is_empty():
						var local_points := PackedVector2Array()
						for p in new_path:
							local_points.append(draw_lines[current_ghost].to_local(p))
						draw_lines[current_ghost].points = local_points
						ghost.path = new_path

				"Blue":
					# --- Estrategia: EXPECTIMAX (Minimax Esperado) ---
					var best_dir = get_minimax_move_expectimax(ghost_snapped_pos, player.global_position, ghost.state)
					
					if best_dir != Vector2.ZERO:
						var far_target = ghost_snapped_pos + best_dir * 1000.0
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, far_target, true)
					
					if new_path.is_empty():
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, player.global_position, true)
					
					if not new_path.is_empty():
						var local_points := PackedVector2Array()
						for p in new_path:
							local_points.append(draw_lines[current_ghost].to_local(p))
						draw_lines[current_ghost].points = local_points
						ghost.path = new_path

				"Orange":
					# Lógica de Clyde (Clásica)
					var distance = ghost_snapped_pos.distance_to(player.global_position)
					if distance > 8 * tile_size:
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, player.global_position, true)
					else:
						# Huye a su esquina (necesitarás definir esta esquina)
						var target_position = Vector2(156, 270) # Ejemplo de esquina de Orange
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, target_position, true)

			# Aplicar la ruta solo a Orange (Red, Pink y Blue la manejan internamente)
			if ghost_names[current_ghost] == "Orange":
				if new_path.is_empty(): return
				var local_points := PackedVector2Array()
				for p in new_path:
					local_points.append(draw_lines[current_ghost].to_local(p))
				draw_lines[current_ghost].points = local_points
				ghost.path = new_path


		Ghost.CORNER:
			if ghost.path.size() < 3:
				var new_pos := Vector2.ZERO
				match ghost_names[current_ghost]:
					"Red":
						new_pos = Vector2(randf_range(264, 372), randf_range(24, 120))
					"Pink":
						new_pos = Vector2(randf_range(156, 264), randf_range(24, 120))
					"Blue":
						new_pos = Vector2(randf_range(264, 372), randf_range(156, 270))
					"Orange":
						new_pos = Vector2(randf_range(156, 264), randf_range(156, 270))

				var new_path := NavigationServer2D.map_get_path(map, ghost_snapped_pos, new_pos, true)
				if new_path.is_empty(): return

				var local_points := PackedVector2Array()
				for p in new_path:
					local_points.append(draw_lines[current_ghost].to_local(p))
				draw_lines[current_ghost].points = local_points
				ghost.path = new_path


		Ghost.SCARED:
			# --- LÓGICA DE HUIDA CON IA (NUEVO) ---
			var new_path := PackedVector2Array()
			# Los fantasmas con IA (Red, Pink, Blue) usan su IA para huir.
			# Orange usa una lógica aleatoria simple.
			match ghost_names[current_ghost]:
				"Red":
					var best_dir = get_minimax_move_alphabeta(ghost_snapped_pos, player.global_position, ghost.state)
					if best_dir != Vector2.ZERO:
						var far_target = ghost_snapped_pos + best_dir * 1000.0
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, far_target, true)
					if new_path.is_empty(): # Fallback a lógica aleatoria
						var random_pos = Vector2(randf_range(156, 372), randf_range(24, 270))
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, random_pos, true)
				
				"Pink":
					var best_dir = get_minimax_move_classic(ghost_snapped_pos, player.global_position, ghost.state)
					if best_dir != Vector2.ZERO:
						var far_target = ghost_snapped_pos + best_dir * 1000.0
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, far_target, true)
					if new_path.is_empty(): # Fallback
						var random_pos = Vector2(randf_range(156, 372), randf_range(24, 270))
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, random_pos, true)

				"Blue":
					var best_dir = get_minimax_move_expectimax(ghost_snapped_pos, player.global_position, ghost.state)
					if best_dir != Vector2.ZERO:
						var far_target = ghost_snapped_pos + best_dir * 1000.0
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, far_target, true)
					if new_path.is_empty(): # Fallback
						var random_pos = Vector2(randf_range(156, 372), randf_range(24, 270))
						new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, random_pos, true)
				
				"Orange":
					# Orange mantiene su lógica aleatoria
					var new_pos := Vector2.ZERO
					var attempts := 0
					while attempts < 10:
						attempts += 1
						var random_pos = Vector2(randf_range(156, 372), randf_range(24, 270))
						if random_pos.distance_to(player.global_position) > 6 * tile_size:
							new_pos = random_pos
							break
					new_path = NavigationServer2D.map_get_path(map, ghost_snapped_pos, new_pos, true)

			# Asignar la ruta
			if new_path.is_empty(): return
			var local_points := PackedVector2Array()
			for p in new_path:
				local_points.append(draw_lines[current_ghost].to_local(p))
			draw_lines[current_ghost].points = local_points
			ghost.path = new_path


		Ghost.EATEN:
			var home_pos = ghost.start_pos
			var new_path := NavigationServer2D.map_get_path(map, ghost_snapped_pos, home_pos, true)
			if new_path.is_empty(): return

			var local_points := PackedVector2Array()
			for p in new_path:
				local_points.append(draw_lines[current_ghost].to_local(p))
			draw_lines[current_ghost].points = local_points
			ghost.path = new_path


		Ghost.IN_PEN:
			ghost.path = PackedVector2Array()


# --------------------------------------------------------------------
# --- EVENTOS Y AUDIO ------------------------------------------------
# --------------------------------------------------------------------
func _on_ExitL_body_entered(body):
	if body is PacMan or body is Ghost:
		body.warp_to($"Arena/Exit-R".global_position)


func _on_ExitR_body_entered(body):
	if body is PacMan or body is Ghost:
		body.warp_to($"Arena/Exit-L".global_position)


func _on_Power_Pellet_eaten():
	$Sounds/Ghost_Woo.stop()
	ghost_bonus = 200
	$UI.add_score(50)
	for ghost in ghosts:
		ghost.scared()
	for _i in 4:
		ghost_repath()
	scattering = true
	$Scatter_Timer.start(vulnerable_time)
	pellets_left -= 1
	if pellets_left == 0:
		level_won()


func _on_Pellet_eaten():
	$UI.add_score(10)
	pellets_left -= 1
	if pellets_left % 2 == 1:
		$Sounds/Dot_1.play()
	else:
		$Sounds/Dot_2.play()
	if pellets_left == starting_pellets - 1:
		play_appropriate_ghost_audio()
		ghosts[0].start()
		ghosts[1].start()
	if pellets_left == starting_pellets - 30:
		ghosts[2].start()
	if pellets_left == starting_pellets - 90:
		ghosts[3].start()
	if pellets_left == 0:
		level_won()


func _on_Ai_Timer_timeout():
	ghost_repath()


func _on_Scatter_Timer_timeout():
	scattering = !scattering
	if vulnearable_ghosts != 0:
		vulnearable_ghosts = 0
		play_appropriate_ghost_audio()
	if scattering:
		$Scatter_Timer.start(7)
		for ghost in ghosts:
			ghost.corner()
	else:
		$Scatter_Timer.start(20)
		for ghost in ghosts:
			ghost.chase()


func _on_ghost_ate_player(_ghost):
	if not mortal:
		return
	stop_ghost_audio()
	lives -= 1
	$UI.draw_lives(lives)
	player.die()
	for ghost in ghosts:
		ghost.reset()
	await get_tree().create_timer(0.10).timeout
	starting_pellets = pellets_left
	if lives < 0:
		$UI.game_over()
		await get_tree().create_timer(5.0).timeout
		lives = 5
		$UI.reset()
		$UI.draw_lives(lives)
		$Sounds/Intro.play()
		reset()


func toggle_debug_draw():
	for line in draw_lines:
		line.visible = !line.visible


func _on_player_ate_ghost(ghost):
	$UI.add_score(ghost_bonus)
	ghost_bonus *= 2
	var new_path := NavigationServer2D.map_get_path(map, ghost.position, Vector2(264, 140), true)
	draw_lines[current_ghost].points = new_path
	ghost.path = new_path
	vulnearable_ghosts -= 1
	eaten_ghosts += 1
	play_appropriate_ghost_audio()


func _on_ghost_became_vulnerable():
	vulnearable_ghosts += 1
	play_appropriate_ghost_audio()


func _on_ghost_restored():
	eaten_ghosts -= 1
	play_appropriate_ghost_audio()


func play_appropriate_ghost_audio():
	return


func stop_ghost_audio():
	return



func _on_Intro_finished():
	player.movement_enabled = true


func _on_PacMan_player_reset():
	if lives >= 0:
		player.movement_enabled = true


func toggle_invulnerability():
	mortal = !mortal
