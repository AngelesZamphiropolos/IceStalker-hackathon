extends Control

# --- CONFIGURACIÓN VISUAL ---
@export_group("Musica")
@export var musica_menu: AudioStream
@export var volumen_musica_db: float = 0

@export_group("Estética de Botones")
@export var escala_hover: Vector2 = Vector2(1.1, 1.1)
@export var color_brillo: Color = Color(1.2, 1.2, 1.2)

@onready var musica_fondo: AudioStreamPlayer = $AudioStreamPlayer
func _ready() -> void:
	if musica_menu:
		musica_fondo.stream = musica_menu
		musica_fondo.volume_db = volumen_musica_db
		musica_fondo.play()
# --- REFERENCIAS ---
# Si tienes un nodo de sonido, ponlo; si no, el script lo ignora sin error.
@onready var sonido_hover: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer")

# --- LAS ACCIONES DE LOS BOTONES ---

func _on_salir_del_juego_pressed() -> void:
	print(">> Cerrando juego. ¡Hasta la próxima!")
	get_tree().quit()


func _on_salir_al_menu_pressed() -> void:
	print(">> Volviendo al menú principal...")
	# Siempre despausar antes de cambiar de escena
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://MenuPrincipal/escenas/menu.tscn")
