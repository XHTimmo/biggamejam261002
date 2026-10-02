extends SceneTree

const MAIN_SCENE := preload("res://main.tscn")
const BOSS_SCRIPT := preload("res://scripts/enemies/alchemy_iron_golem.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	await _frames(8)
	var boss := world.get_node("Zone2/AlchemyIronGolem_2A")
	var gate := world.get_node("Zone2/ExitGate")
	var audio: Node = world.audio
	var warnings: Array[String] = []
	boss.phase_warning.connect(func(element: String, hint: String):
		warnings.append(element + ":" + hint)
	)
	_expect(audio.music_player.stream == audio.background_music and audio.background_music.loop, "Exploration music is missing or does not loop")
	# Exercise playback positions through the headless dummy audio driver too.
	audio.audio_enabled = true
	audio.music_player.play(12.0)
	_expect(boss is BOSS_SCRIPT, "Finale did not spawn the alchemy iron golem")
	_expect(boss.health == 600.0 and boss.current_element == "iron", "Boss initial profile is incorrect")
	_expect(world.zone_enemy_remaining[2] == 6 and not gate.is_open, "Boss or closed exit gate is missing from finale count")
	for child in world.get_node("Zone2").get_children():
		if child != boss and child.is_in_group("enemies"):
			_expect(child.global_position.x < boss.global_position.x, "A regular enemy is positioned after the final boss")
	boss.phase_time = 0.99
	boss._physics_process(0.0)
	_expect(not warnings.is_empty(), "Boss phase warning did not provide a damage hint")
	boss.take_element_damage(10.0, "hydrogen")
	_expect(audio.music_player.stream == audio.boss_music and audio.boss_music.loop and audio.music_player.playing, "Damaging the boss did not start looping boss music")
	_expect(audio.background_music_position >= 11.9, "Exploration playback position was not saved")
	var saved_position: float = audio.background_music_position
	audio.music_player.seek(8.0)
	boss._begin_attack(world.player)
	_expect(audio.music_player.get_playback_position() >= 7.9 and audio.background_music_position == saved_position, "Repeated boss attacks restarted music or lost the saved position")
	world._show_modal("pause")
	await _frames(3)
	_expect(audio.music_player.can_process() and audio.music_player.playing, "Boss music stopped during pause")
	world._close_modal()
	_expect(is_equal_approx(boss.health, 586.5), "Boss iron-state hydrogen weakness is incorrect")
	var previous: String = boss.current_element
	for _index in range(8):
		boss._switch_element()
		_expect(boss.current_element != previous, "Boss repeated the same element state")
		previous = boss.current_element
	boss._defeat()
	_expect(audio.music_player.stream == audio.background_music and audio.music_player.playing, "Boss defeat did not restore exploration music immediately")
	_expect(audio.music_player.get_playback_position() >= saved_position - 0.1, "Exploration music restarted instead of resuming")
	for child in world.get_node("Zone2").get_children():
		if child != boss and child.is_in_group("enemies") and child.has_method("_defeat"):
			child.call("_defeat")
	await _frames(70)
	_expect(world.objectives[2] and world.boss_defeated and gate.is_open, "Boss defeat did not unlock the final exit")
	world.active_checkpoint = 2
	world._restore_checkpoint()
	boss = world.get_node("Zone2/AlchemyIronGolem_2A")
	boss._begin_attack(world.player)
	_expect(audio.boss_music_active, "Respawned boss attack did not start boss music")
	world._restore_checkpoint()
	_expect(audio.music_player.stream == audio.background_music, "Checkpoint restore left boss music playing")
	boss = world.get_node("Zone2/AlchemyIronGolem_2A")
	boss._begin_attack(world.player)
	_expect(audio.boss_music_active, "Retry did not restart boss music")
	world._restart_demo()
	_expect(audio.music_player.stream == audio.background_music and not audio.boss_music_active, "Full restart left boss music playing")
	world.free()
	await process_frame
	# The audio mixer needs wall-clock time even when fixed-fps tests run faster.
	OS.delay_msec(100)
	if failures.is_empty():
		print("PASS: boss profile, elements, exit gate, music attack/damage triggers, pause, playback resume, checkpoint retry and restart")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
