class_name BehaviourModules
extends RefCounted
## Names of the behaviour modules that have an implementation.
## Kept free of dependencies so the data validator can use it;
## [BehaviourRegistry] maps the names to scripts (a unit test compares them).

const IMPLEMENTED: PackedStringArray = ["approach_kamikaze", "strafe", "level_pass"]
