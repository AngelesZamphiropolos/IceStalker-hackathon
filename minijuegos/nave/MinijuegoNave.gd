extends Control

# --- CONFIGURACIÓN DE RECURSOS ---
@export_group("Configuración del Nivel")
@export var escena_meteorito: PackedScene 
@export var texturas_meteoritos: Array[Texture2D] 
@export var velocidad_nave: float = 500.0

# --- REFERENCIAS INTERNAS ---
@onready var nave = $Nave
@onready var label_tiempo = $Label
@onready var timer_juego = $TimerJuego
# Cacheamos el tamaño de pantalla 
@onready var pantalla_ancho = get_viewport_rect().size.x

# Estado del juego
var juego_activo = true

func _ready():
	randomize()
	# Pausamos el árbol principal para centrar en el gameplay del minijuego
	get_tree().paused = true
	
	# Conexión de señales de lógica
	$TimerSpawn.timeout.connect(_spawner_meteoritos)
	$TimerJuego.timeout.connect(_ganar_juego)

func _process(delta):
	# Guard clause: Si el juego terminó, cortamos el proceso
	if not juego_activo: return
	
	# 1. Sincronización UI
	label_tiempo.text = "TIEMPO: " + str(ceil(timer_juego.time_left))
	
	# 2. Movimiento Horizontal 
	var input = Input.get_axis("mover_izquierda", "mover_derecha")
	nave.position.x += input * velocidad_nave * delta
	
	# 3. Restricción de movimiento a los bordes de la pantalla
	nave.position.x = clamp(nave.position.x, 30, pantalla_ancho - 30)

func _spawner_meteoritos():
	if not juego_activo: return
	
	var meteoro = escena_meteorito.instantiate()
	
	# Spawn point: Aleatorio en X, y justo arriba de la pantalla visible en Y
	var random_x = randf_range(20, pantalla_ancho - 20)
	meteoro.position = Vector2(random_x, -50)
	
	# Variación visual: Elegimos textura random si existen
	if texturas_meteoritos.size() > 0:
		meteoro.get_node("Sprite2D").texture = texturas_meteoritos.pick_random()
	
	add_child(meteoro)

# --- SISTEMA DE CONTROL DE ESTADO ---

func perder_juego():
	juego_activo = false
	label_tiempo.text = "¡FALLASTE!"
	$TimerSpawn.stop()
	
	# Pequeño delay para feedback visual antes de cerrar
	await get_tree().create_timer(1.0).timeout
	cerrar_minijuego(false) 

func _ganar_juego():
	juego_activo = false
	label_tiempo.text = "¡SOBREVIVISTE!"
	$TimerSpawn.stop()
	
	# Limpieza visual: Eliminamos amenazas restantes
	get_tree().call_group("Meteorito", "queue_free")
	
	await get_tree().create_timer(1.0).timeout
	cerrar_minijuego(true) 

func cerrar_minijuego(victoria: bool):
	# 1. Notificamos al sistema Global (para activar el generador si ganamos)
	Global.minijuego_terminado.emit(victoria)
	
	# 2. Reanudamos el juego principal
	get_tree().paused = false
	
	# 3. Limpieza de memoria
	queue_free()
