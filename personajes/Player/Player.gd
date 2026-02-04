extends CharacterBody2D

# --- configuración ---
# variables expuestas para ajustar en el editor
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
@export var tasa_drenaje: float = 25.0 
@export var tasa_recarga: float = 15.0 

@export_group("Audio FX")
@export var sfx_pasos: Array[AudioStream] # lista de sonidos para pasos aleatorios
@export var sfx_dano: AudioStream      
@export var frames_pasos: Array[int] = [2, 3] # frames de animación donde suena el paso

@export_group("Opciones")
@export var usar_suavizado_camara: bool = true

# --- referencias ---
# obtención de nodos hijos al iniciar
@onready var sprite_animado: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_interaccion: Area2D = $AreaInteraccion
@onready var camara: Camera2D = $Camera2D
@onready var luz: PointLight2D = $PointLight2D
@onready var label_pensamiento = $LabelPensamiento
@onready var audio_player: AudioStreamPlayer = $AudioPlayer 

# --- estado interno ---
var ultima_direccion: Vector2 = Vector2.DOWN
var esta_sentado: bool = false
var input_bloqueado: bool = false
var fuerza_temblor: float = 0.0
var esta_ralentizado: bool = false 
var tween_pensamiento: Tween

var estamina_actual: float = 0.0
var esta_agotado: bool = false 

func _ready():
	# inicialización de estamina
	estamina_actual = max_estamina
	
	# configuración inicial de cámara y luz si existen
	if camara:
		camara.position_smoothing_enabled = usar_suavizado_camara
	if luz:
		luz.texture_scale = rango_luz
		luz.energy = energia_luz
	
	# conexión de señal para sincronizar pasos
	sprite_animado.frame_changed.connect(_on_frame_changed)
	
	# --- introducción narrativa ---
	# bloquea input para secuencia inicial
	input_bloqueado = true 
	
	# espera inicial
	await get_tree().create_timer(1.0).timeout
	
	# secuencia de textos con esperas
	mostrar_pensamiento("Ugh... mi cabeza... \n ¿Qué hora es?")
	await get_tree().create_timer(4.0).timeout 
	
	mostrar_pensamiento("Me quedé dormido estudiando \npara el final... ¡Maldición!")
	await get_tree().create_timer(4.0).timeout
	
	mostrar_pensamiento("Todo está cerrado y oscuro. \nLas escaleras de emergencia estaban \n bloqueadas...")
	await get_tree().create_timer(4.5).timeout
	
	mostrar_pensamiento("Tengo que bajar por el ascensor. \nEspero que aún haya energía.")
	await get_tree().create_timer(4.0).timeout
	
	# libera input para comenzar juego
	input_bloqueado = false

func _process(delta):
	# control de menú de pausa o salida
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_ESCAPE):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://MenuPrincipal/escenas/menu.tscn")
	
	# lógica de temblor de cámara (screen shake)
	if camara and fuerza_temblor > 0:
		camara.offset = Vector2(
			randf_range(-fuerza_temblor, fuerza_temblor),
			randf_range(-fuerza_temblor, fuerza_temblor)
		)
		fuerza_temblor = lerp(fuerza_temblor, 0.0, 8.0 * delta)
		if fuerza_temblor < 0.1:
			fuerza_temblor = 0
			camara.offset = Vector2.ZERO
			
	# efecto de parpadeo de luz
	if luz and randf() < 0.05: 
		luz.energy = randf_range(energia_luz * 0.8, energia_luz * 1.2)

func _physics_process(delta):
	# interpolación de posición de cámara
	if camara and camara.offset.length() > 0:
		camara.offset = lerp(camara.offset, Vector2.ZERO, 0.1)

	# actualización de recursos
	gestionar_estamina(delta)

	# verificación de estado sentado
	if esta_sentado:
		chequear_levantarse()
		return
	
	# verificación de bloqueo de input
	if input_bloqueado:
		return

	# flujo principal de movimiento y acción
	var direccion = obtener_input()
	aplicar_movimiento(direccion) 
	actualizar_animacion(direccion)
	manejar_acciones()

# --- lógica de movimiento ---

func obtener_input() -> Vector2:
	# obtiene vector normalizado de inputs
	return Input.get_vector("mover_izquierda", "mover_derecha", "mover_arriba", "mover_abajo")

func aplicar_movimiento(dir: Vector2):
	var velocidad_objetivo = velocidad_caminar
	var esta_intentando_correr = Input.is_action_pressed("correr")
	
	# determina velocidad según estado
	if esta_ralentizado:
		velocidad_objetivo = velocidad_herido 
	elif esta_intentando_correr:
		if dir != Vector2.ZERO and not esta_agotado and estamina_actual > 0:
			velocidad_objetivo = velocidad_correr
		else:
			velocidad_objetivo = velocidad_caminar

	# aplica velocidad y dirección
	if dir != Vector2.ZERO:
		velocity = dir * velocidad_objetivo
		ultima_direccion = dir
	else:
		velocity = Vector2.ZERO

	# mueve el cuerpo respetando colisiones
	move_and_slide()

func gestionar_estamina(delta):
	var moviendose = velocity.length() > velocidad_caminar + 10 
	var gastando = moviendose and not esta_agotado and Input.is_action_pressed("correr")
	
	# lógica de drenaje
	if gastando:
		estamina_actual -= tasa_drenaje * delta
		if estamina_actual <= 0:
			estamina_actual = 0
			esta_agotado = true 
			mostrar_pensamiento("¡Me asfixio... necesito aire!")
			sprite_animado.modulate = Color(0.7, 0.7, 1.0) 
	else:
		# lógica de regeneración
		var multiplicador = 1.0
		if esta_sentado:
			multiplicador = 2.0 
		
		estamina_actual += (tasa_recarga * multiplicador) * delta
		
		if estamina_actual > max_estamina:
			estamina_actual = max_estamina
		
		# recuperación del estado agotado
		if esta_agotado:
			var umbral_recuperacion = max_estamina * 0.40
			if estamina_actual >= umbral_recuperacion:
				esta_agotado = false
				mostrar_pensamiento("Ya recuperé el aliento.")
				sprite_animado.modulate = Color.WHITE 

