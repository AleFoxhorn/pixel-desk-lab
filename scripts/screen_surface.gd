extends RefCounted
## Approximate the reference's visible silhouette; replace only this adapter with final mesh/UVs.
const DISPLAY_SIZE: Vector2 = Vector2(2.5, 1.25)
## Native pixels for all screen UI, independent of the outer 3D viewport.
const TEXTURE_SIZE: Vector2i = Vector2i(320, 160)
const OUTLINE: Array[Vector2] = [
	Vector2(0.16, 0.23), Vector2(0.20, 0.18), Vector2(0.29, 0.14),
	Vector2(0.87, 0.025), Vector2(0.94, 0.025), Vector2(0.975, 0.065),
	Vector2(0.985, 0.13), Vector2(0.93, 0.80), Vector2(0.915, 0.87),
	Vector2(0.88, 0.90), Vector2(0.09, 0.995), Vector2(0.04, 0.98),
	Vector2(0.025, 0.93), Vector2(0.04, 0.84), Vector2(0.12, 0.34)]

static func outline() -> PackedVector2Array:
	var contour: PackedVector2Array = []
	for index: int in range(OUTLINE.size()):
		var corner: Vector2 = OUTLINE[index]
		var start: Vector2 = corner.lerp(OUTLINE[posmod(index - 1, OUTLINE.size())], 0.25)
		var finish: Vector2 = corner.lerp(OUTLINE[(index + 1) % OUTLINE.size()], 0.25)
		for step: int in range(6):
			var weight: float = float(step) / 5.0
			contour.append(start.lerp(corner, weight).lerp(corner.lerp(finish, weight), weight))
	return contour

static func make_mesh() -> ArrayMesh:
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	for point: Vector2 in outline():
		vertices.append(Vector3((point.x - 0.5) * DISPLAY_SIZE.x, (0.5 - point.y) * DISPLAY_SIZE.y, 0))
		normals.append(Vector3.BACK)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = outline()
	arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(outline())
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func make_fitted_mesh(profile: Dictionary, model_scale: Vector3) -> ArrayMesh:
	var vertices: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var indices: PackedInt32Array = []
	for value: Array in profile["vertices"]:
		vertices.append(Vector3(float(value[0]), float(value[1]), float(value[2])) * model_scale)
		normals.append(Vector3.BACK)
	for value: Array in profile["uvs"]:
		uvs.append(Vector2(float(value[0]), float(value[1])))
	for value: int in profile["indices"]:
		indices.append(value)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
