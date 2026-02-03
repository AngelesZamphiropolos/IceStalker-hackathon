extends Node2D

var tiempo_restante = 60

var primera_carta = null
var segunda_carta = null
var bloqueado = false

func _ready():
	$Timer.timeout.connect(_on_timer_timeout)

	$Titulo.text = "Empareja las cartas. Puedes ver dos a la vez."
	$Tiempo.text = "Tiempo: " + str(tiempo_restante)

	crear_cartas()

func _on_timer_timeout():
	tiempo_restante -= 1
	$Tiempo.text = "Tiempo: " + str(tiempo_restante)

	if tiempo_restante <= 0:
		tiempo_terminado()

func tiempo_terminado():
	for carta in get_tree().get_nodes_in_group("cartas"):
		carta.volver_al_dorso()
	$Timer.stop()

func carta_seleccionada(carta):
	if bloqueado:
		return

	if primera_carta == null:
		primera_carta = carta
	elif segunda_carta == null and carta != primera_carta:
		segunda_carta = carta
		bloqueado = true
		comparar_cartas()

func comparar_cartas():
	if primera_carta.id == segunda_carta.id:
		primera_carta.emparejada = true
		segunda_carta.emparejada = true
		verificar_victoria()
		reiniciar_turno()
	else:
		await get_tree().create_timer(1.0).timeout
		primera_carta.volver_al_dorso()
		segunda_carta.volver_al_dorso()
		reiniciar_turno()

func reiniciar_turno():
	primera_carta = null
	segunda_carta = null
	bloqueado = false

func verificar_victoria():
	for carta in get_tree().get_nodes_in_group("cartas"):
		if not carta.emparejada:
			return

	$Titulo.text = "¡Ganaste!"
	$Timer.stop()

func crear_cartas():
	var escena_carta = preload("res://scenes/carta.tscn")

	var ids = [1,1,2,2,3,3,4,4,5,5,6,6]
	ids.shuffle()

	for i in range(12):
		var nueva_carta = escena_carta.instantiate()
		nueva_carta.id = ids[i]
		add_child(nueva_carta)

		var fila = i / 4
		var columna = i % 4

		nueva_carta.position = Vector2(250 + columna * 160, 200 + fila * 180)
		
