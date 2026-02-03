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

# Referencia al icono (el signo de exclamación)
@onready var icono_alerta = $IconoAlerta

var minijuego_abierto = false

# Capa temporal para el minijuego
var capa_temporal: CanvasLayer = null

func _ready():
	if textura_objeto != null:
		$Sprite2D.texture = textura_objeto
	
	# CONECTAR SEÑALES AUTOMÁTICAMENTE
	# Detectamos cuando el jugador entra o sale de esta zona
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# --- SISTEMA DE ALERTA VISUAL ---

func _on_body_entered(body):
	# Si lo que entra es el Personaje (asegúrate que tu personaje se llame así o sea CharacterBody2D)
	if body is CharacterBody2D: 
		icono_alerta.visible = true
		
		# Animación extra: Un pequeño rebote (Tween)
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
		jugador.mostrar_pensamiento("¡Perfecto! Arrancando sistemas...")
		Global.generador_reparado = true
		modulate = Color(1.5, 0.0, 0.0, 0.8)
	else:
		# Feedback detallado
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

# --- SISTEMA DE MINIJUEGOS (UI FLOTANTE) ---

func abrir_minijuego(jugador):
	if tipo == TipoObjeto.TV_NAVES and Global.tiene_fusible_azul:
		jugador.mostrar_pensamiento("La tv me solto un fusible azul")
		return
	if tipo == TipoObjeto.MESA_CARTAS and Global.tiene_fusible_verde:
		jugador.mostrar_pensamiento("Cayo un fusible verde de las mesa.")
		return

	if minijuego_abierto or escena_minijuego == null: return

	print("Iniciando minijuego...")
	var juego = escena_minijuego.instantiate()
	
	if not Global.minijuego_terminado.is_connected(_al_terminar_minijuego):
		Global.minijuego_terminado.connect(_al_terminar_minijuego)
	
	# Usamos CanvasLayer para que el juego flote sobre la cámara
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

func entregar_recompensa():
	match tipo:
		TipoObjeto.TV_NAVES:
			if not Global.tiene_fusible_azul:
				Global.tiene_fusible_azul = true
				print("¡GANASTE EL FUSIBLE AZUL!")
		TipoObjeto.MESA_CARTAS:
			if not Global.tiene_fusible_verde:
				Global.tiene_fusible_verde = true
				print("¡GANASTE EL FUSIBLE VERDE!")
