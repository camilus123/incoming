extends Node
## Autoload "EventBus": cross-system signals.
##
## Unrelated systems talk through these signals instead of holding references
## to each other. Emit with `EventBus.enemy_killed.emit(...)`, listen with
## `EventBus.enemy_killed.connect(...)`.

@warning_ignore_start("unused_signal")

## Data files were (re)loaded. `report` is a [DataReport].
signal data_reloaded(report: DataReport)

## A stage began or ended. `stage` is 1-based.
signal stage_started(stage: int)
signal stage_completed(stage: int)
signal wave_started(stage: int, wave: int)

## An enemy was destroyed by the player.
signal enemy_killed(enemy_id: StringName, bounty: int)
## An enemy projectile (missile, bomb, pod) was shot down.
signal enemy_projectile_intercepted(projectile_id: StringName)

## Turret state changes.
signal shield_broken()
signal shield_restored()
signal hull_damaged(amount: float, remaining: float)
## The shield absorbed (part of) a hit.
signal shield_hit(amount: float, remaining: float)
signal turret_destroyed()
signal power_split_changed(shield_share: float)

## Weapon events. `slot` is "primary" or "alternate".
signal weapon_fired(slot: StringName)
signal weapon_overheated(slot: StringName)
## A player shot damaged a target. `slot` is the weapon slot that hit.
signal target_hit(slot: StringName, killed: bool)

## A short message for the player, shown by the HUD.
signal ui_message(text: String)

## Economy.
signal credits_changed(total: int)

@warning_ignore_restore("unused_signal")
