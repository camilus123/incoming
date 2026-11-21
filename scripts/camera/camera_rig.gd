class_name CameraRig
extends Node3D
## Base class for camera rigs.
##
## The turret, weapons and input code only talk to this interface, so another
## rig (for example a third-person one) can be added without touching them.
## The rig never decides where the turret aims: it is told the aim transform
## every frame and only adds presentation (recoil kick, screen shake).


## Called once by the turret after the rig is in the tree.
## `camera_config` is the "camera" block of turret.json.
func configure(_camera_config: Dictionary) -> void:
	pass


## Called every frame with the exact (unsmoothed) aim transform of the
## turret's sighting position.
func update_rig(_aim_transform: Transform3D, _delta_s: float) -> void:
	pass


## The camera that renders the world (used for HUD projections).
func get_camera() -> Camera3D:
	return null


## Render layer mask for models that belong to the first-person view
## (turret and guns). A rig without a separate view returns the world layer.
func get_viewmodel_layers() -> int:
	return Layers.RENDER_WORLD


## Converts a point on a first-person model (for example a muzzle) to the
## world position where it appears on screen. Needed because the first-person
## view can use a different field of view than the world.
func viewmodel_to_world(world_position: Vector3) -> Vector3:
	return world_position


## Vertical field of view of the world camera in degrees.
func get_vertical_fov_deg() -> float:
	return 60.0


## Kicks the view up by `pitch_deg`; it recovers by itself.
func add_recoil(_pitch_deg: float) -> void:
	pass


## Adds screen shake; `amount` is 0..1 and accumulates up to 1.
func add_shake(_amount: float) -> void:
	pass
