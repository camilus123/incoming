class_name WeaponContext
extends RefCounted
## Everything a weapon needs from the outside world, handed to it by the
## turret. Keeps weapons independent of the turret, camera and scene layout.

## Camera rig, for recoil, shake and muzzle positions.
var rig: CameraRig
## Pooled effects (may be null in tests).
var fx: CombatFx
## Pooled homing missiles (may be null in tests).
var missiles: MissileSystem
## Physics world for raycasts.
var world: World3D
## Weapon output multiplier from the power split (1.0 until M3).
var power_output: float = 1.0
## Exact aim ray of the turret, updated every frame before weapons run.
var aim_origin: Vector3 = Vector3.ZERO
var aim_direction: Vector3 = Vector3.FORWARD
