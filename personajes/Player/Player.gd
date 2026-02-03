extends CharacterBody2D

# --- CONFIGURACIÓN ---
@export var vidas: int = 3
var es_invulnerable: bool = false

@export_group("Iluminación")
@export var rango_luz: float = 2.0 
@export var energia_luz: float = 1.0 

@export_group("Movimiento")
@export var velocidad_caminar: float = 120.0
@export var velocidad_correr: float = 250.0
@export var velocidad_herido: float = 50.0 

@export_group("Estamina (Resistencia)")
@export var max_estamina: float = 100.0
@export var tasa_drenaje: float = 25.0 # Cuánta estamina gasta por segundo al correr
@export var tasa_recarga: float = 15.0 # Cuánta recupera por segundo al caminar/quieto

@export_group("Opciones")
@export var usar_suavizado_camara: bool = true

# --- REFERENCIAS ---
@onready var sprite_animado: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_interaccion: Area2D = $AreaInteraccion
@onready var camara: Camera2D = $Camera2D
@onready var luz: PointLight2D = $PointLight2D
@onready var label_pensamiento = $LabelPensamiento

# --- ESTADO INTERNO ---
var ultima_direccion: Vector2 = Vector2.DOWN
var esta_sentado: bool = false
var input_bloqueado: bool = false
var fuerza_temblor: float = 0.0
var esta_ralentizado: bool = false 

# Variables nuevas para la estamina
var estamina_actual: float = 0.0
var esta_agotado: bool = false # El "bloqueo" cuando llegas a 0

func _ready():
	# Inicializamos la estamina carfada
	estamina_actual = max_estamina
	
	if camara:
		camara.position_smoothing_enabled = usar_suavizado_camara
	if luz:
		luz.texture_scale = rango_luz
		luz.energy = energia_luz

func _process(delta):
	# Efecto de temblor
	if camara and fuerza_temblor > 0:
		camara.offset = Vector2(
			randf_range(-fuerza_temblor, fuerza_temblor),
			randf_range(-fuerza_temblor, fuerza_temblor)
		)
		fuerza_temblor = lerp(fuerza_temblor, 0.0, 5.0 * delta)
		if fuerza_temblor < 0.1:
			fuerza_temblor = 0
			camara.offset = Vector2.ZERO
			
	# Parpadeo de luz ambiental
	if luz and randf() < 0.05: 
		luz.energy = randf_range(energia_luz * 0.8, energia_luz * 1.2)

func _physics_process(delta):
	if camara and camara.offset.length() > 0:
		camara.offset = lerp(camara.offset, Vector2.ZERO, 0.1)

	# Gestión de estamina constante 
	gestionar_estamina(delta)

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
	var velocidad_objetivo = velocidad_caminar
	var esta_intentando_correr = Input.is_action_pressed("correr")
	
	# Lógica de prioridades para la velocidad
	if esta_ralentizado:
		velocidad_objetivo = velocidad_herido # Prioridad 1: Golpeado
	
	elif esta_intentando_correr:
		# Solo corremos si nos movemos, tenemos aire y no estamos en cooldown
		if dir != Vector2.ZERO and not esta_agotado and estamina_actual > 0:
			velocidad_objetivo = velocidad_correr
		else:
			# Si intenta correr pero está agotado o quieto, camina
			velocidad_objetivo = velocidad_caminar

	# Aplicamos movimiento
	if dir != Vector2.ZERO:
		velocity = dir * velocidad_objetivo
		ultima_direccion = dir
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func gestionar_estamina(delta):
	# Detectamos si realmente está gastando energía
	var moviendose = velocity.length() > velocidad_caminar + 10 # Margen pequeño
	var gastando = moviendose and not esta_agotado and Input.is_action_pressed("correr")
	
	if gastando:
		# --- GASTAR ---
		estamina_actual -= tasa_drenaje * delta
		
		# Si se vacía el tanque...
		if estamina_actual <= 0:
			estamina_actual = 0
			esta_agotado = true # Activamos el castigo
			mostrar_pensamiento("¡Me asfixio... necesito aire!")
			sprite_animado.modulate = Color(0.7, 0.7, 1.0) 
	else:
		# --- RECUPERAR ---
		var multiplicador = 1.0
		if esta_sentado:
			multiplicador = 2.0 # Doble velocidad si descansa sentado
		
		estamina_actual += (tasa_recarga * multiplicador) * delta
		
		# Limite máximo
		if estamina_actual > max_estamina:
			estamina_actual = max_estamina
		
		# Salir del estado de agotamiento puse 40%
		if esta_agotado:
			var umbral_recuperacion = max_estamina * 0.40
			if estamina_actual >= umbral_recuperacion:
				esta_agotado = false
				mostrar_pensamiento("Ya recuperé el aliento.")
				sprite_animado.modulate = Color.WHITE 

# --- LÓGICA VISUAL ---

func actualizar_animacion(dir: Vector2):
	var accion = _determinar_accion()
	var sufijo = _determinar_direccion_y_flip(dir)
	var nombre_final = accion + sufijo
	
	if sprite_animado.animation != nombre_final:
		sprite_animado.play(nombre_final)

func _determinar_accion() -> String:
	if velocity == Vector2.ZERO:
		return "idle"
	# Detectamos si corre mirando la velocidad real, no el input
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

func mostrar_pensamiento(texto: String):
	if label_pensamiento.visible:
		var tweens_viejos = get_tree().get_processed_tweens()
		# Simplificado: Simplemente sobrescribimos el texto por si el anterior auna no termino
	
	label_pensamiento.text = texto
	label_pensamiento.visible = true
	label_pensamiento.modulate.a = 1.0 
	
	var tween = create_tween()
	tween.tween_interval(2.0) 
	tween.tween_property(label_pensamiento, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): label_pensamiento.visible = false)

func manejar_acciones():
	if Input.is_action_just_pressed("interactuar"):
		_buscar_interaccion()
	
	if Input.is_action_just_pressed("sentarse"):
		_entrar_estado_sentado()

func _buscar_interaccion():
	var areas = area_interaccion.get_overlapping_areas()
	for area in areas:
		if area.has_method("interactuar"):
			area.interactuar(self) 
			return
	
	var cuerpos = area_interaccion.get_overlapping_bodies()
	for cuerpo in cuerpos:
		if cuerpo.has_method("interactuar"):
			cuerpo.interactuar(self) 
			return

# --- ESTADOS ESPECIALES ---

func _entrar_estado_sentado():
	esta_sentado = true
	velocity = Vector2.ZERO
	sprite_animado.play("sit")
	# si nos sentamos la estamiona se recupera el doble de rapido

func chequear_levantarse():
	# Si toca cualquier tecla de moverse, se levanta
	if obtener_input() != Vector2.ZERO:
		esta_sentado = false

# --- SISTEMA DE DAÑO ---

func recibir_dano():
	if es_invulnerable: return
	
	vidas -= 1
	
	var frases_dolor = ["¡Ay!", "¡Maldición!", "¡Eso duele!", "¡Ahg!"]
	mostrar_pensamiento(frases_dolor.pick_random()) 

	if vidas <= 0:
		game_over()
		return

	sprite_animado.modulate = Color(1, 0, 0)
	var tween = create_tween()
	tween.tween_property(sprite_animado, "modulate", Color.WHITE, 0.5)
	
	aplicar_ralentizacion()

	es_invulnerable = true
	await get_tree().create_timer(1.5).timeout
	es_invulnerable = false

func aplicar_ralentizacion():
	esta_ralentizado = true
	await get_tree().create_timer(0.5).timeout
	esta_ralentizado = false

func game_over():
	print("GAME OVER")
