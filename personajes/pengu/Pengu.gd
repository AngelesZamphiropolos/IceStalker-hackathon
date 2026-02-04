extends CharacterBody2D

# --- configuración de comportamiento ---
# ajustes de velocidad para que se sienta distinto en cada fase
@export_group("Velocidades")
@export var velocidad_normal: float = 95.0   # patrulla tranqui
@export var velocidad_persecucion: float = 120.0 # cuando te ve se pone las pilas
@export var velocidad_huida: float = 160.0 # corre rápido después de pegar (hit and run)

@export_group("IA")
@export var rango_patrulla: float = 500.0 # qué tan lejos se va a pasear
@export var distancia_temblor: float = 550.0 # a partir de acá empieza a temblar la cámara

@export_group("Audio")
@export var sfx_grito: AudioStream 

# --- referencias (nodos) ---
# nav_agent es clave, es el gps para que no se choque con las paredes
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea       
@onready var hitbox_ataque: Area2D = $HitboxAtaque        
@onready var audio_susto: AudioStreamPlayer2D = $AudioSusto 

# --- máquina de estados ---
# lógica básica para organizar el cerebro del enemigo
enum Estado { PATRULLAR, PERSEGUIR, HUIR }
var estado_actual = Estado.PATRULLAR
var objetivo: Node2D = null 

var tiempo_huida_restante: float = 0.0
var duracion_huida: float = 2.5 
var ultimo_estado_log: int = -1 

func _ready():
	# check de seguridad para que no explote si falta algo
	if not nav_agent or not detection_area or not hitbox_ataque:
		set_physics_process(false) 
		return
	
	# ajustes finos del pathfinding
	nav_agent.path_desired_distance = 20.0
	nav_agent.target_desired_distance = 10.0
	
	# hay que esperar un frame de físicas para que el mapa se cargue bien, sino tira error
	await get_tree().physics_frame
	buscar_nuevo_punto_patrulla()

func _physics_process(delta):
	_imprimir_cambio_estado()
	
	# el cerebro principal: decide qué hacer según el estado
	match estado_actual:
		Estado.PATRULLAR:
			# si llegó a destino, busca otro punto random
			if nav_agent.is_navigation_finished():
				buscar_nuevo_punto_patrulla()
				
		Estado.PERSEGUIR:
			if is_instance_valid(objetivo):
				# actualiza el gps a la posición del jugador todo el tiempo
				nav_agent.target_position = objetivo.global_position
				procesar_ambiente_terror()
				chequear_ataque()
			else:
				# si el jugador desaparece, vuelve a patrullar
				cambiar_estado(Estado.PATRULLAR)

		Estado.HUIR:
			procesar_huida(delta)

	# mover y animar siempre al final
	aplicar_movimiento()
	animar_pingui()

# --- lógica de movimiento ---

func aplicar_movimiento():
	# si ya llegamos, frenamos
	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	# preguntamos al nav_agent cuál es el siguiente paso
	var siguiente_pos = nav_agent.get_next_path_position()
	var direccion = global_position.direction_to(siguiente_pos)
	
	# elegimos la velocidad según qué esté haciendo
	var velocidad_final = velocidad_normal
	match estado_actual:
		Estado.PERSEGUIR: velocidad_final = velocidad_persecucion
		Estado.HUIR: velocidad_final = velocidad_huida
	
	velocity = direccion * velocidad_final
	move_and_slide()

func buscar_nuevo_punto_patrulla():
	# elige un punto al azar cerca de donde está
	var range_x = randf_range(-rango_patrulla, rango_patrulla)
	var range_y = randf_range(-rango_patrulla, rango_patrulla)
	nav_agent.target_position = global_position + Vector2(range_x, range_y)

# --- sistema de combate ---

func chequear_ataque():
	# revisa si el jugador está tocando la hitbox de ataque
	var cuerpos = hitbox_ataque.get_overlapping_bodies()
	for cuerpo in cuerpos:
		if cuerpo == self: continue # no pegarse a sí mismo
		if cuerpo == objetivo:
			atacar()
			break

func atacar():
	# aplica daño y sale corriendo (mecánica de golpe y fuga)
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
	# cuenta regresiva para dejar de huir
	tiempo_huida_restante -= delta
	if tiempo_huida_restante <= 0:
		cambiar_estado(Estado.PATRULLAR)
		buscar_nuevo_punto_patrulla()

# --- sistema de visión (jumpscare) ---

func _on_detection_area_body_entered(body):
	if estado_actual == Estado.HUIR: return # si está huyendo ignora al jugador
	if body == self or "colisiones" in body.name: return

	# detecta si es el jugador usando grupos
	if body.name == "Jugador" or body.name == "Player" or body.is_in_group("Jugador"):
		objetivo = body
		cambiar_estado(Estado.PERSEGUIR)
		
		# acá arranca el susto: sonido fuerte
		if sfx_grito:
			audio_susto.stream = sfx_grito
			audio_susto.volume_db = 24.0 # volumen alto para asustar
			audio_susto.play()
		
		# sacudón de cámara fuerte
		if objetivo.has_method("temblar"):
			objetivo.temblar(15.0) 

func _on_detection_area_body_exited(body):
	# si se escapó de la vista, volvemos a patrullar
	if body == objetivo and estado_actual != Estado.HUIR:
		objetivo = null
		
		# nota: no paramos el audio para que se desvanezca solo con la distancia
		
		cambiar_estado(Estado.PATRULLAR)
		buscar_nuevo_punto_patrulla()

# --- efectos ---

func procesar_ambiente_terror():
	if not objetivo: return
	# hace temblar la pantalla un poquito si está cerca, para meter tensión
	var distancia = global_position.distance_to(objetivo.global_position)
	if distancia < distancia_temblor:
		var fuerza = (distancia_temblor - distancia) * 0.015
		if objetivo.has_method("temblar"):
			objetivo.temblar(fuerza)

func animar_pingui():
	# lógica simple de animación según hacia dónde se mueve
	if velocity.length() > 5:
		if abs(velocity.x) > abs(velocity.y):
			sprite.play("walk") 
			sprite.flip_h = (velocity.x < 0)
		else:
			if velocity.y < 0: sprite.play("walk_up")
			else: sprite.play("walk_down")
	else:
		sprite.play("idle")

# --- utilidades ---

func cambiar_estado(nuevo_estado):
	estado_actual = nuevo_estado

func _imprimir_cambio_estado():
	if estado_actual != ultimo_estado_log:
		ultimo_estado_log = estado_actual
