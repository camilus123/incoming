class_name DamageResult
extends RefCounted
## Outcome of one hit, as computed by [DamageCalc].

## Shield points removed.
var shield_damage: float = 0.0
## Hull (hp) points removed.
var hull_damage: float = 0.0
## The hit took the shield from above 0 to 0.
var shield_broken: bool = false
## The hit reduced hp to 0.
var killed: bool = false
