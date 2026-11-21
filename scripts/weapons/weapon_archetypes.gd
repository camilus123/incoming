class_name WeaponArchetypes
extends RefCounted
## Names of the weapon archetypes that have an implementation.
##
## Kept free of dependencies so the data validator can use it from the
## command line. [WeaponFactory] maps these names to scripts; a unit test
## checks that the two lists match.

const IMPLEMENTED: PackedStringArray = ["hitscan_pulse", "homing"]
