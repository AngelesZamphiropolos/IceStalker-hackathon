extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var speed = 120.0

# --- REFERENCIAS (Estos nodos TIENEN que estar en la lista de la izquierda) ---
@onready var sprite = $AnimatedSprite2D
@onready var nav_agent = $NavigationAgent2D
@onready var raycast = $RayCast2D
@onready var detection_area = $DetectionArea 

# --- MÁQUINA DE ESTADOS ---
enum State { PATROL, CHASE, SEARCH }
var current_state = State.PATROL
var player_ref: Node2D = null
var last_known_pos: Vector2

func _ready():
	# Si te sigue saliendo error aquí, es porque NO agregaste el NavigationAgent2D en el paso 1
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 20.0
	
	# Conectar las señales automáticamente
	if detection_area:
		if not detection_area.body_entered.is_connected(_on_body_entered):
			detection_area.body_entered.connect(_on_body_entered)
		if not detection_area.body_exited.is_connected(_on_body_exited):
			detection_area.body_exited.connect(_on_body_exited)

func _physics_process(delta):
	match current_state:
		State.PATROL:
			velocity = Vector2.ZERO
		State.CHASE:
			_chase_state()
		State.SEARCH:
			_search_state()
			
	move_and_slide()
	_handle_animations()

# --- FUNCIONES DE MOVIMIENTO ---

func _chase_state():
	if player_ref:
		nav_agent.target_position = player_ref.global_position
		_check_line_of_sight()
		
		var next_pos = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_pos)
		velocity = direction * speed
	else:
		current_state = State.PATROL

func _search_state():
	nav_agent.target_position = last_known_pos
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		current_state = State.PATROL
	else:
		var next_pos = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_pos)
		velocity = direction * speed

# --- ANIMACIONES (Con TU nombre correcto) ---

func _handle_animations():
	if velocity.length() > 0:
		if abs(velocity.x) > abs(velocity.y):
			# MOVIMIENTO HORIZONTAL
			# Usamos tu nombre exacto: "derecha_izquierda"
			sprite.play("derecha_izquierda") 
			
			if velocity.x < 0:
				sprite.flip_h = true  # Mira a la IZQUIERDA (Invertido)
			else:
				sprite.flip_h = false # Mira a la DERECHA (Normal)
		else:
			# MOVIMIENTO VERTICAL
			sprite.flip_h = false
			if velocity.y < 0:
				sprite.play("arriba")
			else:
				sprite.play("abajo")
	else:
		sprite.play("abajo")

# --- VISIÓN ---

func _check_line_of_sight():
	if player_ref:
		raycast.target_position = to_local(player_ref.global_position)
		raycast.force_raycast_update()
		var collider = raycast.get_collider()
		if collider and collider != player_ref:
			last_known_pos = player_ref.global_position
			current_state = State.SEARCH

# --- SEÑALES ---

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_ref = body
		current_state = State.CHASE

func _on_body_exited(body):
	if body == player_ref:
		last_known_pos = player_ref.global_position
		current_state = State.SEARCH
