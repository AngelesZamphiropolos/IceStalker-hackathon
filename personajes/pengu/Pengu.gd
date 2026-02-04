extends CharacterBody2D

# --- CONFIGURACIÓN DE COMPORTAMIENTO ---
@export_group("Velocidades")
@export var velocidad_normal: float = 95.0
@export var velocidad_persecucion: float = 120.0
@export var velocidad_huida: float = 160.0

@export_group("IA")
@export var rango_patrulla: float = 500.0
@export var distancia_temblor: float = 550.0

@export_group("Audio")
@export var sfx_grito: AudioStream 

# --- REFERENCIAS (NODOS) ---
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea      
@onready var hitbox_ataque: Area2D = $HitboxAtaque        
@onready var audio_susto: AudioStreamPlayer2D = $AudioSusto 

# --- MÁQUINA DE ESTADOS ---
enum Estado { PATRULLAR, PERSEGUIR, HUIR }
var estado_actual = Estado.PATRULLAR
var objetivo: Node2D = null 

var tiempo_huida_restante: float = 0.0
var duracion_huida: float = 2.5 
var ultimo_estado_log: int = -1 

func _ready():
	if not nav_agent or not detection_area or not hitbox_ataque:
		set_physics_process(false) 
		return
	
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 10.0
	
	await get_tree().physics_frame
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
				procesar_ambiente_terror()
				chequear_ataque()
			else:
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
		if cuerpo == self: continue
		if cuerpo == objetivo:
			atacar()
			break

func atacar():
	if objetivo.has_method("recibir_dano"):
		objetivo.recibir_dano()
		if objetivo.has_method("temblar"):
			objetivo.temblar(8.0) 
		iniciar_huida()

func iniciar_huida():
	cambiar_estado(Estado.HUIR)
	tiempo_huida_restante = duracion_huida
	objetivo = null 
	buscar_nuevo_punto_patrulla()

func procesar_huida(delta):
	tiempo_huida_restante -= delta
	if tiempo_huida_restante <= 0:
		cambiar_estado(Estado.PATRULLAR)
		buscar_nuevo_punto_patrulla()

# --- SISTEMA DE VISIÓN (JUMPSCARE) ---

func _on_detection_area_body_entered(body):
	if estado_actual == Estado.HUIR: return
	if body == self or "colisiones" in body.name: return

	if body.name == "Jugador" or body.name == "Player" or body.is_in_group("Jugador"):
		objetivo = body
		cambiar_estado(Estado.PERSEGUIR)
		
		# REPRODUCIR SONIDO FUERTE (+24 dB)
		if sfx_grito:
			audio_susto.stream = sfx_grito
			audio_susto.volume_db = 24.0
			audio_susto.play()
		
		# TEMBLOR VIOLENTO
		if objetivo.has_method("temblar"):
			objetivo.temblar(15.0) 

func _on_detection_area_body_exited(body):
	if body == objetivo and estado_actual != Estado.HUIR:
		objetivo = null
		
		# --- CORRECCIÓN ---
		# Quitamos el 'audio_susto.stop()'
		# Ahora el sonido seguirá reproduciéndose solo hasta que termine el archivo
		
		cambiar_estado(Estado.PATRULLAR)
		buscar_nuevo_punto_patrulla()

# --- EFECTOS ---

func procesar_ambiente_terror():
	if not objetivo: return
	var distancia = global_position.distance_to(objetivo.global_position)
	if distancia < distancia_temblor:
		var fuerza = (distancia_temblor - distancia) * 0.015
		if objetivo.has_method("temblar"):
			objetivo.temblar(fuerza)

func animar_pingui():
	if velocity.length() > 5:
		if abs(velocity.x) > abs(velocity.y):
			sprite.play("walk") 
			sprite.flip_h = (velocity.x < 0)
		else:
			if velocity.y < 0: sprite.play("walk_up")
			else: sprite.play("walk_down")
	else:
		sprite.play("idle")

# --- UTILIDADES ---

func cambiar_estado(nuevo_estado):
	estado_actual = nuevo_estado

func _imprimir_cambio_estado():
	if estado_actual != ultimo_estado_log:
		ultimo_estado_log = estado_actual
