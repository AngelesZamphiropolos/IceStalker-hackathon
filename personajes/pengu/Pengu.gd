extends CharacterBody2D

# --- CONFIGURACIÓN DE COMPORTAMIENTO ---
@export_group("Velocidades")
@export var velocidad_normal: float = 95.0
@export var velocidad_persecucion: float = 120.0
@export var velocidad_huida: float = 160.0

@export_group("IA")
@export var rango_patrulla: float = 500.0
@export var distancia_temblor: float = 550.0 # Rango aumentado para sentirlo antes

# --- REFERENCIAS (NODOS) ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea      # Visión
@onready var hitbox_ataque: Area2D = $HitboxAtaque        # Daño

# --- MÁQUINA DE ESTADOS ---
enum Estado { PATRULLAR, PERSEGUIR, HUIR }
var estado_actual = Estado.PATRULLAR
var objetivo: Node2D = null 

# Variables internas
var tiempo_huida_restante: float = 0.0
var duracion_huida: float = 2.5 
var ultimo_estado_log: int = -1 # Para evitar spam en consola

func _ready():
	# Validación de seguridad para evitar crashes
	if not nav_agent or not detection_area or not hitbox_ataque:
		printerr("[ERROR] Faltan nodos esenciales en el Pingüino.")
		set_physics_process(false) # Desactivar si falta algo vital
		return
	
	# Configuración de navegación
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 10.0
	
	# Esperar inicialización del mapa
	await get_tree().physics_frame
	print("[IA] Pingüino operativo y patrullando.")
	buscar_nuevo_punto_patrulla()

func _physics_process(delta):
	_imprimir_cambio_estado()
	
	match estado_actual:
		Estado.PATRULLAR:
			if nav_agent.is_navigation_finished():
				buscar_nuevo_punto_patrulla()
				
		Estado.PERSEGUIR:
			if is_instance_valid(objetivo):
				nav_agent.target_position = objetivo.global_position
				procesar_ambiente_terror() # Temblor
				chequear_ataque()
			else:
				# Si el objetivo desaparece (ej. muere o cambia escena), volver a patrullar
				cambiar_estado(Estado.PATRULLAR)

		Estado.HUIR:
			procesar_huida(delta)

	aplicar_movimiento()
	animar_pingui()

# --- LÓGICA DE MOVIMIENTO ---

func aplicar_movimiento():
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var siguiente_pos = nav_agent.get_next_path_position()
	var direccion = global_position.direction_to(siguiente_pos)
	
	var velocidad_final = velocidad_normal
	match estado_actual:
		Estado.PERSEGUIR: velocidad_final = velocidad_persecucion
		Estado.HUIR: velocidad_final = velocidad_huida
	
	velocity = direccion * velocidad_final
	move_and_slide()

func buscar_nuevo_punto_patrulla():
	var range_x = randf_range(-rango_patrulla, rango_patrulla)
	var range_y = randf_range(-rango_patrulla, rango_patrulla)
	nav_agent.target_position = global_position + Vector2(range_x, range_y)

# --- SISTEMA DE COMBATE ---

func chequear_ataque():
	var cuerpos = hitbox_ataque.get_overlapping_bodies()
	
	for cuerpo in cuerpos:
		# FIX: Ignorarse a sí mismo para no procesar colisión propia
		if cuerpo == self: 
			continue
			
		if cuerpo == objetivo:
			atacar()
			break

func atacar():
	if objetivo.has_method("recibir_dano"):
		print("[COMBATE] Atacando a: ", objetivo.name)
		objetivo.recibir_dano()
		
		# Feedback de golpe fuerte
		if objetivo.has_method("temblar"):
			objetivo.temblar(8.0) 
			
		iniciar_huida()

func iniciar_huida():
	cambiar_estado(Estado.HUIR)
	tiempo_huida_restante = duracion_huida
	objetivo = null # Olvidamos al jugador momentáneamente
	
	# Correr a un punto aleatorio lejos
	buscar_nuevo_punto_patrulla()

func procesar_huida(delta):
	tiempo_huida_restante -= delta
	if tiempo_huida_restante <= 0:
		cambiar_estado(Estado.PATRULLAR)
		buscar_nuevo_punto_patrulla()

# --- SISTEMA DE VISIÓN ---

func _on_detection_area_body_entered(body):
	if estado_actual == Estado.HUIR: return
	
	# Filtros de seguridad
	if body == self or "colisiones" in body.name: return

	# Detección del Jugador
	if body.name == "Jugador" or body.name == "Player" or body.is_in_group("Jugador"):
		print(">>> [IA] Jugador detectado. Iniciando persecución. <<<")
		objetivo = body
		cambiar_estado(Estado.PERSEGUIR)

func _on_detection_area_body_exited(body):
	if body == objetivo and estado_actual != Estado.HUIR:
		print("[IA] Objetivo perdido de vista.")
		objetivo = null
		cambiar_estado(Estado.PATRULLAR)
		buscar_nuevo_punto_patrulla()

# --- EFECTOS Y AMBIENTE ---

func procesar_ambiente_terror():
	if not objetivo: return
	
	var distancia = global_position.distance_to(objetivo.global_position)
	
	# Rango ampliado a 550px para generar tensión antes
	if distancia < distancia_temblor:
		# Fórmula ajustada: (Max - Actual) * Factor suave
		# Lejos: Tiembla poco (0.5). Cerca: Tiembla fuerte (5.0)
		var fuerza = (distancia_temblor - distancia) * 0.015
		
		if objetivo.has_method("temblar"):
			objetivo.temblar(fuerza)

func animar_pingui():
	if velocity.length() > 5:
		# Prioridad Horizontal
		if abs(velocity.x) > abs(velocity.y):
			sprite.play("walk") 
			sprite.flip_h = (velocity.x < 0)
		else:
			# Vertical
			if velocity.y < 0: sprite.play("walk_up")
			else: sprite.play("walk_down")
	else:
		sprite.play("idle")

# --- UTILIDADES ---

func cambiar_estado(nuevo_estado):
	estado_actual = nuevo_estado

func _imprimir_cambio_estado():
	if estado_actual != ultimo_estado_log:
		print("[ESTADO] ", Estado.keys()[estado_actual])
		ultimo_estado_log = estado_actual
