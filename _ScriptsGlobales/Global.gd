extends Node

# Aquí guardamos los nombres de lo que recoges. Ej: ["llave_roja", "engranaje"]
var inventario: Array = []

func agregar_item(nombre_item: String):
	if not nombre_item in inventario:
		inventario.append(nombre_item)
		print("Has recogido: " + nombre_item)

func tiene_item(nombre_item: String) -> bool:
	return nombre_item in inventario

func tiene_todos(lista_items: Array) -> bool:
	for item in lista_items:
		if not item in inventario:
			return false 
	return true
