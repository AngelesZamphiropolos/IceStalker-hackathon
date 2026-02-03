extends Node

# --- INVENTARIO (Actualizado) ---
var tiene_fusible_rojo: bool = false
var tiene_fusible_azul: bool = false 
var tiene_fusible_verde: bool = false
var tiene_llave_puerta: bool = false
var tiene_engranaje: bool = false
var tiene_engranaje_2: bool = false 

# --- ESTADO DE MISIONES ---
var generador_reparado: bool = false
var ascensor_reparado: bool = false

# --- COMUNICACIÓN ---
signal minijuego_terminado(victoria: bool)

# Función para reiniciar (Game Over)
func reiniciar_todo():
	tiene_fusible_rojo = false
	tiene_fusible_azul = false 
	tiene_fusible_verde = false
	tiene_llave_puerta = false
	tiene_engranaje = false
	tiene_engranaje_2 = false
	generador_reparado = false
	ascensor_reparado = false
