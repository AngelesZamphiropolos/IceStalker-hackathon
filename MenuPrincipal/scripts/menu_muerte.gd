extends Control

# --- CONFIGURACIÓN VISUAL ---
@export_group("Estética de Botones")
@export var escala_hover: Vector2 = Vector2(1.1, 1.1)
@export var color_brillo: Color = Color(1.2, 1.2, 1.2) # Un brillo sutil pero notable

# --- REFERENCIAS ---
# Asegúrate de que este nodo exista y tenga un sonido cargado
@onready var sonido_hover: AudioStreamPlayer = $AudioStreamPlayer 

# --- INICIALIZACIÓN ---

func _ready():
	# 2. Configuramos todos los botones de la escena automáticamente
	_configurar_botones_recursivo(self)
	if has_node("CanvasLayer/ColorRect/VBoxContainer/reintentar"):
		$CanvasLayer/ColorRect/VBoxContainer/reintentar.grab_focus()

# --- SISTEMA DE CONFIGURACIÓN AUTOMÁTICA ---

# Esta función recorre todos los hijos buscando botones para darles vida
func _configurar_botones_recursivo(nodo: Node) -> void:
	for hijo in nodo.get_children():
		if hijo is Button:
			# Truco: Ajustamos el pivote al centro para que la animación de escala se vea bien
			# Usamos call_deferred para asegurarnos de que el botón ya tenga tamaño calculado
			hijo.call_deferred("set_pivot_offset", hijo.size / 2)
			
			# Conectamos las señales de animación (Feedback visual)
			hijo.mouse_entered.connect(_animar_entrada.bind(hijo))
			hijo.mouse_exited.connect(_animar_salida.bind(hijo))
			hijo.button_down.connect(_animar_presion.bind(hijo))
		
		# Si el hijo tiene hijos, seguimos buscando (recursividad)
		if hijo.get_child_count() > 0:
			_configurar_botones_recursivo(hijo)

# --- ANIMACIONES (JUICE) ---

func _animar_entrada(btn: Button) -> void:
	# Sonido
	if sonido_hover:
		sonido_hover.pitch_scale = randf_range(0.95, 1.05) # Variación leve para que no suene robótico
		sonido_hover.play()
	
	# Animación (Tween)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", escala_hover, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "modulate", color_brillo, 0.1)

func _animar_salida(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.1)

func _animar_presion(btn: Button) -> void:
	# Efecto de "click" físico (se achica un poco y brilla mucho)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
	tween.tween_property(btn, "modulate", Color(1.5, 1.5, 1.5), 0.05)

# --- LÓGICA DE JUEGO (SEÑALES) ---

func _on_reintentar_pressed():
	# IMPORTANTE: Quitar la pausa antes de reiniciar o el juego cargará congelado
	get_tree().paused = false 
	
	# Pequeña espera 
	await get_tree().create_timer(0.1).timeout 
	
	# Asegúrate de poner aquí la ruta de TU NIVEL DE JUEGO, no la del menú
	get_tree().change_scene_to_file("res://Escenas/main.tscn") 


func _on_salir_al_menu_pressed():
	print(">> Volviendo al menú principal...")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MenuPrincipal/escenas/menu.tscn")
