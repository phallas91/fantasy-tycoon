extends SubViewportContainer
## Procedural 3D "hero" quadcopter rendered in a transparent SubViewport so an
## otherwise-2D game can show a premium 3D flourish (boot intro, welcome popup).
## Built entirely from primitive meshes + StandardMaterial3D — needs no external
## .glb assets and runs under gl_compatibility. Self-animates via looping tweens
## (body yaw, hover bob, rotor spin); no per-frame _process.
##
## Instantiate via load("res://scripts/hero_drone.gd").new() (no class_name, to
## avoid the global-class-cache reimport dance). Set custom_minimum_size before
## adding to the tree; the SubViewport tracks the control size via `stretch`.

const BODY_COL   := Color(0.17, 0.22, 0.37)   # navy hull (bright enough to read)
const TRIM_COL   := Color(0.29, 0.55, 1.00)   # Sky accent
const CYAN_COL   := Color(0.23, 0.84, 0.94)
const GOLD_COL   := Color(1.00, 0.78, 0.22)

var _root: Node3D
var _rotors: Array = []

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	# Ambient fill so shadowed faces don't crush to black (gl_compatibility).
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.40, 0.50, 0.72)
	env.ambient_light_energy = 1.7
	var we := WorldEnvironment.new(); we.environment = env; vp.add_child(we)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.55, 4.3)
	cam.rotation_degrees = Vector3(-7.0, 0.0, 0.0)
	cam.fov = 40.0
	vp.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	key.light_energy = 2.3
	key.light_color = Color(1.0, 0.96, 0.88)
	vp.add_child(key)

	# front fill so the hull face toward camera never crushes to black
	var front := DirectionalLight3D.new()
	front.rotation_degrees = Vector3(-12.0, 18.0, 0.0)
	front.light_energy = 0.9
	front.light_color = Color(0.8, 0.88, 1.0)
	vp.add_child(front)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.6, 1.2, 1.2)
	rim.light_color = TRIM_COL
	rim.light_energy = 3.2
	rim.omni_range = 9.0
	vp.add_child(rim)

	var fill := OmniLight3D.new()
	fill.position = Vector3(2.4, -0.6, 2.2)
	fill.light_color = CYAN_COL
	fill.light_energy = 1.6
	fill.omni_range = 8.0
	vp.add_child(fill)

	_root = Node3D.new()
	vp.add_child(_root)
	_build(_root)
	_animate()

