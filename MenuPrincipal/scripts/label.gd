extends RichTextLabel

func _ready():
	# Activa el BBCode por código si no lo hiciste en el inspector
	bbcode_enabled = true
	
	# Escribe el texto con la etiqueta [wave]
	# amp = amplitud (qué tan alto sube/baja)
	# freq = frecuencia (qué tan rápido se mueve)
	text = "[wave amp=35 freq=5]¡HAS MUERTO![/wave]"
