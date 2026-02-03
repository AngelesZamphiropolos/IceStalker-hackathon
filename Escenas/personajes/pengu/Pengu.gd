extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var speed = 100.0        # Velocidad normal
@export var kill_distance = 35.0 # Distancia para matarte
@export var patrol_range = 500.0 # Rango amplio para patrullar todo el edificio

# --- REFERENCIAS ---
@onready var sprite = $AnimatedSprite2D
@onready var nav_agent = $NavigationAgent2D
@onready var raycast = $RayCast2D
@onready var detection_area = $DetectionArea 
@onready var timer = $Timer 

# --- ESTADOS ---
enum State { PATROL, CHASE, SEARCH }
var current_state = State.PATROL
var player_ref: Node2D = null
var last_known_pos: Vector2

func _ready():
	# Configuración para que no se pegue a las paredes
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 20.0
	
	# Activa la "Evitación" de obstáculos
	nav_agent.avoidance_enabled = true
	
	# Conectar Timer y arrancar patrulla
	if timer: timer.timeout.connect(_on_timer_timeout)
	call_deferred("_get_random_patrol_point") # Empieza a caminar apenas nace

func _physics_process(delta):
	# 1. Chequeo de Muerte
	if player_ref and global_position.distance_to(player_ref.global_position) < kill_distance:
		print("¡TE ATRAPÓ! 💀")
		get_tree().reload_current_scene()
	
	# 2. Máquina de Estados
	match current_state:
		State.PATROL:
			# ¡CAMBIO CLAVE! Si llega, no para. Busca otro punto.
			if nav_agent.is_navigation_finished():
				_get_random_patrol_point()
			else:
				_move_to_target()
				
		State.CHASE:
			_chase_state()
			
		State.SEARCH:
			_search_state()
			
	move_and_slide()
	_handle_animations()

# --- LÓGICA DE MOVIMIENTO ---

func _move_to_target():
	var next_pos = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_pos)
	velocity = direction * speed

func _chase_state():
	if player_ref:
		nav_agent.target_position = player_ref.global_position
		_check_line_of_sight()
		_move_to_target()
	else:
		current_state = State.PATROL

func _search_state():
	# Va a donde te vio por última vez
	nav_agent.target_position = last_known_pos
	if nav_agent.is_navigation_finished():
		# Si llega y no estás, vuelve a patrullar inmediatamente
		current_state = State.PATROL
		_get_random_patrol_point()
	else:
		_move_to_target()

# --- PATRULLAJE ALEATORIO ---

func _on_timer_timeout():
	# "Desatascador": Si lleva 4 segundos buscando y no llega, cambia de ruta
	if current_state == State.PATROL:
		_get_random_patrol_point()

func _get_random_patrol_point():
	var random_x = randf_range(-patrol_range, patrol_range)
	var random_y = randf_range(-patrol_range, patrol_range)
	var random_point = global_position + Vector2(random_x, random_y)
	nav_agent.target_position = random_point

# --- VISIÓN Y ANIMACIÓN ---

func _handle_animations():
	if velocity.length() > 0:
		if abs(velocity.x) > abs(velocity.y):
			sprite.play("derecha_izquierda") 
			sprite.flip_h = (velocity.x < 0)
		else:
			sprite.flip_h = false
			if velocity.y < 0: sprite.play("arriba")
			else: sprite.play("abajo")
	else:
		sprite.play("abajo")

func _check_line_of_sight():
	if player_ref:
		raycast.target_position = to_local(player_ref.global_position)
		raycast.force_raycast_update()
		var collider = raycast.get_collider()
		# Si choca con una pared antes que con el jugador, pierde la visión
		if collider and collider != player_ref:
			last_known_pos = player_ref.global_position
			current_state = State.SEARCH

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_ref = body
		current_state = State.CHASE

func _on_body_exited(body):
	if body == player_ref:
		last_known_pos = player_ref.global_position
		current_state = State.SEARCH
		player_ref = null
