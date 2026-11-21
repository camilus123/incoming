class_name EffectRegistry
extends RefCounted
## Creates special effects by name (see [SpecialEffect]).

const EFFECTS: Dictionary = {
	"damage_reduction_while_shielded": preload("res://scripts/economy/effects/damage_reduction_while_shielded.gd"),
	"aegis_bulwark": preload("res://scripts/economy/effects/aegis_bulwark.gd"),
	"reflex_field": preload("res://scripts/economy/effects/reflex_field.gd"),
	"phase_pulse": preload("res://scripts/economy/effects/phase_pulse.gd"),
}


## Returns a new effect for `{ "effect": name, "params": {...} }`, or null if
## the name is unknown.
static func create(effect_data: Dictionary, turret: Turret) -> SpecialEffect:
	var effect_name: String = effect_data.get("effect", "")
	if not EFFECTS.has(effect_name):
		push_warning("Special effect \"%s\" is not implemented" % effect_name)
		return null
	var script: GDScript = EFFECTS[effect_name]
	var effect: SpecialEffect = script.new() as SpecialEffect
	effect.setup(turret, effect_data.get("params", {}))
	return effect
