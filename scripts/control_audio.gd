extends Node
## One bounded pool for mechanical feedback, with separate persistent device streams.
signal played(sound_id: String)
var streams: Dictionary = {}
var levels: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var loops: Dictionary = {}
var next_voice: int = 0
var cooldowns: Dictionary = {}

func _ready() -> void:
	# A running playtest remains usable while the parallel audio build writes its assets.
	var data: Dictionary = {}
	var manifest_path: String = "res://audio/controls".path_join("manifest.json")
	if FileAccess.file_exists(manifest_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if parsed is Dictionary:
			data = parsed as Dictionary
	# The generated manifest also serves as a reproducible audio-quality report.
	var entries: Variant = data.get("sounds", data.get("files", {}))
	if entries is Array:
		for entry: Dictionary in entries:
			_load_sound(str(entry.get("id", entry.get("name", ""))), entry)
	else:
		for sound_id: String in entries:
			_load_sound(sound_id, entries[sound_id])
	for index: int in range(8):
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = "Feedback_%d" % index
		add_child(voice)
		voices.append(voice)
	for channel: String in ["radio_station", "radio_noise", "tape"]:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = channel
		add_child(player)
		loops[channel] = player

func _load_sound(sound_id: String, entry: Dictionary) -> void:
	if sound_id.is_empty():
		return
	var path: String = str(entry.get("file", entry.get("path", sound_id + ".wav")))
	if not path.begins_with("res://"):
		path = "res://audio/controls/" + path.get_file()
	var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
	if bool(entry.get("loop", false)):
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() >> (2 if stream.stereo else 1)
	streams[sound_id] = stream
	levels[sound_id] = float(entry.get("suggested_volume_db", -10.0))

func play_sound(sound_id: String, pitch: float = 1.0, gain_db: float = 0.0, cooldown: float = 0.0) -> void:
	if not streams.has(sound_id) or voices.is_empty():
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - float(cooldowns.get(sound_id, -100.0)) < cooldown:
		return
	cooldowns[sound_id] = now
	var voice: AudioStreamPlayer = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stop()
	voice.stream = streams[sound_id]
	voice.pitch_scale = clampf(pitch, 0.5, 2.0)
	voice.volume_db = float(levels[sound_id]) + gain_db
	voice.play()
	played.emit(sound_id)

func _loop(channel: String, sound_id: String, gain_db: float, pitch: float = 1.0) -> void:
	if not streams.has(sound_id):
		return
	var player: AudioStreamPlayer = loops[channel]
	var changed: bool = player.stream != streams[sound_id]
	var resume_paused: bool = player.stream_paused and not changed
	if changed:
		player.stop()
		player.stream = streams[sound_id]
	player.volume_db = float(levels[sound_id]) + gain_db
	player.pitch_scale = pitch
	if resume_paused:
		player.stream_paused = false
	if not player.playing and not resume_paused:
		player.play()
		played.emit(sound_id)

func set_radio(powered: bool, volume: float, tuning: float) -> void:
	if not powered or volume <= 0.001:
		(loops["radio_station"] as AudioStreamPlayer).stop()
		(loops["radio_noise"] as AudioStreamPlayer).stop()
		return
	var distance: float = 1.0
	for station: float in [0.18, 0.50, 0.82]:
		distance = minf(distance, absf(tuning - station))
	var signal_strength: float = clampf(1.0 - distance / 0.13, 0.0, 1.0)
	var volume_db: float = linear_to_db(maxf(volume, 0.001))
	_loop("radio_station", "radio_station", volume_db + linear_to_db(maxf(signal_strength, 0.001)), lerpf(0.94, 1.06, tuning))
	_loop("radio_noise", "radio_tune", volume_db + linear_to_db(lerpf(1.0, 0.035, signal_strength)))

func set_tape(mode: String, level: float) -> void:
	var player: AudioStreamPlayer = loops["tape"]
	player.set_meta("mode", mode)
	if mode == "pause":
		player.stream_paused = true
		return
	if mode == "stop":
		player.stop()
		player.stream_paused = false
		return
	var sound_id: String = "tape_rewind" if mode == "rewind" else "tape_play"
	# Record is a demonstration monitor signal; it never requests the microphone.
	var volume_db: float = linear_to_db(maxf(level, 0.001))
	_loop("tape", sound_id, volume_db, 0.98 if mode == "record" else 1.0)
	player.stream_paused = level <= 0.001

func stop_all() -> void:
	for player: AudioStreamPlayer in voices:
		player.stop()
	for player: AudioStreamPlayer in loops.values():
		player.stop()
