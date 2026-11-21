class_name SpecialEffect
extends RefCounted
## Base class of special upgrade effects: behaviour that plain stat modifiers
## cannot express (Aegis Bulwark, Phase Pulse, ...).
##
## A tree node names an effect and its parameters:
##   { "effect": "aegis_bulwark", "params": { "restore_fraction": 0.5 } }
## The turret creates one instance per purchased effect and calls the hooks
## below. A new effect is one small script plus one line in [EffectRegistry]
## (and in [EffectNames]).

var turret: Turret
var params: Dictionary = {}


func setup(owner_turret: Turret, effect_params: Dictionary) -> void:
	turret = owner_turret
	params = effect_params


## A stage is starting (per-stage charges reset here).
func on_stage_start() -> void:
	pass


## Called every frame during play.
func tick(_delta_s: float) -> void:
	pass


## May change damage before the shield takes it. Return the new amount.
func modify_incoming_damage(amount: float, _damage_type: String) -> float:
	return amount


## A hit is about to destroy the turret. Return true to cancel it.
func absorb_lethal_hit() -> bool:
	return false


## The shield was just emptied.
func on_shield_broken() -> void:
	pass


## The shield just went from empty back to full.
func on_shield_restored() -> void:
	pass


func _param(key: String, fallback: float) -> float:
	return float(params.get(key, fallback))
