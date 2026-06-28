extends Node

## Manages game audio, including music transitions between layers.

var _music_players: Dictionary = {}
var _ambience_players: Dictionary = {}
var _current_layer: int = -1

const MUSIC_PATHS = {
	0: "res://assets/audio/music/layer0_village.mp3",
	1: "res://assets/audio/music/layer1_governance.mp3",
	2: "res://assets/audio/music/layer2_civilisation.mp3",
	3: "res://assets/audio/music/layer3_pilgrim.mp3"
}

const AMBIENCE_PATHS = {
	0: "res://assets/audio/ambience/layer0_village_ambience.mp3",
	1: "res://assets/audio/ambience/layer1_governance_ambience.mp3",
	2: "res://assets/audio/ambience/layer2_civilisation_ambience.mp3",
	3: "res://assets/audio/ambience/layer3_pilgrim_ambience.mp3"
}

func _ready() -> void:
	for layer_idx in range(4):
		# Setup Music
		var music_player = AudioStreamPlayer.new()
		music_player.bus = "Music"
		music_player.volume_db = -80.0
		var m_path = MUSIC_PATHS.get(layer_idx, "")
		if m_path != "" and ResourceLoader.exists(m_path):
			music_player.stream = load(m_path) as AudioStream
		add_child(music_player)
		_music_players[layer_idx] = music_player
		
		# Setup Ambience
		var amb_player = AudioStreamPlayer.new()
		amb_player.bus = "SFX" # Or a dedicated Ambience bus
		amb_player.volume_db = -80.0
		var a_path = AMBIENCE_PATHS.get(layer_idx, "")
		if a_path != "" and ResourceLoader.exists(a_path):
			amb_player.stream = load(a_path) as AudioStream
		add_child(amb_player)
		_ambience_players[layer_idx] = amb_player

	EventBus.layer_switched.connect(_on_layer_switched)

func _on_layer_switched(_from_layer: String, to_layer: String) -> void:
	var to_idx: int = -1
	match to_layer:
		"Village", "Layer.VILLAGE", "0": to_idx = 0
		"Governance", "Layer.GOVERNANCE", "1": to_idx = 1
		"Civilisation", "Layer.CIVILISATION", "2": to_idx = 2
		"Pilgrim", "Layer.PILGRIM", "3": to_idx = 3

	if to_idx == -1 or to_idx == _current_layer:
		return

	print("AudioManager: Crossfading music and ambience to layer %d (%s)" % [to_idx, to_layer])

	# Fade out old
	if _current_layer != -1:
		if _music_players.has(_current_layer):
			var old_player: AudioStreamPlayer = _music_players[_current_layer]
			var tween_out = create_tween()
			tween_out.tween_property(old_player, "volume_db", -80.0, 1.5)
			tween_out.tween_callback(old_player.stop)
		if _ambience_players.has(_current_layer):
			var old_amb: AudioStreamPlayer = _ambience_players[_current_layer]
			var tween_out_amb = create_tween()
			tween_out_amb.tween_property(old_amb, "volume_db", -80.0, 1.5)
			tween_out_amb.tween_callback(old_amb.stop)

	# Fade in new
	if _music_players.has(to_idx):
		var new_player: AudioStreamPlayer = _music_players[to_idx]
		if new_player.stream != null:
			new_player.play()
			var tween_in = create_tween()
			tween_in.tween_property(new_player, "volume_db", 0.0, 1.5)

	if _ambience_players.has(to_idx):
		var new_amb: AudioStreamPlayer = _ambience_players[to_idx]
		if new_amb.stream != null:
			new_amb.play()
			var tween_in_amb = create_tween()
			# Ambience should be slightly quieter than music
			tween_in_amb.tween_property(new_amb, "volume_db", -10.0, 1.5)
	
	_current_layer = to_idx
