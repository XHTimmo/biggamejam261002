extends Node

const BACKGROUND_MUSIC = preload("res://music/旧舱新发现.mp3")
const BOSS_MUSIC = preload("res://music/失控炼金舱.mp3")
const ELEMENTS = preload("res://scripts/shared/element_catalog.gd")
const SHOT_SOUNDS := {
	"hydrogen": [preload("res://assets/audio/weapons/hydrogen_normal.wav"), preload("res://assets/audio/weapons/hydrogen_charged.wav")],
	"oxygen": [preload("res://assets/audio/weapons/oxygen_normal.wav"), preload("res://assets/audio/weapons/oxygen_charged.wav")],
	"carbon": [preload("res://assets/audio/weapons/carbon_normal.wav"), preload("res://assets/audio/weapons/carbon_charged.wav")],
	"iron": [preload("res://assets/audio/weapons/iron_normal.wav"), preload("res://assets/audio/weapons/iron_charged.wav")],
}
const RELOAD_SOUNDS := [preload("res://assets/audio/weapons/gas_reload.wav"), preload("res://assets/audio/weapons/solid_reload.wav")]
const RELOAD_COMPLETE_SOUNDS := [preload("res://assets/audio/weapons/gas_reload_complete.wav"), preload("res://assets/audio/weapons/solid_reload_complete.wav")]

var music_player: AudioStreamPlayer
var background_music: AudioStreamMP3
var boss_music: AudioStreamMP3
var boss_music_active := false
var background_music_position := 0.0
var weapon_owner: CharacterBody2D
var shot_voices: Array[AudioStreamPlayer] = []
var shot_voice_index := 0
var reload_voice: AudioStreamPlayer
var reload_complete_voice: AudioStreamPlayer
var active_reload_element := -1
var audio_enabled := false
var voices: Array[AudioStreamPlayer] = []
var bank := {}
var voice_index := 0

func _ready() -> void:
	audio_enabled = DisplayServer.get_name() != "headless"
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.volume_db = -12.0
	background_music = BACKGROUND_MUSIC.duplicate() as AudioStreamMP3
	background_music.loop = true
	boss_music = BOSS_MUSIC.duplicate() as AudioStreamMP3
	boss_music.loop = true
	music_player.stream = background_music
	add_child(music_player)
	if audio_enabled:
		music_player.play()
	for index in range(4):
		var shot_voice := AudioStreamPlayer.new()
		shot_voice.name = "WeaponShot%d" % index
		shot_voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(shot_voice)
		shot_voices.append(shot_voice)
	reload_voice = AudioStreamPlayer.new()
	reload_voice.name = "ReloadMechanism"
	reload_voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	reload_voice.volume_db = -12.0
	add_child(reload_voice)
	reload_complete_voice = AudioStreamPlayer.new()
	reload_complete_voice.name = "ReloadLock"
	reload_complete_voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	reload_complete_voice.volume_db = -13.0
	add_child(reload_complete_voice)
	for index in range(4):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -21
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		voices.append(voice)
	for key in ["jump", "spring", "checkpoint", "reaction", "pickup", "gate", "damage", "dash", "throw"]:
		bank[key] = _tone(key)

func set_boss_music(active: bool) -> void:
	if boss_music_active == active:
		return
	if active and audio_enabled:
		background_music_position = music_player.get_playback_position()
	boss_music_active = active
	music_player.stop()
	music_player.stream = boss_music if active else background_music
	if audio_enabled:
		music_player.play(0.0 if active else background_music_position)

func set_weapon_owner(player: CharacterBody2D) -> void:
	weapon_owner = player

func _notification(what: int) -> void:
	if not reload_voice:
		return
	if what == NOTIFICATION_PAUSED:
		reload_voice.stream_paused = true
	elif what == NOTIFICATION_UNPAUSED:
		reload_voice.stream_paused = false

func play_shot(element: String, kind: String) -> void:
	if get_tree().paused or not SHOT_SOUNDS.has(element):
		return
	var voice := shot_voices[shot_voice_index]
	shot_voice_index = (shot_voice_index + 1) % shot_voices.size()
	voice.stream = SHOT_SOUNDS[element][1 if kind == "charged" else 0]
	voice.volume_db = (-12.0 if ELEMENTS.is_gas(element) else -10.0) + (1.0 if kind == "charged" else 0.0)
	if audio_enabled:
		voice.play()

func play_reload_complete(element: String) -> void:
	reload_voice.stop()
	active_reload_element = -1
	reload_complete_voice.stream = RELOAD_COMPLETE_SOUNDS[0 if ELEMENTS.is_gas(element) else 1]
	if audio_enabled:
		reload_complete_voice.play()

func _process(_delta: float) -> void:
	if get_tree().paused:
		reload_voice.stream_paused = true
		return
	reload_voice.stream_paused = false
	if not is_instance_valid(weapon_owner) or not weapon_owner.is_reloading():
		reload_voice.stop()
		active_reload_element = -1
		return
	var index: int = weapon_owner.selected_element
	var elapsed: float = ELEMENTS.RELOAD_SECONDS[index] - weapon_owner.reload_remaining[index]
	if active_reload_element != index or (audio_enabled and not reload_voice.playing):
		reload_voice.stop()
		reload_voice.stream = RELOAD_SOUNDS[0 if index < 2 else 1]
		if audio_enabled:
			reload_voice.play(elapsed)
		active_reload_element = index
	elif audio_enabled and absf(reload_voice.get_playback_position() - elapsed) > 0.12:
		# Keep mechanical clicks aligned when the frame rate changes.
		reload_voice.seek(elapsed)

func play_cue(key: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if voices.is_empty() or not bank.has(key):
		return
	var voice := voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = bank[key]
	voice.play()

func _exit_tree() -> void:
	for voice in shot_voices + [reload_voice, reload_complete_voice]:
		if voice:
			voice.stop()
			voice.stream = null
	if music_player:
		music_player.stop()
		music_player.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	bank.clear()

func _tone(key: String) -> AudioStreamWAV:
	var frequencies := {"jump": 420.0, "spring": 190.0, "checkpoint": 600.0, "reaction": 260.0, "pickup": 840.0, "gate": 150.0, "damage": 90.0, "dash": 760.0, "throw": 330.0}
	var duration := 0.22 if key != "checkpoint" else 0.4
	var count := int(22050 * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for sample in range(count):
		var time := float(sample) / count
		var frequency: float = frequencies[key] * (1.0 + time * (2.0 if key == "spring" else 0.25))
		phase += TAU * frequency / 22050
		var amplitude := sin(phase) * pow(1.0 - time, 2) * minf(time * 30, 1) * 18000
		data.encode_s16(sample * 2, int(amplitude))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream
