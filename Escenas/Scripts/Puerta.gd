extends StaticBody2D

# ¿Qué item necesito para abrir esto? (Debe coincidir con el nombre del Item)
@export var llave_necesaria: String = "llave_pasillo"

# Esta función la llamará tu Jugador al presionar el botón de interactuar
func interactuar():
	if Global.tiene_item(llave_necesaria):
		print("¡Abriendo puerta!")
		queue_free() # Borra la puerta (se abre)
		# Opcional: Aquí podrías poner una animación o sonido antes de borrarla
	else:
		print("Está cerrada. Necesitas: " + llave_necesaria)
