extends Control

# --- CONFIGURACIÓN Y RECURSOS ---
@export_group("Recursos Visuales")
@export var dorso_carta: Texture2D 
@export var imagenes_frente: Array[Texture2D] 

@export_group("Referencias")
@onready var grid = $GridContainer
@onready var timer_juego = $Timer
@export var label_tiempo: Label

# --- ESTADO DEL JUEGO ---
var cartas_levantadas = [] 
var pares_encontrados = 0
var total_pares = 6
var bloqueo_input = false # Evita clicks locos mientras animamos
var juego_activo = true

# Ajuste de resolución (640x360):
var tamano_carta = Vector2(110, 85) 

func _ready():
	# Pausamos el juego principal para que no nos maten mientras resolvemos el puzzle
	get_tree().paused = true
	
	if imagenes_frente.size() != 6:
		printerr("ERROR CRÍTICO: Se requieren exactamente 6 imágenes para generar los pares.")
		return
		
	timer_juego.timeout.connect(_on_tiempo_agotado)
	generar_tablero()

func _process(delta):
	# Actualizamos el UI solo si el juego corre y tenemos la referencia del label válida
	if juego_activo and timer_juego.time_left > 0 and label_tiempo:
		label_tiempo.text = "Tiempo: %d" % ceil(timer_juego.time_left)

# --- SISTEMA DE GENERACIÓN ---

func generar_tablero():
	# Duplicamos las imágenes para tener los pares y barajamos
	var mazo = []
	for img in imagenes_frente:
		mazo.append(img)
		mazo.append(img)
	mazo.shuffle()
	
	for textura_secreto in mazo:
		var carta = TextureButton.new()
		
		# Configuración del botón para que se comporte como carta
		carta.texture_normal = dorso_carta 
		carta.ignore_texture_size = true   
		carta.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		carta.custom_minimum_size = tamano_carta 
		
		# El pivote al centro es obligatorio para que la animación de rotación no se descuadre
		carta.pivot_offset = tamano_carta / 2 
		
		# Guardamos la info real en metadatos para no exponerla visualmente
		carta.set_meta("imagen_frente", textura_secreto)
		carta.set_meta("es_par", false)
		
		carta.pressed.connect(_al_tocar_carta.bind(carta))
		grid.add_child(carta)

# --- CORE GAMEPLAY ---

func _al_tocar_carta(carta_tocada):
	# Filtros de seguridad: si está bloqueado, pausado o la carta ya está lista, ignoramos
	if not juego_activo or bloqueo_input: return
	if carta_tocada.get_meta("es_par") or carta_tocada in cartas_levantadas: return

	# Añadimos a la memoria temporal
	cartas_levantadas.append(carta_tocada)

	# Animación de entrada (Revelar)
	animar_voltear(carta_tocada, carta_tocada.get_meta("imagen_frente"))
	
	# Si tenemos dos cartas en memoria, bloqueamos input y validamos
	if cartas_levantadas.size() == 2:
		bloqueo_input = true
		verificar_par()

func verificar_par():
	var c1 = cartas_levantadas[0]
	var c2 = cartas_levantadas[1]
	
	# Pequeño delay para que el jugador alcance a ver la segunda carta antes de validar
	await get_tree().create_timer(0.2).timeout
	
	if c1.get_meta("imagen_frente") == c2.get_meta("imagen_frente"):
		_procesar_acierto(c1, c2)
	else:
		_procesar_fallo(c1, c2)

func _procesar_acierto(c1, c2):
	pares_encontrados += 1
	
	# Marcamos como resueltas y deshabilitamos interacción
	c1.set_meta("es_par", true)
	c2.set_meta("es_par", true)
	c1.disabled = true
	c2.disabled = true
	
	# Feedback visual (verde sutil)
	c1.modulate = Color(0.6, 1, 0.6)
	c2.modulate = Color(0.6, 1, 0.6)
	
	cartas_levantadas.clear()
	bloqueo_input = false
	
	if pares_encontrados == total_pares:
		await get_tree().create_timer(0.5).timeout
		ganar_juego()

func _procesar_fallo(c1, c2):
	# Damos 1 segundo para memorizar el error
	await get_tree().create_timer(1.0).timeout
	
	# Ocultamos de nuevo
	animar_voltear(c1, dorso_carta)
	animar_voltear(c2, dorso_carta)
	
	cartas_levantadas.clear()
	bloqueo_input = false

# --- ANIMACIONES ---

func animar_voltear(carta: TextureButton, textura_final: Texture2D):
	# Simulamos un giro 3D :D
	var tween = create_tween()
	tween.tween_property(carta, "scale:x", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): carta.texture_normal = textura_final)
	tween.tween_property(carta, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_SINE)

# --- FLUJO DE CONTROL Y SALIDA ---

func _on_tiempo_agotado():
	# Si se acaba el tiempo, reiniciamos el puzzle
	reiniciar_tablero()

func reiniciar_tablero():
	for hijo in grid.get_children():
		hijo.queue_free()
	
	cartas_levantadas.clear()
	pares_encontrados = 0
	bloqueo_input = false
	timer_juego.start()
	
	# Esperamos un frame para asegurar que la limpieza de nodos terminó
	await get_tree().process_frame
	generar_tablero()

func ganar_juego():
	juego_activo = false
	if label_tiempo: label_tiempo.text = "¡GANASTE!"
	timer_juego.stop()
	
	await get_tree().create_timer(1.5).timeout
	cerrar_minijuego(true)

func cerrar_minijuego(victoria: bool):
	# Notificamos al Global el resultado
	Global.minijuego_terminado.emit(victoria)
	
	# Importante: Devolver el control al juego principal antes de morir
	# El que lea esto me debe 10.000 gs
	get_tree().paused = false
	queue_free()
