extends RefCounted
## Object pools (M7 performance): knives, arrows and loot are reused instead of
## being made and thrown away all the time. A finished one leaves the scene
## tree and waits here; the next one asked for comes from here if there is one.
## (Particle effects have their own round-robin pool in fx.gd.)
##
## Use it with `const Pool := preload("res://scripts/pool.gd")`:
##   var arrow = Pool.take("arrow")   # null if the pool is empty: make a new one
##   Pool.give_back("arrow", arrow)   # when it's done

## How many spare nodes of one kind are kept; extras are freed.
const MAX_KEPT := 48

static var _free := {}


## A spare node of `kind`, or null if there isn't one.
static func take(kind: String) -> Node:
	var nodes: Array = _free.get(kind, [])
	while not nodes.is_empty():
		var node = nodes.pop_back()
		if is_instance_valid(node):
			return node
	return null


## Takes `node` out of the scene and keeps it for reuse (or frees it if the pool is full).
static func give_back(kind: String, node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	var nodes: Array = _free.get(kind, [])
	_free[kind] = nodes
	if nodes.size() >= MAX_KEPT:
		node.queue_free()
		return
	nodes.append(node)
