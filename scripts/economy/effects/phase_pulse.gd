extends SpecialEffect
## "phase_pulse" (Flicker capstone). When the shield goes from empty to full
## it emits a shockwave that damages and staggers nearby enemies and destroys
## enemy projectiles.
## Parameters: radius_m, damage, stagger_s.

var _info: DamageInfo = DamageInfo.new()


func on_shield_restored() -> void:
	var enemies: EnemyManager = turret.get_tree().get_first_node_in_group(EnemyManager.GROUP) as EnemyManager
	if enemies == null:
		return
	var origin: Vector3 = turret.get_hit_point()
	var radius_m: float = _param("radius_m", 300.0)
	_info.amount = _param("damage", 60.0)
	_info.damage_type = "energy"
	_info.armour_pierce = 0.0
	_info.source_slot = &""
	# Copies of the lists: targets remove themselves while we go through them.
	for enemy: Enemy in enemies.get_enemies().duplicate():
		if enemy.is_alive() and enemy.global_position.distance_to(origin) <= radius_m:
			enemy.stagger(_param("stagger_s", 1.5))
			enemy.apply_damage(_info)
	for projectile: EnemyProjectile in enemies.get_projectiles().duplicate():
		if projectile.is_alive() and projectile.global_position.distance_to(origin) <= radius_m:
			_info.amount = 100000.0
			projectile.apply_damage(_info)
	var fx: CombatFx = enemies.get_fx()
	if fx != null:
		fx.flash(origin, 10.0, radius_m, Color(0.4, 1.0, 0.95), 0.6, 2.0)
	EventBus.ui_message.emit("PHASE PULSE")
