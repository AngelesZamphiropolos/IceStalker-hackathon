extends Area2D

var velocidad = 400.0
var radio_choque = 15.0 

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta):
	# 1. Caída
	position.y += velocidad * delta
	
	# 2. DETECCIÓN MANUAL
	# Buscamos al hermano "Nave" dentro del padre (MinijuegoNaves)
	var nave = get_parent().get_node_or_null("Nave")
	
	if nave:
		# Calculamos distancia en línea recta entre el centro del meteoro y la nave
		var distancia = global_position.distance_to(nave.global_position)
		
		# Si está más cerca que el radio de choque explota jejeke
		if distancia < radio_choque:
			print("¡IMPACTO MATEMÁTICO! Distancia: ", distancia)
			if get_parent().has_method("perder_juego"):
				get_parent().perder_juego()
				set_process(false) #Dejar de procesar para no matar 2 veces

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()
