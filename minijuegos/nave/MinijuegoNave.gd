extends Control

# --- CONFIGURACIÓN ---
@export var escena_meteorito: PackedScene # Arrastra Meteorito.tscn aquí en el editor
@export var texturas_meteoritos: Array[Texture2D] # Arrastra tus 3 imagenes aquí
@export var velocidad_nave: float = 500.0

# --- REFERENCIAS ---
@onready var nave = $Nave
@onready var label_tiempo = $Label
@onready var timer_juego = $TimerJuego
@onready var pantalla_ancho = get_viewport_rect().size.x

# Estado
var juego_activo = true

func _ready():
	randomize()
	# Nos aseguramos de pausar el juego principal al abrir esto
	get_tree().paused = true 
	
	# Conectamos timers por código o hazlo en el editor
	$TimerSpawn.timeout.connect(_spawner_meteoritos)
	$TimerJuego.timeout.connect(_ganar_juego)

func _process(delta):
	if not juego_activo: return
	
	# 1. Actualizar UI
	label_tiempo.text = "TIEMPO: " + str(ceil(timer_juego.time_left))
	
	# 2. Movimiento de la Nave (Simple, sin físicas complejas)
	var input = Input.get_axis("mover_izquierda", "mover_derecha")
	nave.position.x += input * velocidad_nave * delta
	
	# 3. Limites de pantalla (Clamp)
	nave.position.x = clamp(nave.position.x, 30, pantalla_ancho - 30)

func _spawner_meteoritos():
	if not juego_activo: return
	
	# Crear meteorito
	var meteoro = escena_meteorito.instantiate()
	
	# Posición aleatoria arriba (fuera de pantalla)
	var random_x = randf_range(20, pantalla_ancho - 20)
	meteoro.position = Vector2(random_x, -50)
	
	# Textura aleatoria (si cargaste las 3 imagenes)
	if texturas_meteoritos.size() > 0:
		meteoro.get_node("Sprite2D").texture = texturas_meteoritos.pick_random()
	
	# Añadir a la escena
	add_child(meteoro)

# --- SISTEMA ESTÁNDAR (ESTO USARÁS EN TODOS LOS MINIJUEGOS) ---

func perder_juego():
	juego_activo = false
	label_tiempo.text = "¡FALLASTE!"
	$TimerSpawn.stop()
	
	# Esperar 1 segundo y cerrar
	await get_tree().create_timer(1.0).timeout
	cerrar_minijuego(false) # False = Perdió

func _ganar_juego():
	juego_activo = false
	label_tiempo.text = "¡SOBREVIVISTE!"
	$TimerSpawn.stop()
	
	# Borrar meteoritos restantes visualmente
	get_tree().call_group("Meteorito", "queue_free")
	
	await get_tree().create_timer(1.0).timeout
	cerrar_minijuego(true) # True = Ganó

func cerrar_minijuego(victoria: bool):
	# 1. Avisar al Global
	if victoria:
		print("Minijuego Ganado")
		# Global.minijuego_ganado.emit() <--- DESCOMENTAR CUANDO TENGAS EL GLOBAL
	else:
		print("Minijuego Perdido")
		# Global.minijuego_perdido.emit() <--- DESCOMENTAR CUANDO TENGAS EL GLOBAL
	
	# 2. Despausar el juego principal
	get_tree().paused = false
	
	# 3. Autodestrucción
	queue_free()
