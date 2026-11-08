extends Node
## One-shot playback, separate from focus and camera movement.
var success: AudioStreamPlayer
var startup: AudioStreamPlayer
var pending_start: float = -1.0

func _ready() -> void:
	success = AudioStreamPlayer.new()
	success.name = "UnlockSuccess"
	success.stream = AudioStreamWAV.load_from_file("res://audio/unlock_success.wav")
	success.volume_db = -1.0
	add_child(success)
	startup = AudioStreamPlayer.new()
	startup.name = "RetroStartup"
	startup.stream = AudioStreamWAV.load_from_file("res://audio/retro_boot.wav")
	startup.volume_db = -3.0
	add_child(startup)

func play_unlock() -> void:
	stop_all()
	success.play()
	pending_start = 0.32

func stop_all() -> void:
	pending_start = -1.0
	if success != null:
		success.stop()
	if startup != null:
		startup.stop()

func _process(delta: float) -> void:
	if pending_start < 0:
		return
	pending_start -= delta
	if pending_start <= 0:
		pending_start = -1.0
		startup.play()
