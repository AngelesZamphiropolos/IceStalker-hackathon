extends Control

# Configuración que puedes tocar desde el Inspector
@export_group("Ajustes de Botón")
@export var escala_hover: Vector2 = Vector2(1.1, 1.1)
@export var color_brillo: Color = Color(1.4, 1.4, 1.4) # Esto aclara el botón

@onready var sonido_hover: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	# Configura automáticamente todos los botones hijos
	_preparar_botones(self)

func _preparar_botones(nodo: Node) -> void:
	for hijo in nodo.get_children():
		if hijo is Button:
			hijo.pivot_offset = hijo.size / 2 # Centrar pivote
			# Conectamos las señales por código
			hijo.mouse_entered.connect(_on_mouse_enter.bind(hijo))
			hijo.mouse_exited.connect(_on_mouse_exit.bind(hijo))
			hijo.button_down.connect(_on_button_down.bind(hijo))
		
		if hijo.get_child_count() > 0:
			_preparar_botones(hijo)

# --- ANIMACIONES ---

func _on_mouse_enter(btn: Button) -> void:
	# Sonido con variación de tono
	sonido_hover.pitch_scale = randf_range(0.9, 1.1)
	sonido_hover.play()
	
	var tween = create_tween().set_parallel(true)
	# Crece y brilla al mismo tiempo
	tween.tween_property(btn, "scale", escala_hover, 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "modulate", color_brillo, 0.1)

func _on_mouse_exit(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	# Vuelve a la normalidad
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.1)

func _on_button_down(btn: Button) -> void:
	# Efecto pequeño de "apretar"
	btn.scale = Vector2(0.95, 0.95)

# --- NAVEGACIÓN (Tus funciones) ---

func _on_jugar_pressed() -> void:
	get_tree().change_scene_to_file("res://Arte/escenarios/juego.tscn")

func _on_opciones_pressed() -> void:
	get_tree().change_scene_to_file("res://Arte/escenarios/opciones.tscn")

func _on_salir_pressed() -> void:
	get_tree().quit()
