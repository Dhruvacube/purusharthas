extends Node

## The Kathakaar (Storyteller) System
## Observes the Purushartha axes and game events to deliver
## philosophical context and commentary.

var _last_commentary_year: int = 0
var _commentary_cooldown: int = 2 # Years between random commentaries
var _audio_player: AudioStreamPlayer

const VOICEOVER_PATHS = {
	"start": "res://assets/audio/voice/kathakaar/vo_start.mp3",
	"warn_artha": "res://assets/audio/voice/kathakaar/vo_warn_artha.mp3",
	"warn_moksha": "res://assets/audio/voice/kathakaar/vo_warn_moksha.mp3",
	"warn_kama": "res://assets/audio/voice/kathakaar/vo_warn_kama.mp3",
	"warn_dharma": "res://assets/audio/voice/kathakaar/vo_warn_dharma.mp3",
	"victory": "res://assets/audio/voice/kathakaar/vo_victory.mp3"
}

func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "Voice"
	add_child(_audio_player)
	
	EventBus.game_started.connect(_on_game_started)
	EventBus.year_changed.connect(_on_year_changed)

func _play_vo(key: String) -> void:
	var path = VOICEOVER_PATHS.get(key, "")
	if path != "" and ResourceLoader.exists(path):
		_audio_player.stream = load(path) as AudioStream
		_audio_player.play()

func _on_game_started() -> void:
	EventBus.notification.emit("The Kathakaar Speaks", "A new era begins. Balance the four aims of life, O Raja, lest the kingdom fall into ruin.", "positive")
	_play_vo("start")
	_last_commentary_year = TurnManager.get_current_year()

func _on_year_changed(year: int) -> void:
	if year - _last_commentary_year >= _commentary_cooldown:
		_check_axis_imbalance()

func _check_axis_imbalance() -> void:
	var dharma := GlobalState.get_axis("dharma")
	var artha := GlobalState.get_axis("artha")
	var kama := GlobalState.get_axis("kama")
	var moksha := GlobalState.get_axis("moksha")

	var message := ""
	var title := "The Kathakaar Observes"
	var severity := "info"
	var vo_key := ""

	if artha > 80 and dharma < 40:
		message = "Wealth without righteousness is a poison. The treasury overflows, but the people whisper of tyranny."
		severity = "warning"
		vo_key = "warn_artha"
	elif moksha > 80 and artha < 40:
		message = "Your people gaze at the heavens while the granaries empty. Asceticism cannot feed an army."
		severity = "warning"
		vo_key = "warn_moksha"
	elif kama < 30:
		message = "A kingdom without joy is a prison. The arts wither and the spirit of the people grows cold."
		severity = "warning"
		vo_key = "warn_kama"
	elif dharma > 80 and kama < 40:
		message = "Rigid duty has stifled innovation. Tradition must not become a chain that binds the soul."
		severity = "warning"
		vo_key = "warn_dharma"
	elif dharma > 70 and artha > 70 and kama > 70 and moksha > 70:
		message = "A golden age is upon us! The four pillars of life stand strong and balanced."
		severity = "positive"
		title = "The Kathakaar Rejoices"
		vo_key = "victory"

	if not message.is_empty():
		EventBus.notification.emit(title, message, severity)
		_play_vo(vo_key)
		_last_commentary_year = TurnManager.get_current_year()
