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
@export_group("Sonidos")
@export var sfx_interaccion: AudioStream
@export var sfx_generador_arreglado: AudioStream 

@export_group("Configuración Principal")
@export var tipo: TipoObjeto = TipoObjeto.PUERTA_COMUN
@export var textura_objeto: Texture2D

@export_group("Para Minijuegos")
@export var escena_minijuego: PackedScene

# Referencias internas
@onready var icono_alerta = $IconoAlerta
@onready var audio_interact = $AudioInteract
var minijuego_abierto = false
var capa_temporal: CanvasLayer = null

# Variable del jugador
var jugador_actual = null 

func _ready():
	if textura_objeto != null:
		$Sprite2D.texture = textura_objeto
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# --- SISTEMA DE ALERTA VISUAL ---

func _on_body_entered(body):
	if body is CharacterBody2D: 
		icono_alerta.visible = true
		var tween = create_tween()
		tween.tween_property(icono_alerta, "position:y", -60, 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(icono_alerta, "position:y", -50, 0.2).set_trans(Tween.TRANS_SINE)

func _on_body_exited(body):
	if body is CharacterBody2D:
		icono_alerta.visible = false

# --- INTERACCIÓN PRINCIPAL ---

func interactuar(jugador):
	# Reproducimos el sonido "click" genérico primero
	if sfx_interaccion:
		audio_interact.stream = sfx_interaccion
		audio_interact.play()
		
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
	#si el generador esta reparado, avisamos con el pensamiento
	if Global.generador_reparado:
		if sfx_generador_arreglado:
			audio_interact.stream = sfx_generador_arreglado
			audio_interact.play()
		jugador.mostrar_pensamiento("El motor ruge con fuerza. Ya está funcionando.")
		return

	# --- REQUISITOS: 3 FUSIBLES + 2 ENGRANAJES ---
	if Global.tiene_fusible_rojo and Global.tiene_fusible_azul and Global.tiene_fusible_verde and Global.tiene_engranaje and Global.tiene_engranaje_2:
		
		jugador.mostrar_pensamiento("La energía solo alcanza para el ascensor, no puedo encender las luces.")
		Global.generador_reparado = true
		
		# Sonido de éxito (Motor arrancando)
		if sfx_generador_arreglado:
			audio_interact.stream = sfx_generador_arreglado
			audio_interact.play()
		
	else:
		# --- LISTA DE COSAS QUE FALTAN ---
		var faltantes = ""
		
		if not Global.tiene_fusible_rojo: faltantes += "Fusible Rojo, "
		if not Global.tiene_fusible_azul: faltantes += "Fusible Azul, "
		if not Global.tiene_fusible_verde: faltantes += "Fusible Verde, "
		# Mostramos los engranajes por separado
		if not Global.tiene_engranaje: faltantes += "Engranaje 1, "
		if not Global.tiene_engranaje_2: faltantes += "Engranaje 2, "
		
		# Estética: Quitamos la última coma y espacio extra
		if faltantes.length() > 0:
			faltantes = faltantes.left(faltantes.length() - 2)
		
		jugador.mostrar_pensamiento("Faltan piezas: " + faltantes)

func accion_ascensor(jugador):
	if Global.generador_reparado:
		jugador.mostrar_pensamiento("¡Por fin! Sácame de aquí.")
		
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://MenuPrincipal/escenas/ganado.tscn") 
	else:
		jugador.mostrar_pensamiento("No tiene energía. Debo arreglar el generador.")

# --- SISTEMA DE MINIJUEGOS ---

func abrir_minijuego(jugador):
	if tipo == TipoObjeto.TV_NAVES and Global.tiene_fusible_azul:
		jugador.mostrar_pensamiento("La TV ya me soltó un fusible azul.")
		return
	if tipo == TipoObjeto.MESA_CARTAS and Global.tiene_fusible_verde:
		jugador.mostrar_pensamiento("Ya encontré el fusible verde en la mesa.")
		return

	if minijuego_abierto or escena_minijuego == null: return

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
		if jugador_actual:
			jugador_actual.mostrar_pensamiento("Maldición, casi lo tenía...")

func entregar_recompensa():
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
