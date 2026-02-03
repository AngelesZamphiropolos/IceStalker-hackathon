extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var vidas: int = 3
var es_invulnerable: bool = false
@export_group("Movimiento")
@export var velocidad_caminar: float = 120.0
@export var velocidad_correr: float = 250.0
@export var velocidad_herido: float = 50.0 # ### NUEVO: Velocidad lenta al recibir daño

@export_group("Opciones")
@export var usar_suavizado_camara: bool = true

# --- REFERENCIAS ---
@onready var sprite_animado: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_interaccion: Area2D = $AreaInteraccion
@onready var camara: Camera2D = $Camera2D

# --- ESTADO INTERNO ---
var ultima_direccion: Vector2 = Vector2.DOWN
var esta_sentado: bool = false
var input_bloqueado: bool = false
var fuerza_temblor: float = 0.0
var esta_ralentizado: bool = false # ### NUEVO: Controla si camina lento por el golpe

func _ready():
	if camara:
		camara.position_smoothing_enabled = usar_suavizado_camara

func _process(delta):
	# Efecto de temblor en cámara
	if camara and fuerza_temblor > 0:
		camara.offset = Vector2(
			randf_range(-fuerza_temblor, fuerza_temblor),
			randf_range(-fuerza_temblor, fuerza_temblor)
		)
		fuerza_temblor = lerp(fuerza_temblor, 0.0, 5.0 * delta)
		
		if fuerza_temblor < 0.1:
			fuerza_temblor = 0
			camara.offset = Vector2.ZERO

func _physics_process(_delta):
	# Limpieza de cámara en físicas (redundancia por seguridad)
	if camara and camara.offset.length() > 0:
		camara.offset = lerp(camara.offset, Vector2.ZERO, 0.1)

	if esta_sentado:
		chequear_levantarse()
		return
	
	if input_bloqueado:
		return

	var direccion = obtener_input()
	aplicar_movimiento(direccion)
	actualizar_animacion(direccion)
	manejar_acciones()

# --- LÓGICA DE MOVIMIENTO ---

func obtener_input() -> Vector2:
	return Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")

func aplicar_movimiento(dir: Vector2):
	var velocidad_actual = velocidad_caminar
	
	# ### NUEVO: Lógica de prioridad de velocidades
	if esta_ralentizado:
		velocidad_actual = velocidad_herido # Prioridad 1: Estás herido (Lento)
	elif Input.is_action_pressed("correr"):
		velocidad_actual = velocidad_correr # Prioridad 2: Correr

	if dir != Vector2.ZERO:
		velocity = dir * velocidad_actual
		ultima_direccion = dir
	else:
		velocity = Vector2.ZERO

	move_and_slide()

# --- LÓGICA VISUAL (ANIMACIONES) ---

func actualizar_animacion(dir: Vector2):
	var accion = _determinar_accion()
	var sufijo = _determinar_direccion_y_flip(dir)
	var nombre_final = accion + sufijo
	
	if sprite_animado.animation != nombre_final:
		sprite_animado.play(nombre_final)

func _determinar_accion() -> String:
	if velocity == Vector2.ZERO:
		return "idle"
	return "run" if velocity.length() > velocidad_caminar + 10 else "walk"

func _determinar_direccion_y_flip(dir: Vector2) -> String:
	var referencia = dir if dir != Vector2.ZERO else ultima_direccion
	
	if referencia.y < 0:
		sprite_animado.flip_h = false
		return "_up"
	elif referencia.y > 0:
		sprite_animado.flip_h = false
		return "_down"
	
	sprite_animado.flip_h = (referencia.x < 0)
	return ""

# --- SISTEMA DE INTERACCIÓN ---

func manejar_acciones():
	if Input.is_action_just_pressed("interactuar"):
		_buscar_interaccion()
	
	if Input.is_action_just_pressed("sentarse"):
		_entrar_estado_sentado()

func _buscar_interaccion():
	var objetos = area_interaccion.get_overlapping_bodies()
	for objeto in objetos:
		if objeto.has_method("activar_minijuego"):
			objeto.activar_minijuego()
			return 

# --- ESTADOS ESPECIALES ---

func _entrar_estado_sentado():
	esta_sentado = true
	velocity = Vector2.ZERO
	sprite_animado.play("sit")

func chequear_levantarse():
	if obtener_input() != Vector2.ZERO:
		esta_sentado = false

# --- SISTEMA DE DAÑO (MODIFICADO) ---

func recibir_dano():
	if es_invulnerable: return
	
	vidas -= 1
	print("¡RECIBÍ DMG! Vidas restantes: ", vidas)
	
	if vidas <= 0:
		game_over()
		return # <--- AGREGA ESTO para que no intente animar un cadáver

	# ... resto del código (color rojo, invulnerabilidad) ...

	# 1. Efecto Visual: ROJO INTENSO
	sprite_animado.modulate = Color(1, 0, 0) # Rojo puro
	var tween = create_tween()
	# Vuelve a color normal (blanco) en 0.5 segundos
	tween.tween_property(sprite_animado, "modulate", Color.WHITE, 0.5)
	
	# 2. Efecto Mecánico: RALENTIZAR
	aplicar_ralentizacion()

	# 3. Invulnerabilidad
	es_invulnerable = true
	await get_tree().create_timer(1.5).timeout
	es_invulnerable = false

func aplicar_ralentizacion():
	esta_ralentizado = true
	# Esperamos 0.5 segundos caminando lento
	await get_tree().create_timer(0.5).timeout
	esta_ralentizado = false

func game_over():
	print("GAME OVER")
	sprite_animado.modulate = Color(0.5, 0, 0) # Rojo oscuro muerto
	get_tree().paused = true 

func temblar(fuerza_nueva: float):
	if fuerza_nueva > fuerza_temblor:
		fuerza_temblor = fuerza_nueva
