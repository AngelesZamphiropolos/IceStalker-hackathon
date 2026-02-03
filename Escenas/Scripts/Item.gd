extends Area2D

# --- MENÚ DESPLEGABLE ACTUALIZADO ---
enum TipoItem { 
	FUSIBLE_ROJO, 
	FUSIBLE_AZUL, 
	FUSIBLE_VERDE, 
	LLAVE_PUERTA, 
	ENGRANAJE,
	ENGRANAJE_2 
}

# --- VARIABLES EXPORTADAS ---
@export_group("Configuración del Item")
@export var tipo_de_item: TipoItem = TipoItem.FUSIBLE_ROJO
@export var textura_del_item: Texture2D

func _ready():
	if textura_del_item != null:
		$Sprite2D.texture = textura_del_item

func interactuar(jugador):
	match tipo_de_item:
		TipoItem.FUSIBLE_ROJO:
			Global.tiene_fusible_rojo = true
			jugador.mostrar_pensamiento("Encontré el Fusible Rojo.")

		TipoItem.FUSIBLE_AZUL: 
			Global.tiene_fusible_azul = true 

		TipoItem.FUSIBLE_VERDE:
			Global.tiene_fusible_verde = true
			
		TipoItem.LLAVE_PUERTA:
			Global.tiene_llave_puerta = true
			jugador.mostrar_pensamiento("¡Recogi la LLAVE DE LA PUERTA!")
			
		TipoItem.ENGRANAJE:
			Global.tiene_engranaje = true
			jugador.mostrar_pensamiento("¡Recogi el PRIMER ENGRANAJE!")

		TipoItem.ENGRANAJE_2:
			Global.tiene_engranaje_2 = true
			jugador.mostrar_pensamiento("¡Recogi el SEGUNDO ENGRANAJE!")
	
	queue_free()
