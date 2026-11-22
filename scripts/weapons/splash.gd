class_name Splash
extends RefCounted
## Splash damage shared by missiles, shells and explosions.


## Damages every live target within `radius_m` of `at`: full damage at the
## centre, falling off to the configured edge fraction. Distances are measured
## to each target's surface, so a direct hit always takes full damage.
## `info` supplies the damage type, pierce and source; its amount is set per
## target. Returns how many targets were hit.
static func apply(tree: SceneTree, at: Vector3, radius_m: float, full_damage: float, info: DamageInfo) -> int:
	if radius_m <= 0.0 or full_damage <= 0.0:
		return 0
	var edge_fraction: float = GameData.loader.get_config("combat").get("splash_edge_damage_fraction", 0.4)
	var hits: int = 0
	for node: Node in tree.get_nodes_in_group(CombatTarget.GROUP):
		var target: CombatTarget = node as CombatTarget
		if target == null or not target.is_alive():
			continue
		var distance: float = maxf(0.0, at.distance_to(target.get_aim_point()) - target.target_radius_m)
		var falloff: float = DamageCalc.splash_falloff(distance, radius_m, edge_fraction)
		if falloff <= 0.0:
			continue
		info.amount = full_damage * falloff
		info.hit_position = at
		target.apply_damage(info)
		hits += 1
	return hits
