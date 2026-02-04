extends Control

# --- configuración ---
@export_group("Audio")
@export var musica_menu: AudioStream 
@export var volumen_musica_db: float = 0

@export_group("Ajustes de Botón")
@export var escala_hover: Vector2 = Vector2(1.1, 1.1)
@export var color_brillo: Color = Color(1.4, 1.4, 1.4)

# referencias a nodos
@onready var sonido_hover: AudioStreamPlayer = $AudioStreamPlayer
@onready var musica_fondo: AudioStreamPlayer = $MusicaFondo 
@onready var video_intro: VideoStreamPlayer = $VideoIntro

func _ready() -> void:
	# configuración inicial del video
	if video_intro:
		video_intro.visible = false
		# conexión de señal de finalización
		video_intro.finished.connect(_al_terminar_video)
	
	# inicio de música de fondo
	if musica_menu:
		musica_fondo.stream = musica_menu
		musica_fondo.volume_db = volumen_musica_db
		musica_fondo.play()
	
	# configuración recursiva de botones
	_preparar_botones(self)

func _preparar_botones(nodo: Node) -> void:
	for hijo in nodo.get_children():
		if hijo is Button:
			hijo.pivot_offset = hijo.size / 2 
			# conexión dinámica de señales con bind
			hijo.mouse_entered.connect(_on_mouse_enter.bind(hijo))
			hijo.mouse_exited.connect(_on_mouse_exit.bind(hijo))
			hijo.button_down.connect(_on_button_down.bind(hijo))
		
		# recursividad para contenedores anidados
		if hijo.get_child_count() > 0:
			_preparar_botones(hijo)

# --- animaciones ---

func _on_mouse_enter(btn: Button) -> void:
	# reproducción de sonido con variación de pitch
	if sonido_hover.stream:
		sonido_hover.pitch_scale = randf_range(0.9, 1.1)
		sonido_hover.play()
	
	# animación de escala y brillo en paralelo
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", escala_hover, 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "modulate", color_brillo, 0.1)

func _on_mouse_exit(btn: Button) -> void:
	# restauración de estado original
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.1)

func _on_button_down(btn: Button) -> void:
	# efecto visual de presión
	btn.scale = Vector2(0.95, 0.95)

# --- navegación y video ---

func _on_jugar_pressed() -> void:
	print("Iniciando secuencia de video...")
	
	# detiene música del menú
	musica_fondo.stop()
	
	# activa y reproduce video overlay
	video_intro.visible = true
	video_intro.play()
	
	# oculta cursor durante cinemática
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

# ejecutado por señal finished del video_intro
func _al_terminar_video():
	# restaura visibilidad del mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# cambio a escena principal
	get_tree().change_scene_to_file("res://Escenas/main.tscn")

# --- truco extra: saltar video ---
func _input(event):
	# permite saltar video con escape o enter
	if video_intro.visible and video_intro.is_playing():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			video_intro.stop() 


func _on_opciones_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuPrincipal/escenas/opciones.tscn")

func _on_salir_pressed() -> void:
	get_tree().quit()