func _mat(albedo: Color, metallic: float, rough: float, emit := Color.BLACK, emit_e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = rough
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m

func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _build(root: Node3D) -> void:
	var hull := _mat(BODY_COL, 0.9, 0.26, Color(0.12, 0.17, 0.30), 0.45)
	var trim := _mat(TRIM_COL, 0.4, 0.3, TRIM_COL, 2.6)
	var glass := _mat(Color(0.06, 0.10, 0.18), 0.2, 0.05, CYAN_COL, 2.2)
	var dark := _mat(Color(0.06, 0.08, 0.13), 0.7, 0.45)

	# central hull (flattened, tapered look via scaled box + a top canopy)
	var body := BoxMesh.new(); body.size = Vector3(1.15, 0.30, 0.86)
	_add(root, body, hull, Vector3.ZERO)
	# Primitive meshes default to radial_segments=64/rings=32 — ~4k tris each. At a
	# 260px render target that detail is invisible, but generating + uploading 15
	# VBOs of it lands right on the boot intro. ~48k tris -> ~4k, same silhouette.
	var canopy := SphereMesh.new(); canopy.radial_segments = 16; canopy.rings = 8
	canopy.radius = 0.34; canopy.height = 0.5
	_add(root, canopy, glass, Vector3(0.0, 0.12, -0.04), Vector3.ZERO, Vector3(1.0, 0.55, 1.0))
	# accent spine strip along the top
	var spine := BoxMesh.new(); spine.size = Vector3(0.9, 0.05, 0.10)
	_add(root, spine, trim, Vector3(0.0, 0.17, 0.22))

	# camera gimbal ball underneath (front)
	var gimbal := SphereMesh.new(); gimbal.radial_segments = 14; gimbal.rings = 7
	gimbal.radius = 0.17
	_add(root, gimbal, dark, Vector3(0.0, -0.18, -0.28))
	var lens := SphereMesh.new(); lens.radial_segments = 10; lens.rings = 5
	lens.radius = 0.09
	_add(root, lens, _mat(Color.BLACK, 0.1, 0.05, CYAN_COL, 3.0), Vector3(0.0, -0.20, -0.40))

	# four arms + motors + rotors + glowing rings, at 45° corners
	var corners := [
		Vector3(-0.86, 0.0, -0.66), Vector3(0.86, 0.0, -0.66),
		Vector3(-0.86, 0.0,  0.66), Vector3(0.86, 0.0,  0.66),
	]
	# identical for all 4 rotors — built once instead of 4 duplicate materials
	var blade_mat := _mat(Color(0.8, 0.9, 1.0), 0.1, 0.2, CYAN_COL, 0.8)
	blade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blade_mat.albedo_color.a = 0.5
	for c: Vector3 in corners:
		# arm (thin box pointing from hull to the motor)
		var arm := BoxMesh.new(); arm.size = Vector3(c.length() * 2.0, 0.09, 0.15)
		var yaw := rad_to_deg(atan2(c.x, c.z))
		_add(root, arm, hull, c * 0.5, Vector3(0.0, yaw, 0.0))
		# motor pod
		var motor := CylinderMesh.new(); motor.radial_segments = 12
		motor.top_radius = 0.15; motor.bottom_radius = 0.17; motor.height = 0.22
		_add(root, motor, dark, c + Vector3(0.0, 0.02, 0.0))
		# glowing rotor ring (torus)
		var ring := TorusMesh.new(); ring.rings = 16; ring.ring_segments = 8
		ring.inner_radius = 0.44; ring.outer_radius = 0.52
		var ringcol := TRIM_COL if c.z < 0.0 else CYAN_COL
		_add(root, ring, _mat(ringcol, 0.3, 0.3, ringcol, 2.6), c + Vector3(0.0, 0.16, 0.0))
		# spinning rotor: a pivot with two crossed translucent blades
		var pivot := Node3D.new(); pivot.position = c + Vector3(0.0, 0.18, 0.0)
		root.add_child(pivot)
		for a in [0.0, 90.0]:
			var blade := BoxMesh.new(); blade.size = Vector3(0.92, 0.015, 0.10)
			_add(pivot, blade, blade_mat, Vector3.ZERO, Vector3(0.0, a, 0.0))
		_rotors.append(pivot)

	# nav LEDs — front pair green, rear pair red (classic drone tell)
	var green := _mat(Color.BLACK, 0.1, 0.1, Color(0.2, 1.0, 0.45), 3.0)
	var red := _mat(Color.BLACK, 0.1, 0.1, Color(1.0, 0.3, 0.32), 3.0)
	for c: Vector3 in corners:
		var led := SphereMesh.new(); led.radial_segments = 6; led.rings = 3
		led.radius = 0.05
		_add(root, led, green if c.z < 0.0 else red, c + Vector3(0.0, -0.02, 0.0))

	root.rotation_degrees = Vector3(12.0, -22.0, 0.0)   # pleasing 3/4 rest pose

func _animate() -> void:
	var slow := Fx.reduce_motion if has_node("/root/Fx") else false
	# body: continuous slow yaw + gentle hover bob
	var spin := _root.create_tween().set_loops()
	spin.tween_property(_root, "rotation:y", deg_to_rad(-22.0) + TAU, 12.0 if slow else 8.0).from(deg_to_rad(-22.0))
	if not slow:
		var bob := _root.create_tween().set_loops()
		bob.tween_property(_root, "position:y", 0.12, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(_root, "position:y", -0.12, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# rotors: fast continuous spin (blur-like)
	for pivot: Node3D in _rotors:
		var rt := pivot.create_tween().set_loops()
		rt.tween_property(pivot, "rotation:y", TAU, 0.4 if slow else 0.14).from(0.0)
