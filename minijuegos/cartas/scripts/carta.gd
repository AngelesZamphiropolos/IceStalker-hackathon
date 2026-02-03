extends Area2D

var esta_boca_arriba = false
var id = 0
var emparejada = false

func _ready():
	add_to_group("cartas")
	voler_estado_inicial()

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		if not esta_boca_arriba and not emparejada:
			dar_vuelta()
			get_parent().carta_seleccionada(self)

func dar_vuelta():
	$Frente.visible = true
	$Dorso.visible = false
	esta_boca_arriba = true

func volver_al_dorso():
	$Frente.visible = false
	$Dorso.visible = true
	esta_boca_arriba = false

func voler_estado_inicial():
	$Frente.visible = false
	$Dorso.visible = true
	esta_boca_arriba = false
	emparejada = false
