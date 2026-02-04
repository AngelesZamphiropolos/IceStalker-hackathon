extends Control

# --- configuración de recursos ---
@export_group("Configuración del Nivel")
@export var escena_meteorito: PackedScene 
@export var texturas_meteoritos: Array[Texture2D] 
@export var velocidad_nave: float = 500.0

# --- referencias internas ---
@onready var nave = $Nave
@onready var label_tiempo = $Label
@onready var timer_juego = $TimerJuego
# guarda el ancho de pantalla para calcular límites
@onready var pantalla_ancho = get_viewport_rect().size.x

# estado del juego
var juego_activo = true

func _ready():
	randomize()
	# pausa el juego principal mientras corre el minijuego
	get_tree().paused = true
	
	# conexión de señales de los timers
	$TimerSpawn.timeout.connect(_spawner_meteoritos)
	$TimerJuego.timeout.connect(_ganar_juego)

func _process(delta):
	# si el juego terminó, no procesar nada
	if not juego_activo: return
	
	# actualiza el texto del tiempo restante
	label_tiempo.text = "TIEMPO: " + str(ceil(timer_juego.time_left))
	
	# movimiento horizontal según input
	var input = Input.get_axis("mover_izquierda", "mover_derecha")
	nave.position.x += input * velocidad_nave * delta
	
	# restringe la posición para no salir de la pantalla
	nave.position.x = clamp(nave.position.x, 30, pantalla_ancho - 30)

func _spawner_meteoritos():
	if not juego_activo: return
	
	var meteoro = escena_meteorito.instantiate()
	
	# posición aleatoria en x, arriba de la pantalla en y
	var random_x = randf_range(20, pantalla_ancho - 20)
	meteoro.position = Vector2(random_x, -50)
	
	# asigna textura aleatoria si hay disponibles
	if texturas_meteoritos.size() > 0:
		meteoro.get_node("Sprite2D").texture = texturas_meteoritos.pick_random()
	
	add_child(meteoro)

# --- sistema de control de estado ---

func perder_juego():
	juego_activo = false
	label_tiempo.text = "¡FALLASTE!"
	$TimerSpawn.stop()
	
	# espera un momento para mostrar el resultado
	await get_tree().create_timer(1.0).timeout
	cerrar_minijuego(false) 

func _ganar_juego():
	juego_activo = false
	label_tiempo.text = "¡SOBREVIVISTE!"
	$TimerSpawn.stop()
	
	# elimina todos los meteoritos restantes en el grupo
	get_tree().call_group("Meteorito", "queue_free")
	
	await get_tree().create_timer(1.0).timeout
	cerrar_minijuego(true) 

func cerrar_minijuego(victoria: bool):
	# emite señal con el resultado a global
	Global.minijuego_terminado.emit(victoria)
	
	# despausa el juego principal
	get_tree().paused = false
	
	# elimina el nodo del minijuego
	queue_free()
