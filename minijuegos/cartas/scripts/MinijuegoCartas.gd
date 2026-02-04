extends Control

# --- configuración y recursos ---
@export_group("Recursos Visuales")
@export var dorso_carta: Texture2D 
@export var imagenes_frente: Array[Texture2D] 

@export_group("Referencias")
@onready var grid = $GridContainer
@onready var timer_juego = $Timer
@export var label_tiempo: Label

# --- estado del juego ---
var cartas_levantadas = [] 
var pares_encontrados = 0
var total_pares = 6
var bloqueo_input = false # bandera para evitar input durante animaciones
var juego_activo = true

# ajuste de resolución para cartas (640x360)
var tamano_carta = Vector2(110, 85) 

func _ready():
	# pausa del árbol principal durante el puzzle
	get_tree().paused = true
	
	if imagenes_frente.size() != 6:
		printerr("ERROR CRÍTICO: Se requieren exactamente 6 imágenes para generar los pares.")
		return
		
	timer_juego.timeout.connect(_on_tiempo_agotado)
	generar_tablero()

func _process(delta):
	# actualización de interfaz de tiempo si el juego es válido
	if juego_activo and timer_juego.time_left > 0 and label_tiempo:
		label_tiempo.text = "Tiempo: %d" % ceil(timer_juego.time_left)

# --- sistema de generación ---

func generar_tablero():
	# duplicación de imágenes para crear pares y mezcla aleatoria
	var mazo = []
	for img in imagenes_frente:
		mazo.append(img)
		mazo.append(img)
	mazo.shuffle()
	
	for textura_secreto in mazo:
		var carta = TextureButton.new()
		
		# configuración de propiedades del botón
		carta.texture_normal = dorso_carta 
		carta.ignore_texture_size = true   
		carta.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		carta.custom_minimum_size = tamano_carta 
		
		# ajuste de pivote al centro para rotación correcta
		carta.pivot_offset = tamano_carta / 2 
		
		# almacenamiento de datos lógicos en metadatos
		carta.set_meta("imagen_frente", textura_secreto)
		carta.set_meta("es_par", false)
		
		carta.pressed.connect(_al_tocar_carta.bind(carta))
		grid.add_child(carta)

# --- core gameplay ---

func _al_tocar_carta(carta_tocada):
	# validación de estado: ignora input si hay bloqueo o carta resuelta
	if not juego_activo or bloqueo_input: return
	if carta_tocada.get_meta("es_par") or carta_tocada in cartas_levantadas: return

	# registro en memoria temporal
	cartas_levantadas.append(carta_tocada)

	# ejecución de animación de revelado
	animar_voltear(carta_tocada, carta_tocada.get_meta("imagen_frente"))
	
	# validación de par al tener dos cartas seleccionadas
	if cartas_levantadas.size() == 2:
		bloqueo_input = true
		verificar_par()

func verificar_par():
	var c1 = cartas_levantadas[0]
	var c2 = cartas_levantadas[1]
	
	# espera breve para visualización
	await get_tree().create_timer(0.2).timeout
	
	if c1.get_meta("imagen_frente") == c2.get_meta("imagen_frente"):
		_procesar_acierto(c1, c2)
	else:
		_procesar_fallo(c1, c2)

func _procesar_acierto(c1, c2):
	pares_encontrados += 1
	
	# actualización de estado y desactivación de interacción
	c1.set_meta("es_par", true)
	c2.set_meta("es_par", true)
	c1.disabled = true
	c2.disabled = true
	
	# feedback visual de éxito
	c1.modulate = Color(0.6, 1, 0.6)
	c2.modulate = Color(0.6, 1, 0.6)
	
	cartas_levantadas.clear()
	bloqueo_input = false
	
	if pares_encontrados == total_pares:
		await get_tree().create_timer(0.5).timeout
		ganar_juego()

func _procesar_fallo(c1, c2):
	# tiempo de espera para memorización
	await get_tree().create_timer(1.0).timeout
	
	# reversión de animación al dorso
	animar_voltear(c1, dorso_carta)
	animar_voltear(c2, dorso_carta)
	
	cartas_levantadas.clear()
	bloqueo_input = false

# --- animaciones ---

func animar_voltear(carta: TextureButton, textura_final: Texture2D):
	# simulación de rotación 3d mediante escala
	var tween = create_tween()
	tween.tween_property(carta, "scale:x", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): carta.texture_normal = textura_final)
	tween.tween_property(carta, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_SINE)

# --- flujo de control y salida ---

func _on_tiempo_agotado():
	# reinicio del tablero por timeout
	reiniciar_tablero()

func reiniciar_tablero():
	for hijo in grid.get_children():
		hijo.queue_free()
	
	cartas_levantadas.clear()
	pares_encontrados = 0
	bloqueo_input = false
	timer_juego.start()
	
	# espera de frame para asegurar limpieza de nodos
	await get_tree().process_frame
	generar_tablero()

func ganar_juego():
	juego_activo = false
	if label_tiempo: label_tiempo.text = "¡GANASTE!"
	timer_juego.stop()
	
	await get_tree().create_timer(1.5).timeout
	cerrar_minijuego(true)

func cerrar_minijuego(victoria: bool):
	# emisión de resultado global
	Global.minijuego_terminado.emit(victoria)
	
	# reactivación del árbol principal y liberación de memoria
	get_tree().paused = false
	queue_free()
