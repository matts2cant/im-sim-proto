class_name LevelNavigation
extends NavigationRegion3D
## Bakes the level's navigation mesh from its geometry when the level loads (synchronously,
## on the main thread, in `_ready`), so the navmesh always matches the geometry (ADR 0041).
## Source: every CSG root with collision under `source_root` (all kit parts and free CSG), plus
## static colliders of nodes in the group `navigation_source` (for non-CSG level objects).
## The agent is a standing human: spaces lower than `agent_height` (vents, crawl spaces) are left
## out automatically. Max climb 0.3 m: characters walk up steps of up to 0.35 m (StepClimber,
## ADR 0058), so steps and stairs of up to 0.3 m (the level rule, with margin) are on the navmesh;
## higher ledges (jumped or mantled) are not.
## Place it last among the level's children; call `bake()` again after changing the geometry
## (a quickload that removed geometry, such as a burnt barricade, does: QuickSave.REBAKE_GROUP).

const SOURCE_GROUP: StringName = &"navigation_source"

@export var source_root: NodePath = ^".."
@export_range(0.1, 2.0, 0.05, "suffix:m") var agent_radius := 0.35
@export_range(0.5, 3.0, 0.05, "suffix:m") var agent_height := 1.8
@export_range(0.0, 1.0, 0.05, "suffix:m") var agent_max_climb := 0.3
@export_range(0.0, 89.0, 1.0, "suffix:deg") var agent_max_slope := 45.0
## Voxel size (a divisor of the agent radius keeps it exact); the navigation map is set to match.
@export_range(0.05, 1.0, 0.05, "suffix:m") var cell_size := 0.05
@export_range(0.05, 1.0, 0.05, "suffix:m") var cell_height := 0.05
## Bake when the level loads. Tests that need no navmesh, or bake once on a synchronous map they set
## up first, turn it off before adding the level to the tree (a bake costs about 1 s in the
## warehouse).
@export var bake_on_ready := true


func _ready() -> void:
	add_to_group(QuickSave.REBAKE_GROUP)
	if bake_on_ready:
		bake()


## Collects the source geometry and bakes the navigation mesh on the calling thread.
func bake() -> void:
	var root := get_node_or_null(source_root)
	if root == null:
		push_error("LevelNavigation: source_root %s not found" % source_root)
		return
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = agent_radius
	nav_mesh.agent_height = agent_height
	nav_mesh.agent_max_climb = agent_max_climb
	nav_mesh.agent_max_slope = agent_max_slope
	nav_mesh.cell_size = cell_size
	nav_mesh.cell_height = cell_height
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = SOURCE_GROUP
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, root)
	_add_csg_faces(root, source)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	var map := get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, cell_size)
	NavigationServer3D.map_set_cell_height(map, cell_height)
	navigation_mesh = nav_mesh


func _add_csg_faces(node: Node, source: NavigationMeshSourceGeometryData3D) -> void:
	var csg := node as CSGShape3D
	if csg != null and csg.is_root_shape():
		if csg.use_collision:
			var faces := _collision_faces(csg)
			if not faces.is_empty():
				source.add_faces(faces, csg.global_transform)
		return
	for child: Node in node.get_children():
		_add_csg_faces(child, source)


# Collision faces of a CSG root in its local space. Inside the tree CSG rebuilds deferred, so its
# baked shape is empty right after loading and stale right after an edit: an out-of-tree copy
# computes the current faces immediately.
static func _collision_faces(csg: CSGShape3D) -> PackedVector3Array:
	var copy := csg.duplicate() as CSGShape3D
	copy.transform = Transform3D.IDENTITY
	var shape := copy.bake_collision_shape()
	copy.free()
	return shape.get_faces() if shape != null else PackedVector3Array()
