extends Area2D

# Escribe aquí el nombre. Ej: "llave_pasillo" o "engranaje_motor"
@export var nombre_del_item: String = "item_generico"

func _ready():
	# Conectamos la señal de que alguien entró en el área
	body_entered.connect(_on_body_entered)

func _on_body_entered(cuerpo):
	# Si es el jugador quien toca el item
	if cuerpo.name == "Jugador":
		Global.agregar_item(nombre_del_item)
		queue_free() # Desaparece el objeto del mundo
