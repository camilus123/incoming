class_name TechTree
extends RefCounted
## The tech tree's rules: which nodes can be bought, refunded or are locked
## out. Pure logic on top of data/techtree/tree.json, unit tested.
##
## Prerequisites: `requires.all_of` (every one) and `requires.any_of` (at
## least one). Nodes sharing an `exclusive_group` exclude each other: buying
## one locks the others, and everything that can only be reached through a
## locked node counts as excluded too.

enum NodeState { LOCKED, AVAILABLE, PURCHASED, EXCLUDED }

var _nodes: Dictionary = {}          # id -> node data
var _order: Array[String] = []       # ids in file order
var _branches: Dictionary = {}


## `config` is the "techtree" config. Nodes with duplicate ids are ignored.
func _init(config: Dictionary = {}) -> void:
	_branches = config.get("branches", {})
	for tree_node: Dictionary in config.get("nodes", []):
		var id: String = tree_node.get("id", "")
		if id.is_empty() or _nodes.has(id):
			continue
		_nodes[id] = tree_node
		_order.append(id)


func get_node_ids() -> Array[String]:
	return _order


func has_node(id: String) -> bool:
	return _nodes.has(id)


## Data of one node, or {} if it does not exist.
func get_node(id: String) -> Dictionary:
	return _nodes.get(id, {})


func get_branch(branch_id: String) -> Dictionary:
	return _branches.get(branch_id, {})


## Ids of the nodes the player owns from the beginning.
func get_start_nodes() -> Array[String]:
	var result: Array[String] = []
	for id: String in _order:
		if _nodes[id].get("owned_at_start", false):
			result.append(id)
	return result


func get_cost(id: String) -> int:
	return int(get_node(id).get("cost", 0))


## True if the node's own prerequisites are all purchased.
func prerequisites_met(id: String, purchased: Array[String]) -> bool:
	var requires: Dictionary = get_node(id).get("requires", {})
	for required: String in requires.get("all_of", []):
		if not purchased.has(required):
			return false
	var any_of: Array = requires.get("any_of", [])
	if any_of.is_empty():
		return true
	for candidate: String in any_of:
		if purchased.has(candidate):
			return true
	return false


## True if the node can no longer be obtained in this run: another node of
## its exclusive group was bought, or its prerequisites lead only through
## excluded nodes.
func is_excluded(id: String, purchased: Array[String]) -> bool:
	return _is_excluded(id, purchased, {})


func get_state(id: String, purchased: Array[String]) -> NodeState:
	if purchased.has(id):
		return NodeState.PURCHASED
	if is_excluded(id, purchased):
		return NodeState.EXCLUDED
	if prerequisites_met(id, purchased):
		return NodeState.AVAILABLE
	return NodeState.LOCKED


func can_buy(id: String, purchased: Array[String], credits: int) -> bool:
	return has_node(id) and get_state(id, purchased) == NodeState.AVAILABLE and credits >= get_cost(id)


## A purchased node can be refunded if it is not a starting node and no other
## purchased node needs it.
func can_refund(id: String, purchased: Array[String]) -> bool:
	if not purchased.has(id) or get_node(id).get("owned_at_start", false):
		return false
	var remaining: Array[String] = purchased.duplicate()
	remaining.erase(id)
	for other: String in remaining:
		if not prerequisites_met(other, remaining):
			return false
	return true


## Credits returned when the node is refunded at the given ratio (0 to 1).
func refund_value(id: String, ratio: float) -> int:
	return int(roundf(get_cost(id) * clampf(ratio, 0.0, 1.0)))


## Structural problems in a tree config, for the data validator:
## unknown references, cycles and nodes that can never be reached.
## Each entry is `{ "field": "nodes.<id>...", "problem": "..." }`.
static func find_problems(config: Dictionary) -> Array[Dictionary]:
	var problems: Array[Dictionary] = []
	var tree: TechTree = TechTree.new(config)
	var seen: Dictionary = {}
	for tree_node: Dictionary in config.get("nodes", []):
		var id: String = tree_node.get("id", "")
		if seen.has(id):
			problems.append({"field": "nodes." + id, "problem": "duplicate node id"})
		seen[id] = true
		if not config.get("branches", {}).has(tree_node.get("branch", "")):
			problems.append({"field": "nodes.%s.branch" % id, "problem": "unknown branch \"%s\"" % tree_node.get("branch", "")})
		for required: String in tree._prerequisites(id):
			if not tree.has_node(required):
				problems.append({"field": "nodes.%s.requires" % id, "problem": "unknown node \"%s\"" % required})
			elif required == id:
				problems.append({"field": "nodes.%s.requires" % id, "problem": "a node cannot require itself"})

	for id: String in tree.get_node_ids():
		if tree._on_cycle(id, id, {}):
			problems.append({"field": "nodes.%s.requires" % id, "problem": "prerequisites form a cycle"})

	# A node is reachable if its prerequisites can be met from the start nodes.
	var reachable: Array[String] = []
	var grew: bool = true
	while grew:
		grew = false
		for id: String in tree.get_node_ids():
			if not reachable.has(id) and tree.prerequisites_met(id, reachable):
				reachable.append(id)
				grew = true
	for id: String in tree.get_node_ids():
		if not reachable.has(id):
			problems.append({"field": "nodes." + id, "problem": "node can never be reached (check its prerequisites)"})
	return problems


func _prerequisites(id: String) -> Array[String]:
	var result: Array[String] = []
	var requires: Dictionary = get_node(id).get("requires", {})
	for required: String in requires.get("all_of", []):
		result.append(required)
	for required: String in requires.get("any_of", []):
		result.append(required)
	return result


func _is_excluded(id: String, purchased: Array[String], visiting: Dictionary) -> bool:
	if purchased.has(id) or visiting.has(id):
		return false
	visiting[id] = true
	var tree_node: Dictionary = get_node(id)
	var group: String = tree_node.get("exclusive_group", "")
	if not group.is_empty():
		for other: String in purchased:
			if other != id and get_node(other).get("exclusive_group", "") == group:
				return true
	var requires: Dictionary = tree_node.get("requires", {})
	for required: String in requires.get("all_of", []):
		if _is_excluded(required, purchased, visiting.duplicate()):
			return true
	var any_of: Array = requires.get("any_of", [])
	if not any_of.is_empty():
		for candidate: String in any_of:
			if not _is_excluded(candidate, purchased, visiting.duplicate()):
				return false
		return true
	return false


func _on_cycle(start: String, current: String, visited: Dictionary) -> bool:
	for required: String in _prerequisites(current):
		if required == start:
			return true
		if visited.has(required) or not has_node(required):
			continue
		visited[required] = true
		if _on_cycle(start, required, visited):
			return true
	return false
