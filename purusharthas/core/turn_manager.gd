## TurnManager — Unified global timeline for all four gameplay layers.
##
## Tracks seasons (Village), years (Pilgrim), decades (Governance), and eras
## (Civilisation) on a single year counter starting at a configurable BCE year.
## Registered as the "TurnManager" autoload.
class_name TurnManagerClass
extends Node


#region Enums
enum Season {
	KHARIF,  ## Monsoon / summer-sown crop season
	RABI,    ## Winter-sown crop season
	ZAID,    ## Short summer crop season
}
#endregion


#region Constants
const SEASON_DISPLAY_NAMES: Dictionary = {
	Season.KHARIF: "Kharif",
	Season.RABI: "Rabi",
	Season.ZAID: "Zaid",
}

const SEASONS_PER_YEAR: int = 3
const YEARS_PER_DECADE: int = 10
const YEARS_PER_ERA: int = 25
const PANCHAYAT_INTERVAL: int = 4  ## Panchayat year every 4th year
#endregion


#region State
## The absolute year value.  Negative values represent BCE, positive represent CE.
## Default: -321 (i.e., 321 BCE — Maurya era).
var _start_year: int = -321
var _current_year: int = -321
var _current_season: Season = Season.KHARIF
var _seasons_elapsed: int = 0
var _paused: bool = false
#endregion


#region Public API — Queries

## Return the current season enum value.
func get_current_season() -> int:
	return _current_season


## Return a human-readable season name.
func get_current_season_name() -> String:
	return SEASON_DISPLAY_NAMES.get(_current_season, "Unknown") as String


## Return the internal year value (negative = BCE).
func get_current_year() -> int:
	return _current_year


## Return a display-friendly year string, e.g. "321 BCE" or "45 CE".
func get_current_year_display() -> String:
	if _current_year <= 0:
		# Year 0 and negative are BCE; display as positive number.
		return "%d BCE" % absi(_current_year)
	else:
		return "%d CE" % _current_year


## The decade number (0-based index from start year).
func get_current_decade() -> int:
	var years_from_start: int = _current_year - _start_year
	@warning_ignore("integer_division")
	return years_from_start / YEARS_PER_DECADE


## The era number (0-based index from start year).
func get_current_era() -> int:
	var years_from_start: int = _current_year - _start_year
	@warning_ignore("integer_division")
	return years_from_start / YEARS_PER_ERA


## Total number of seasons advanced since the game began.
func get_seasons_elapsed() -> int:
	return _seasons_elapsed


## Returns true on Panchayat years (every [PANCHAYAT_INTERVAL]th year from start).
func is_panchayat_year() -> bool:
	var years_from_start: int = _current_year - _start_year
	if years_from_start <= 0:
		return false
	return years_from_start % PANCHAYAT_INTERVAL == 0

#endregion


#region Public API — Advance Time

## Advance the timeline by one season.
##
## After the final season (ZAID) the year increments and the season wraps to
## KHARIF.  Time-boundary signals are emitted through EventBus.
func advance_season() -> void:
	if _paused:
		return

	var old_decade: int = get_current_decade()
	var old_era: int = get_current_era()

	_seasons_elapsed += 1

	match _current_season:
		Season.KHARIF:
			_current_season = Season.RABI
		Season.RABI:
			_current_season = Season.ZAID
		Season.ZAID:
			_current_season = Season.KHARIF
			_advance_year()

	EventBus.season_changed.emit(get_current_season_name(), _current_year)

	# Check decade boundary
	if get_current_decade() != old_decade:
		EventBus.decade_changed.emit(get_current_decade(), _get_era_name())

	# Check era boundary
	if get_current_era() != old_era:
		EventBus.notification.emit(
			"New Era",
			"A new era begins in %s." % get_current_year_display(),
			"info",
		)

	# Tick modifiers every season
	GlobalState.tick_modifiers()

#endregion


#region Public API — Pause / Resume

## Pause the timeline.  advance_season() becomes a no-op while paused.
func pause() -> void:
	_paused = true


## Resume the timeline.
func resume() -> void:
	_paused = false


## Whether the timeline is currently paused.
func is_paused() -> bool:
	return _paused

#endregion


#region Serialisation

func to_save_data() -> Dictionary:
	return {
		"start_year": _start_year,
		"current_year": _current_year,
		"current_season": _current_season as int,
		"seasons_elapsed": _seasons_elapsed,
		"paused": _paused,
	}


func from_save_data(data: Dictionary) -> void:
	_start_year = int(data.get("start_year", -321))
	_current_year = int(data.get("current_year", _start_year))
	_current_season = int(data.get("current_season", Season.KHARIF)) as Season
	_seasons_elapsed = int(data.get("seasons_elapsed", 0))
	_paused = bool(data.get("paused", false))

#endregion


#region Internal

## Advance the year by one and emit year_changed.
func _advance_year() -> void:
	# Handle the BCE → CE transition: jump from year 0 to year 1 (no year 0).
	if _current_year == 0:
		_current_year = 1
	else:
		_current_year += 1

	EventBus.year_changed.emit(_current_year)


## Return a human-readable label for the current era based on the era index.
func _get_era_name() -> String:
	var era_index: int = get_current_era()
	# Era names loosely follow Indian historical periods from the Maurya start.
	var era_names: PackedStringArray = PackedStringArray([
		"Maurya Era",
		"Post-Maurya Era",
		"Shunga-Kanva Era",
		"Early Satavahana Era",
		"Late Satavahana Era",
		"Kushan Era",
		"Gupta Era",
		"Post-Gupta Era",
		"Early Medieval Era",
		"Chola Era",
		"Sultanate Era",
		"Mughal Era",
	])
	if era_index >= 0 and era_index < era_names.size():
		return era_names[era_index]
	return "Era %d" % era_index

#endregion
