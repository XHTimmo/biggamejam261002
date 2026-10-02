extends SceneTree

const MAIN = preload("res://main.tscn")
var world: Node2D
var player: CharacterBody2D
var failures: Array[String] = []
var fired := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = MAIN.instantiate()
	root.add_child(world)
	player = world.player
	player.weapon_fired.connect(func(_element, _kind): fired += 1)
	await _frames(30)
	var audio: Node = world.audio
	for index in range(4):
		player.select_element(index)
		player.reset_combat()
		var element: String = player.ELEMENTS.IDS[index]
		var before := fired
		await _tap("oxygen_normal")
		_expect(fired == before + 1, "Normal attack did not emit one sound")
		_expect(_last_shot(audio).stream.resource_path.ends_with(element + "_normal.wav"), "Wrong normal sound")
		_expect(not audio.audio_enabled or _last_shot(audio).playing, "Normal sound did not start playback")
		Input.action_press("oxygen_skill2")
		await _frames(10)
		Input.action_release("oxygen_skill2")
		await _frames(2)
		_expect(_last_shot(audio).stream.resource_path.ends_with(element + "_charged.wav"), "Wrong charged sound")
		for action in ["oxygen_skill", "oxygen_ultimate"]:
			player.reset_combat()
			before = fired
			await _tap(action)
			_expect(fired == before + 1, "Volley sound played once per pellet or was missing")
		player.reset_combat()
		player.magazine_ammo[index] = 1
		await _tap("oxygen_normal")
		var family := "gas" if index < 2 else "solid"
		_expect(player.is_reloading() and audio.active_reload_element == index, "Reload audio did not track empty magazine")
		_expect(not audio.audio_enabled or audio.reload_voice.playing, "Reload sound did not start playback")
		_expect(audio.reload_voice.stream.resource_path.ends_with(family + "_reload.wav"), "Wrong reload mechanism sound")
		_expect(is_equal_approx(audio.reload_voice.stream.get_length(), player.ELEMENTS.RELOAD_SECONDS[index]), "Reload clip length does not match reload")
		before = fired
		await _tap("oxygen_normal")
		_expect(fired == before, "Blocked shot played a firing sound")
		world._show_modal("pause")
		await _frames(4)
		_expect(not audio.reload_voice.can_process() and (not audio.audio_enabled or audio.reload_voice.stream_paused), "Reload audio did not pause")
		_expect(audio.music_player.can_process(), "Background music was paused with reload effects")
		world._close_modal()
		await _frames(2)
		_expect(not audio.reload_voice.stream_paused, "Reload audio did not resume")
		var remaining: float = player.reload_remaining[index]
		player.select_element((index + 1) % 4)
		await _frames(3)
		_expect(audio.active_reload_element == -1 and not audio.reload_voice.playing, "Stowed reload kept making sound")
		_expect(player.reload_remaining[index] == remaining, "Stowed reload progress changed")
		player.select_element(index)
		await _frames(2)
		_expect(audio.active_reload_element == index, "Returning weapon did not resume reload sound")
		await _frames(int(ceil(player.reload_remaining[index] * 60)) + 3)
		_expect(audio.active_reload_element == -1 and not audio.reload_voice.playing, "Reload sound did not stop on completion")
		_expect(audio.reload_complete_voice.stream.resource_path.ends_with(family + "_reload_complete.wav"), "Completion lock sound missing")
		for projectile in get_nodes_in_group("projectiles"):
			projectile.queue_free()
		await _frames(2)
	var realtime_audio: bool = audio.audio_enabled
	world.free()
	await process_frame
	if realtime_audio:
		# Allow the mixer thread to release stopped playback resources.
		await create_timer(0.1).timeout
	if failures.is_empty():
		print("PASS: four normal/charged sound routes, one sound per volley, blocked shots silent, reload clip timing/pause/switch/resume and completion lock")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _last_shot(audio: Node) -> AudioStreamPlayer:
	return audio.shot_voices[posmod(audio.shot_voice_index - 1, audio.shot_voices.size())]

func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)

func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
