class_name EffectNames
extends RefCounted
## Names of the special effects that have an implementation. Kept free of
## dependencies so the data validator can use it; [EffectRegistry] maps the
## names to scripts (a unit test compares the two).

const IMPLEMENTED: PackedStringArray = [
	"damage_reduction_while_shielded",
	"aegis_bulwark",
	"reflex_field",
	"phase_pulse",
]
