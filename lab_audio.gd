extends Node

const BACKGROUND_MUSIC = preload("res://music/旧舱新发现.mp3")

var music_player: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var bank := {}
var voice_index := 0

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.volume_db = -12.0
	var music := BACKGROUND_MUSIC.duplicate() as AudioStreamMP3
	music.loop = true
	music_player.stream = music
	add_child(music_player)
	music_player.play()
	for index in range(4):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -21
		add_child(voice)
		voices.append(voice)
	for key in ["jump", "spring", "checkpoint", "reaction", "pickup", "gate", "damage", "throw"]:
		bank[key] = _tone(key)

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
	if music_player:
		music_player.stop()
		music_player.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	bank.clear()

func _tone(key: String) -> AudioStreamWAV:
	var frequencies := {"jump": 420.0, "spring": 190.0, "checkpoint": 600.0, "reaction": 260.0, "pickup": 840.0, "gate": 150.0, "damage": 90.0, "throw": 330.0}
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
