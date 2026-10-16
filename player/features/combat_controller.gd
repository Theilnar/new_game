class_name CombatController
extends RefCounted

## Pure melee state decisions. Hitbox, stamina and animations remain in Player.

var stage: int = 0
var queued: bool = false
var charging: bool = false
var charge_elapsed: float = 0.0
var heavy: bool = false
var stamina_paid: bool = false

func tick_charge(delta: float) -> void:
	if charging:
		charge_elapsed += delta

func begin_charge() -> void:
	charging = true
	charge_elapsed = 0.0
	queued = false

func cancel_charge() -> void:
	charging = false
	charge_elapsed = 0.0
	queued = false

func clear_attack() -> void:
	stage = 0
	queued = false
	charging = false
	charge_elapsed = 0.0
	heavy = false
	stamina_paid = false