# --- lógica visual y audio de pasos ---

func actualizar_animacion(dir: Vector2):
	var accion = _determinar_accion()
	var sufijo = _determinar_direccion_y_flip(dir)
	var nombre_final = accion + sufijo
	
	# cambia animación solo si es distinta a la actual
	if sprite_animado.animation != nombre_final:
		sprite_animado.play(nombre_final)

# se ejecuta por señal frame_changed
func _on_frame_changed():
	if velocity.length() == 0 or esta_sentado: return
	
	var anim = sprite_animado.animation
	if "walk" in anim or "run" in anim:
		# reproduce sonido si el frame coincide con la lista configurada
		if sprite_animado.frame in frames_pasos:
			_reproducir_sonido_paso()

func _reproducir_sonido_paso():
	if sfx_pasos.is_empty(): return
	# selecciona sonido aleatorio
	audio_player.stream = sfx_pasos.pick_random()
	
	var esta_corriendo = velocity.length() > velocidad_caminar + 10
	
	# ajusta pitch y volumen según velocidad
	if esta_corriendo:
		audio_player.volume_db = -2 
		audio_player.pitch_scale = randf_range(1.1, 1.3) 
	else:
		audio_player.volume_db = -8 
		audio_player.pitch_scale = randf_range(0.9, 1.05) 
	
	audio_player.play()

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

# --- sistema de interacción ---

func mostrar_pensamiento(texto: String):
	# limpia tween anterior si existe
	if tween_pensamiento and tween_pensamiento.is_valid():
		tween_pensamiento.kill()
	
	# configuración inicial del label
	label_pensamiento.text = texto
	label_pensamiento.visible = true
	label_pensamiento.modulate.a = 1.0
	label_pensamiento.visible_ratio = 0.0
	
	# creación de secuencia de animación
	tween_pensamiento = create_tween()
	
	# efecto de escritura
	tween_pensamiento.tween_property(label_pensamiento, "visible_ratio", 1.0, 0.7)
	
	# espera de lectura calculada
	var tiempo_lectura = 1.5 + (texto.length() * 0.1)
	tween_pensamiento.tween_interval(tiempo_lectura)
	
	# desvanecimiento (fade out)
	tween_pensamiento.tween_property(label_pensamiento, "modulate:a", 0.0, 1.0)
	
	# ocultar label al finalizar
	tween_pensamiento.tween_callback(func(): label_pensamiento.visible = false)
	

func manejar_acciones():
	# detección de inputs de acción
	if Input.is_action_just_pressed("interactuar"):
		_buscar_interaccion()
	
	if Input.is_action_just_pressed("sentarse"):
		_entrar_estado_sentado()

func _buscar_interaccion():
	# busca áreas interactivas cercanas
	var areas = area_interaccion.get_overlapping_areas()
	for area in areas:
		if area.has_method("interactuar"):
			area.interactuar(self) 
			return
	
	# busca cuerpos interactivos cercanos
	var cuerpos = area_interaccion.get_overlapping_bodies()
	for cuerpo in cuerpos:
		if cuerpo.has_method("interactuar"):
			cuerpo.interactuar(self) 
			return

# --- estados especiales ---

func _entrar_estado_sentado():
	esta_sentado = true
	velocity = Vector2.ZERO
	sprite_animado.play("sit")

func chequear_levantarse():
	# rompe estado sentado si hay input de movimiento
	if obtener_input() != Vector2.ZERO:
		esta_sentado = false

# --- sistema de daño ---

func recibir_dano():
	if es_invulnerable: return
	
	vidas -= 1
	
	# reproducción de audio de daño
	if sfx_dano:
		audio_player.stream = sfx_dano
		audio_player.pitch_scale = 1.0 
		audio_player.volume_db = 0
		audio_player.play()
	
	var frases_dolor = ["¡Ay!", "¡Maldición!", "¡Eso duele!", "¡Ahg!"]
	mostrar_pensamiento(frases_dolor.pick_random()) 

	# verificación de muerte
	if vidas <= 0:
		game_over()
		return

	# feedback visual (parpadeo rojo)
	sprite_animado.modulate = Color(1, 0, 0)
	var tween = create_tween()
	tween.tween_property(sprite_animado, "modulate", Color.WHITE, 0.5)
	
	aplicar_ralentizacion()

	# periodo de invulnerabilidad
	es_invulnerable = true
	await get_tree().create_timer(1.5).timeout
	es_invulnerable = false

func aplicar_ralentizacion():
	# penalización temporal de velocidad
	esta_ralentizado = true
	await get_tree().create_timer(0.5).timeout
	esta_ralentizado = false

func game_over():
	print("GAME OVER")
	
	sprite_animado.modulate = Color(0.5, 0, 0)
	mostrar_pensamiento("Todo se vuelve oscuro...")
	
	input_bloqueado = true
	velocity = Vector2.ZERO 
	
	await get_tree().create_timer(2.0).timeout
	
	# reinicio de variables globales y cambio de escena
	if Global.has_method("reiniciar_todo"):
		Global.reiniciar_todo()
	
	get_tree().change_scene_to_file("res://MenuPrincipal/escenas/menu_muerte.tscn")
