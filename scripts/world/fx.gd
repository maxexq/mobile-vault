class_name FX
extends RefCounted
## Particle factory. One config dictionary -> GPUParticles2D (default) or CPUParticles2D (low-end fallback).
## Godot docs recommend GPUParticles2D; CPU version is kept for very weak phones (Settings > Low FX).

static var use_gpu := true

## cfg keys: tex, amount, lifetime, dir(Vector2), spread, vmin, vmax, gravity(Vector2), box(Vector2 half-extents),
## smin, smax, color, fade(bool), damping, local(bool), preprocess, vis(Rect2), explosiveness, angle
static func particles(cfg: Dictionary) -> Node2D:
	return _gpu(cfg) if use_gpu else _cpu(cfg)


static func _ramp(cfg: Dictionary) -> Gradient:
	var g := Gradient.new()
	var c: Color = cfg.get("color", Color.WHITE)
	g.set_color(0, c)
	var end := c
	if cfg.get("fade", true):
		end.a = 0.0
	g.set_color(1, end)
	if cfg.get("fade_in", false):
		g.add_point(0.15, c)
		var start := c
		start.a = 0.0
		g.set_color(0, start)
	return g


static func _gpu(cfg: Dictionary) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	var m := ParticleProcessMaterial.new()
	var d: Vector2 = cfg.get("dir", Vector2.UP)
	m.direction = Vector3(d.x, d.y, 0)
	m.spread = cfg.get("spread", 15.0)
	m.initial_velocity_min = cfg.get("vmin", 10.0)
	m.initial_velocity_max = cfg.get("vmax", 20.0)
	var gv: Vector2 = cfg.get("gravity", Vector2.ZERO)
	m.gravity = Vector3(gv.x, gv.y, 0)
	m.scale_min = cfg.get("smin", 1.0)
	m.scale_max = cfg.get("smax", 1.0)
	m.damping_min = cfg.get("damping", 0.0)
	m.damping_max = cfg.get("damping", 0.0)
	m.particle_flag_disable_z = true
	if cfg.has("angle"):
		m.angle_min = -float(cfg.angle)
		m.angle_max = float(cfg.angle)
	if cfg.has("box"):
		var b: Vector2 = cfg.box
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3(b.x, b.y, 0)
	var gt := GradientTexture1D.new()
	gt.gradient = _ramp(cfg)
	m.color_ramp = gt
	p.process_material = m
	p.texture = cfg.get("tex")
	p.amount = cfg.get("amount", 16)
	p.lifetime = cfg.get("lifetime", 1.0)
	p.local_coords = cfg.get("local", false)
	p.preprocess = cfg.get("preprocess", 0.0)
	p.explosiveness = cfg.get("explosiveness", 0.0)
	p.visibility_rect = cfg.get("vis", Rect2(-2000, -2000, 4000, 4000))
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return p


static func _cpu(cfg: Dictionary) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.direction = cfg.get("dir", Vector2.UP)
	p.spread = cfg.get("spread", 15.0)
	p.initial_velocity_min = cfg.get("vmin", 10.0)
	p.initial_velocity_max = cfg.get("vmax", 20.0)
	p.gravity = cfg.get("gravity", Vector2.ZERO)
	p.scale_amount_min = cfg.get("smin", 1.0)
	p.scale_amount_max = cfg.get("smax", 1.0)
	p.damping_min = cfg.get("damping", 0.0)
	p.damping_max = cfg.get("damping", 0.0)
	if cfg.has("angle"):
		p.angle_min = -float(cfg.angle)
		p.angle_max = float(cfg.angle)
	if cfg.has("box"):
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = cfg.box
	p.color_ramp = _ramp(cfg)
	p.texture = cfg.get("tex")
	p.amount = int(cfg.get("amount", 16) * 0.6)
	p.lifetime = cfg.get("lifetime", 1.0)
	p.local_coords = cfg.get("local", false)
	p.preprocess = cfg.get("preprocess", 0.0)
	p.explosiveness = cfg.get("explosiveness", 0.0)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return p


static func set_box(p: Node2D, box: Vector2) -> void:
	if p is GPUParticles2D:
		(p.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(box.x, box.y, 0)
	elif p is CPUParticles2D:
		p.emission_rect_extents = box


static func set_dir(p: Node2D, dir: Vector2) -> void:
	if p is GPUParticles2D:
		(p.process_material as ParticleProcessMaterial).direction = Vector3(dir.x, dir.y, 0)
	elif p is CPUParticles2D:
		p.direction = dir
