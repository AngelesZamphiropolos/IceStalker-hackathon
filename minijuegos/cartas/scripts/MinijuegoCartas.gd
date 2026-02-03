extends Control

# --- CONFIGURACIÓN ---
@export_group("Recursos Visuales")
@export var dorso_carta: Texture2D 
@export var imagenes_frente: Array[Texture2D] 

@export_group("Referencias")
@onready var grid = $GridContainer
@export var label_tiempo: Label
@onready var timer_juego = $Timer

# Variables de Estado
var cartas_levantadas = [] 
var pares_encontrados = 0
var total_pares = 6
var bloqueo_input = false 
var juego_activo = true

# Tamaño de carta ajustado para resolución 640x360
# Tus imagenes son 315x250 (Ratio 1.26). 
# 110x85 mantiene el ratio y caben 4 a lo ancho (440px) en tu pantalla de 640px.
var tamano_carta = Vector2(110, 85) 

func _ready():
	get_tree().paused = true
	
	if imagenes_frente.size() != 6:
		printerr("ERROR: Necesitas cargar exactamente 6 imágenes.")
		return
		
	timer_juego.timeout.connect(_on_tiempo_agotado)
	generar_tablero()

func _process(delta):
	# ### CAMBIO 2: Actualización segura del texto
	if juego_activo and timer_juego.time_left > 0 and label_tiempo:
		label_tiempo.text = "Tiempo: %d" % ceil(timer_juego.time_left)

# --- GENERACIÓN VISUAL ---

func generar_tablero():
	var mazo = []
	for img in imagenes_frente:
		mazo.append(img)
		mazo.append(img)
	mazo.shuffle()
	
	for textura_secreto in mazo:
		var carta = TextureButton.new()
		
		# Configuración Visual
		carta.texture_normal = dorso_carta 
		carta.ignore_texture_size = true   
		carta.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		# ### CAMBIO 1: Tamaño ajustado para 640x360
		carta.custom_minimum_size = tamano_carta 
		
		# ### CAMBIO 3 (Importante para animación): 
		# El pivote debe estar en el centro para que gire sobre su eje
		carta.pivot_offset = tamano_carta / 2 
		
		# Metadatos
		carta.set_meta("imagen_frente", textura_secreto)
		carta.set_meta("es_par", false)
		
		carta.pressed.connect(_al_tocar_carta.bind(carta))
		grid.add_child(carta)

# --- LÓGICA Y ANIMACIÓN ---

func _al_tocar_carta(carta_tocada):
	if not juego_activo or bloqueo_input: return
	if carta_tocada.get_meta("es_par") or carta_tocada in cartas_levantadas: return

	# Añadir a la lista
	cartas_levantadas.append(carta_tocada)

	# ### CAMBIO 3: Animación de Voltear (Muestra el Frente)
	animar_voltear(carta_tocada, carta_tocada.get_meta("imagen_frente"))
	
	if cartas_levantadas.size() == 2:
		bloqueo_input = true
		verificar_par()

func verificar_par():
	var c1 = cartas_levantadas[0]
	var c2 = cartas_levantadas[1]
	
	# Esperamos un poco (0.3s) a que termine la animación de voltear la segunda carta
	await get_tree().create_timer(0.3).timeout
	
	if c1.get_meta("imagen_frente") == c2.get_meta("imagen_frente"):
		# --- ¡PAR CORRECTO! ---
		pares_encontrados += 1
		c1.set_meta("es_par", true)
		c2.set_meta("es_par", true)
		c1.disabled = true
		c2.disabled = true
		c1.modulate = Color(0.6, 1, 0.6)
		c2.modulate = Color(0.6, 1, 0.6)
		
		cartas_levantadas.clear()
		bloqueo_input = false
		
		if pares_encontrados == total_pares:
			await get_tree().create_timer(0.5).timeout
			ganar_juego()
	else:
		# --- ERROR ---
		# Esperar 1 segundo para ver el error
		await get_tree().create_timer(1.0).timeout
		
		# ### CAMBIO 3: Animación de Voltear (Volver al Dorso)
		animar_voltear(c1, dorso_carta)
		animar_voltear(c2, dorso_carta)
		
		cartas_levantadas.clear()
		bloqueo_input = false

# ### CAMBIO 3: Función genérica de animación (Tween)
func animar_voltear(carta: TextureButton, textura_final: Texture2D):
	var tween = create_tween()
	# 1. Escalar X a 0 (Se hace fina hasta desaparecer)
	tween.tween_property(carta, "scale:x", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	# 2. Cambiar la textura cuando es invisible
	tween.tween_callback(func(): carta.texture_normal = textura_final)
	# 3. Escalar X a 1 (Vuelve a aparecer con la nueva imagen)
	tween.tween_property(carta, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_SINE)

# --- RESTO DEL CÓDIGO (Igual que antes) ---

func _on_tiempo_agotado():
	reiniciar_tablero()

func reiniciar_tablero():
	for hijo in grid.get_children():
		hijo.queue_free()
	
	cartas_levantadas.clear()
	pares_encontrados = 0
	bloqueo_input = false
	timer_juego.start()
	await get_tree().process_frame
	generar_tablero()

func ganar_juego():
	juego_activo = false
	label_tiempo.text = "¡GANASTE!"
	timer_juego.stop()
	await get_tree().create_timer(1.5).timeout
	cerrar_minijuego(true)

func cerrar_minijuego(victoria: bool):
	if victoria:
		# Global.minijuego_ganado.emit()
		pass
	else:
		# Global.minijuego_perdido.emit()
		pass
	get_tree().paused = false
	queue_free()
