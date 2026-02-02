extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export_group("Movimiento")
@export var velocidad_caminar: float = 120.0
@export var velocidad_correr: float = 250.0

@export_group("Opciones")
@export var usar_suavizado_camara: bool = true

# --- REFERENCIAS ---
@onready var sprite_animado: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_interaccion: Area2D = $AreaInteraccion
@onready var camara: Camera2D = $Camera2D

# --- ESTADO INTERNO ---
var ultima_direccion: Vector2 = Vector2.DOWN
var esta_sentado: bool = false
var input_bloqueado: bool = false # Útil para cinemáticas o diálogos

func _ready():
	# Configuración inicial de la cámara
	if camara:
		camara.position_smoothing_enabled = usar_suavizado_camara

func _physics_process(_delta):
	# Si está sentado o bloqueado, no procesamos movimiento normal
	if esta_sentado:
		chequear_levantarse()
		return
	
	if input_bloqueado:
		return

	# Ciclo principal de juego
	var direccion = obtener_input()
	aplicar_movimiento(direccion)
	actualizar_animacion(direccion)
	manejar_acciones()

# --- LÓGICA DE MOVIMIENTO ---

func obtener_input() -> Vector2:
	return Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")

func aplicar_movimiento(dir: Vector2):
	var velocidad_actual = velocidad_caminar
	
	if Input.is_action_pressed("correr"):
		velocidad_actual = velocidad_correr

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
	# Margen de seguridad para diferenciar caminar de correr
	return "run" if velocity.length() > velocidad_caminar + 10 else "walk"

func _determinar_direccion_y_flip(dir: Vector2) -> String:
	# Si no hay input, usamos la última dirección registrada
	var referencia = dir if dir != Vector2.ZERO else ultima_direccion
	
	if referencia.y < 0:
		sprite_animado.flip_h = false
		return "_up"
	elif referencia.y > 0:
		sprite_animado.flip_h = false
		return "_down"
	
	# Lógica lateral
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
