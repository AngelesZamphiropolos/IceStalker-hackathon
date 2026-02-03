extends Area2D

# --- TIPOS DE OBJETOS ---
enum TipoObjeto {
	PUERTA_COMUN,
	GENERADOR,
	ASCENSOR,
	TV_NAVES,
	MESA_CARTAS
}

# --- CONFIGURACIÓN ---
@export_group("Configuración Principal")
@export var tipo: TipoObjeto = TipoObjeto.PUERTA_COMUN
@export var textura_objeto: Texture2D

@export_group("Para Minijuegos")
@export var escena_minijuego: PackedScene

# Referencias internas
@onready var icono_alerta = $IconoAlerta
var minijuego_abierto = false
var capa_temporal: CanvasLayer = null

# VARIABLE NUEVA: Guardamos quién está jugando para hablarle cuando gane
var jugador_actual = null 

func _ready():
	if textura_objeto != null:
		$Sprite2D.texture = textura_objeto
	
	# Conexión de señales de proximidad
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# --- SISTEMA DE ALERTA VISUAL ---

func _on_body_entered(body):
	if body is CharacterBody2D: 
		icono_alerta.visible = true
		
		# Animación de rebote suave para llamar la atención
		var tween = create_tween()
		tween.tween_property(icono_alerta, "position:y", -60, 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(icono_alerta, "position:y", -50, 0.2).set_trans(Tween.TRANS_SINE)

func _on_body_exited(body):
	if body is CharacterBody2D:
		icono_alerta.visible = false

# --- INTERACCIÓN PRINCIPAL ---

func interactuar(jugador):
	match tipo:
		TipoObjeto.PUERTA_COMUN:
			accion_puerta(jugador)
		TipoObjeto.GENERADOR:
			accion_generador(jugador)
		TipoObjeto.ASCENSOR:
			accion_ascensor(jugador)
		TipoObjeto.TV_NAVES:
			abrir_minijuego(jugador)
		TipoObjeto.MESA_CARTAS:
			abrir_minijuego(jugador)

# --- LÓGICA DE OBJETOS ---

func accion_puerta(jugador):
	if Global.tiene_llave_puerta:
		jugador.mostrar_pensamiento("Abriendo...")
		queue_free() 
	else:
		jugador.mostrar_pensamiento("Está cerrada. Necesito una llave.")

func accion_generador(jugador):
	if Global.generador_reparado:
		jugador.mostrar_pensamiento("Ya está funcionando.")
		return

	if Global.tiene_fusible_rojo and Global.tiene_fusible_azul and Global.tiene_fusible_verde:
		jugador.mostrar_pensamiento("La energía solo alcanza para el ascensor, no puedo encender las luces.")
		Global.generador_reparado = true
	else:
		var faltantes = ""
		if not Global.tiene_fusible_rojo: faltantes += "Rojo "
		if not Global.tiene_fusible_azul: faltantes += "Azul "
		if not Global.tiene_fusible_verde: faltantes += "Verde "
		
		jugador.mostrar_pensamiento("Faltan fusibles: " + faltantes)

func accion_ascensor(jugador):
	if Global.generador_reparado:
		jugador.mostrar_pensamiento("¡Por fin! Sácame de aquí.")
		get_tree().quit() 
	else:
		jugador.mostrar_pensamiento("No tiene energía. Debo arreglar el generador.")

# --- SISTEMA DE MINIJUEGOS ---

func abrir_minijuego(jugador):
	# Validaciones iniciales: zi ya tenemos el premio, solo damos feedback y salimos
	if tipo == TipoObjeto.TV_NAVES and Global.tiene_fusible_azul:
		jugador.mostrar_pensamiento("La TV ya me soltó un fusible azul.")
		return
	if tipo == TipoObjeto.MESA_CARTAS and Global.tiene_fusible_verde:
		jugador.mostrar_pensamiento("Ya encontré el fusible verde en la mesa.")
		return

	if minijuego_abierto or escena_minijuego == null: return

	# GUARDAMOS LA REFERENCIA DEL JUGADOR
	jugador_actual = jugador 

	print("Iniciando minijuego...")
	var juego = escena_minijuego.instantiate()
	
	if not Global.minijuego_terminado.is_connected(_al_terminar_minijuego):
		Global.minijuego_terminado.connect(_al_terminar_minijuego)
	
	capa_temporal = CanvasLayer.new()
	capa_temporal.layer = 100
	capa_temporal.add_child(juego)
	get_tree().root.add_child(capa_temporal)
	
	minijuego_abierto = true

func _al_terminar_minijuego(victoria: bool):
	minijuego_abierto = false
	if Global.minijuego_terminado.is_connected(_al_terminar_minijuego):
		Global.minijuego_terminado.disconnect(_al_terminar_minijuego)
	
	if capa_temporal != null:
		capa_temporal.queue_free()
		capa_temporal = null
	
	if victoria:
		entregar_recompensa()
	else:
		# Feedback opcional al perder
		if jugador_actual:
			jugador_actual.mostrar_pensamiento("Maldición, casi lo tenía...")

func entregar_recompensa():
	#la variable 'jugador_actual' para mostrar el pensamiento
	match tipo:
		TipoObjeto.TV_NAVES:
			if not Global.tiene_fusible_azul:
				Global.tiene_fusible_azul = true
				if jugador_actual:
					jugador_actual.mostrar_pensamiento("¡Bien! Cayó un fusible AZUL de la TV.")
					
		TipoObjeto.MESA_CARTAS:
			if not Global.tiene_fusible_verde:
				Global.tiene_fusible_verde = true
				if jugador_actual:
					jugador_actual.mostrar_pensamiento("¡Genial! Encontré un fusible VERDE en la mesa.")
	
	# Limpieza de referencia por seguridad
	#jugador_actual = null (no note ningun cambio de usar este o nel)
