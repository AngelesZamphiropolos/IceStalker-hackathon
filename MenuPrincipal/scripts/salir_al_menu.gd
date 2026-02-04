extends Control

# --- CONFIGURACIÓN PARA EL INSPECTOR ---
@export_group("Ajustes Visuales")
@export var escala_hover: Vector2 = Vector2(1.1, 1.1)
@export var color_victoria: Color = Color(1.2, 1.2, 0.8) # Un tono dorado/brillante

@export_group("Sonidos")
@export var sonido_victoria: AudioStream # Arrastra aquí un sonido de "Tada!" o victoria
@onready var sonido_hover: AudioStreamPlayer = $AudioStreamPlayer 

func _ready():
	print("Chivato: Interfaz de Victoria lista")
	hide()
	modulate.a = 0 # Empezamos invisibles para el efecto de Fade-in
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

# --- LÓGICA DE APERTURA (Cuando el jugador gana) ---

func celebrar_victoria():
	print("Chivato: ¡Nivel completado! Abriendo menú de victoria...")
	show()
	get_tree().paused = true
	
	# Efecto de aparición suave (Fade-in)
	var tween_fade = create_tween()
	tween_fade.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# Sonido de victoria único
	if sonido_victoria:
		var audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
		audio_player.stream = sonido_victoria
		audio_player.play()
	
	# Foco en el botón principal (Siguiente Nivel o Continuar)
	if has_node("CenterContainer/VBoxContainer/BotonSiguiente"):
		$CenterContainer/VBoxContainer/BotonSiguiente.grab_focus()

# --- ANIMACIONES (Iguales a tu estilo) ---

func _on_mouse_enter(btn: Button) -> void:
	if sonido_hover:
		sonido_hover.pitch_scale = randf_range(1.0, 1.2) # Un poco más agudo para victoria
		sonido_hover.play()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", escala_hover, 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "modulate", color_victoria, 0.1)

func _on_mouse_exit(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.1)

func _on_button_down(btn: Button) -> void:
	btn.scale = Vector2(0.9, 0.9)
	btn.modulate = Color(2.0, 2.0, 1.0) # Brillo amarillento

# --- ACCIONES DE LOS BOTONES ---

func _on_boton_siguiente_pressed():
	print("Chivato: Cargando siguiente nivel...")
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	# Aquí podrías usar una variable global para saber cuál es el siguiente nivel
	# Por ahora, un ejemplo genérico:
	get_tree().change_scene_to_file("res://Arte/escenarios/Nivel2.tscn")

func _on_boton_menu_principal_pressed():
	print("Chivato: Volviendo al menú...")
	await get_tree().create_timer(0.1).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Arte/escenarios/menu.tscn")
