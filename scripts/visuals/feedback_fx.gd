class_name FeedbackFX
extends RefCounted
## Lightweight visual and procedural audio feedback helpers for block placement,
## recoloring, and removal.


static func play_place_tween(node: Node3D) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	node.scale = Vector3(1.2, 0.75, 1.2)
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector3.ONE, 0.15)


static func play_paint_tween(node: Node3D) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	node.scale = Vector3(1.12, 1.12, 1.12)
	var tween := node.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector3.ONE, 0.12)


static func spawn_burst(parent: Node3D, pos: Vector3, color: Color, is_erase: bool) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return

	var particles := CPUParticles3D.new()
	particles.name = "FeedbackBurst"
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 8
	particles.lifetime = 0.35
	particles.direction = Vector3.UP
	particles.spread = 110.0 if is_erase else 75.0
	particles.gravity = Vector3(0.0, -7.5 if is_erase else -5.0, 0.0)
	particles.initial_velocity_min = 1.6
	particles.initial_velocity_max = 3.2 if is_erase else 2.8
	particles.scale_amount_min = 0.65
	particles.scale_amount_max = 1.1

	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.1, 0.1, 0.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	box_mesh.material = mat
	particles.mesh = box_mesh

	particles.position = pos
	particles.finished.connect(particles.queue_free)
	parent.add_child(particles)
	particles.emitting = true


static func play_sfx(type: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return

	var start_freq: float = 220.0
	var end_freq: float = 520.0
	var duration_sec: float = 0.06
	var amplitude: float = 0.22

	match type:
		"place":
			start_freq = 220.0
			end_freq = 520.0
			duration_sec = 0.06
		"paint":
			start_freq = 660.0
			end_freq = 660.0
			duration_sec = 0.045
		"erase":
			start_freq = 300.0
			end_freq = 110.0
			duration_sec = 0.07
		_:
			return

	var pitch_jitter: float = randf_range(0.95, 1.05)
	start_freq *= pitch_jitter
	end_freq *= pitch_jitter

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = 44100.0
	generator.buffer_length = 0.1

	var player := AudioStreamPlayer.new()
	player.name = "FeedbackSFX"
	player.stream = generator
	tree.root.add_child(player)
	player.play()

	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		var sample_rate: float = generator.mix_rate
		var frame_count: int = int(round(duration_sec * sample_rate))
		var frames := PackedVector2Array()
		frames.resize(frame_count)
		var phase: float = 0.0
		var attack_frames: int = maxi(int(round(0.005 * sample_rate)), 1)

		for i in range(frame_count):
			var t: float = float(i) / float(maxi(frame_count - 1, 1))
			var freq: float = lerpf(start_freq, end_freq, t)
			phase += TAU * freq / sample_rate
			var env: float = 1.0 - t
			if i < attack_frames:
				env *= float(i) / float(attack_frames)
			var sample: float = sin(phase) * amplitude * env
			frames[i] = Vector2(sample, sample)

		playback.push_buffer(frames)

	var cleanup_timer := tree.create_timer(0.15)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.queue_free()
	)
