extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var speed = 150.0
@export var player_ref: Node2D = null # Arrastrar al Player aquí en el inspector o buscarlo por código

# --- NODOS ---
# Como en tu escena "pengu0.tscn" usas AnimatedSprite2D, lo referenciamos así:
@onready var sprite = $AnimatedSprite2D 
# Necesitas agregar estos nodos a tu escena si no están:
@onready var nav_agent = $NavigationAgent2D 

func _physics_process(delta):
	# Si no hay jugador, no hacemos nada
	if player_ref == null:
		# Intentamos buscar al jugador si está en el grupo "Player"
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player_ref = players[0]
		return

	# 1. Perseguir al jugador
	nav_agent.target_position = player_ref.global_position
	
	# 2. Calcular movimiento
	if nav_agent.is_navigation_finished():
		return # Ya llegó

	var current_pos = global_position
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = current_pos.direction_to(next_path_pos)
	
	velocity = direction * speed
	move_and_slide()
	
	# 3. Girar el sprite según la dirección
	if velocity.x < 0:
		sprite.flip_h = false # O true, depende de tu imagen original
	elif velocity.x > 0:
		sprite.flip_h = true
