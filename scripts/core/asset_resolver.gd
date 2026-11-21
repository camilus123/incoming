class_name AssetResolver
extends RefCounted
## Turns asset IDs into loaded resources.
##
## Game code never uses file paths. It asks for an ID such as
## "model.turret.base" and this class looks the path up in
## data/assets/asset_manifest.json. Swapping a model means editing one line
## of the manifest.
##
## Override roots are the hook for the future mods/ folder (see
## docs/ROADMAP.md): a file found under an override root at the same relative
## path as the manifest entry wins over the built-in one. Loading external
## glTF and images at runtime is not implemented yet.

var _assets: Dictionary = {}                 # asset id -> { path, type, fallback? }
var _cache: Dictionary = {}                  # asset id -> Resource
var _override_roots: PackedStringArray = []
var _warned: Dictionary = {}                 # asset id -> true, so each warning prints once


## Replaces the manifest (the "asset_manifest" config) and clears the cache.
func configure(manifest: Dictionary) -> void:
	_assets = manifest.get("assets", {})
	_cache.clear()
	_warned.clear()


## Registers a directory that can override built-in assets (future mods/ support).
func add_override_root(directory: String) -> void:
	if not _override_roots.has(directory):
		_override_roots.append(directory)


func has_asset(asset_id: String) -> bool:
	return _assets.has(asset_id)


## Returns the manifest type of an asset ("model", "texture", "audio", ...), or "".
func get_asset_type(asset_id: String) -> String:
	var entry: Dictionary = _assets.get(asset_id, {})
	return entry.get("type", "")


## Returns the file path for an asset ID, or "" if the ID is unknown.
func resolve_path(asset_id: String) -> String:
	var entry: Dictionary = _assets.get(asset_id, {})
	var path: String = entry.get("path", "")
	if path.is_empty():
		return ""
	var relative: String = path.trim_prefix("res://")
	for root: String in _override_roots:
		var candidate: String = root.path_join(relative)
		if FileAccess.file_exists(candidate):
			return candidate
	return path


## Loads the resource for an asset ID. If it is missing, tries the entry's
## "fallback" ID, then returns null. Callers must cope with null (for example
## by showing a placeholder) so a bad manifest never crashes the game.
func load_asset(asset_id: String) -> Resource:
	if _cache.has(asset_id):
		return _cache[asset_id]
	var resource: Resource = null
	var path: String = resolve_path(asset_id)
	if not path.is_empty() and ResourceLoader.exists(path):
		resource = ResourceLoader.load(path)
	if resource == null:
		_warn_once(asset_id, "asset \"%s\" could not be loaded (path: \"%s\")" % [asset_id, path])
		var entry: Dictionary = _assets.get(asset_id, {})
		var fallback: String = entry.get("fallback", "")
		if not fallback.is_empty() and fallback != asset_id:
			resource = load_asset(fallback)
	if resource != null:
		_cache[asset_id] = resource
	return resource


func _warn_once(asset_id: String, message: String) -> void:
	if _warned.has(asset_id):
		return
	_warned[asset_id] = true
	push_warning(message)
