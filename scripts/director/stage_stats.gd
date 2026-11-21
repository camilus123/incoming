class_name StageStats
extends RefCounted
## What the player did in one stage. Feeds the result screens now and the
## reward calculator in M4.

var stage: int = 1
var shots_fired: int = 0
var shots_hit: int = 0
var kills: int = 0
var bounty: int = 0
var intercepts: int = 0
var time_s: float = 0.0
var shield_broken: bool = false
var hull_max: float = 0.0
var hull_end: float = 0.0


## Hits per shot in percent, 0 to 100. Splash can hit several targets with
## one shot, so the value is capped.
func accuracy_percent() -> float:
	if shots_fired <= 0:
		return 0.0
	return minf(100.0, 100.0 * shots_hit / shots_fired)


## Remaining hull in percent, 0 to 100.
func hull_percent() -> float:
	if hull_max <= 0.0:
		return 0.0
	return clampf(100.0 * hull_end / hull_max, 0.0, 100.0)
