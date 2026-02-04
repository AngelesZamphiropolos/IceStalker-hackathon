extends Control

# --- CONFIGURACIÓN ---
@export_group("Audio")
@export var musica_menu: AudioStream 
@export var volumen_musica_db: float = 0

@export_group("Ajustes de Botón")
@export var escala_hover: Vector2 = Vector2(1.1, 1.1)
@export var color_brillo: Color = Color(1.4, 1.4, 1.4)

# Referencias
@onready var sonido_hover: AudioStreamPlayer = $AudioStreamPlayer
@onready var musica_fondo: AudioStreamPlayer = $MusicaFondo 
@onready var video_intro: VideoStreamPlayer = $VideoIntro

func _ready() -> void:
	# Asegur que el video esté oculto al iniciar
	if video_intro:
		video_intro.visible = false
		# Conectar la señal de "terminó el video"
		video_intro.finished.connect(_al_terminar_video)
	
	# 1. INICIAR MÚSICA
	if musica_menu:
		musica_fondo.stream = musica_menu
		musica_fondo.volume_db = volumen_musica_db
		musica_fondo.play()
	
	# 2. Configurar botones
	_preparar_botones(self)

func _preparar_botones(nodo: Node) -> void:
	for hijo in nodo.get_children():
		if hijo is Button:
			hijo.pivot_offset = hijo.size / 2 
			hijo.mouse_entered.connect(_on_mouse_enter.bind(hijo))
			hijo.mouse_exited.connect(_on_mouse_exit.bind(hijo))
			hijo.button_down.connect(_on_button_down.bind(hijo))
		
		if hijo.get_child_count() > 0:
			_preparar_botones(hijo)

# --- ANIMACIONES ---

func _on_mouse_enter(btn: Button) -> void:
	if sonido_hover.stream:
		sonido_hover.pitch_scale = randf_range(0.9, 1.1)
		sonido_hover.play()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", escala_hover, 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "modulate", color_brillo, 0.1)

func _on_mouse_exit(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.1)

func _on_button_down(btn: Button) -> void:
	btn.scale = Vector2(0.95, 0.95)

# --- NAVEGACIÓN Y VIDEO ---

func _on_jugar_pressed() -> void:
	print("Iniciando secuencia de video...")
	
	# 1. Apagamos la música del menú para escuchar el video
	musica_fondo.stop()
	
	# 2. Mostramos el reproductor de video (que tapa todo)
	video_intro.visible = true
	
	# 3. Le damos Play
	video_intro.play()
	
	# Ocultar el cursor mientras se ve el video
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

# Esta función se llama sola cuando el video termina (gracias al connect en _ready)
func _al_terminar_video():
	# Restauramos el mouse por si acaso
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Cambiamos de escena
	get_tree().change_scene_to_file("res://Escenas/main.tscn")

# --- TRUCO EXTRA: SALTAR VIDEO ---
func _input(event):
	if video_intro.visible and video_intro.is_playing():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			video_intro.stop() 


func _on_opciones_pressed() -> void:
	get_tree().change_scene_to_file("res://MenuPrincipal/escenas/opciones.tscn")

func _on_salir_pressed() -> void:
	get_tree().quit()
