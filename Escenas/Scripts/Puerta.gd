extends StaticBody2D

# ¿Qué item necesito para abrir esto?
@export var llave_necesaria: String = "llave_pasillo"

# Esta función la llamará tu Jugador al presionar el botón de interactuar
func interactuar():
	if Global.tiene_item(llave_necesaria):
		print("¡Abriendo puerta!")
		queue_free() 
	else:
		print("Está cerrada. Necesitas: " + llave_necesaria)
