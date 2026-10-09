class_name Sound
extends Node
## Game sound: background music and the prototype's effects.
## Class is `Sound`, autoload is `Audio` on purpose — see docs/arquitetura/som.md.

## Background track. MP3 not WAV: see tools/gerar_audio.py.
const MUSIC: AudioStreamMP3 = preload("res://assets/audio/lastro_music.mp3")

## Seven sliced footstep samples, randomized to avoid a machine-gun cadence.
const FOOTSTEPS: Array[AudioStream] = [
	preload("res://assets/audio/footstep_1.wav"),
	preload("res://assets/audio/footstep_2.wav"),
	preload("res://assets/audio/footstep_3.wav"),
	preload("res://assets/audio/footstep_4.wav"),
	preload("res://assets/audio/footstep_5.wav"),
	preload("res://assets/audio/footstep_6.wav"),
	preload("res://assets/audio/footstep_7.wav"),
]

const HAMMER_HIT: AudioStream = preload("res://assets/audio/hammer_hit.wav")
const DOOR_OPENING: AudioStream = preload("res://assets/audio/door_opening.wav")
const DOOR_CLOSING: AudioStream = preload("res://assets/audio/door_closing.wav")

## Deliberately quiet background track; see docs/arquitetura/som.md for the dB math.
const MUSIC_VOLUME: float = -34.0

## Effect volumes, in dB — order matters, see docs/arquitetura/som.md.
const FOOTSTEP_VOLUME: float = -30.0
const HAMMER_HIT_VOLUME: float = -14.0
const DOOR_VOLUME: float = -30.0

## Footstep pitch variation (frequency multiplier).
const FOOTSTEP_PITCH_VARIATION: float = 1.08

## Footstep volume variation, in dB either way.
const FOOTSTEP_VOLUME_VARIATION: float = 2.0

## Hammer-hit pitch variation, so a single sample doesn't sound looped.
const HAMMER_HIT_PITCH_VARIATION: float = 1.06

## Max simultaneous plays of the same effect; avoids one cutting another off.
const CONCURRENT_PLAYS: int = 3

## Static players, filled by the `Audio` autoload's `_ready()`.
static var _music: AudioStreamPlayer
static var _footsteps: AudioStreamPlayer
static var _hammer_hits: AudioStreamPlayer
static var _doors: AudioStreamPlayer


## One foot on the ground; called from jogador.gd's walk contact frames.
static func footstep() -> void:
	if _is_ready():
		_footsteps.play()


## One pickaxe hit; called from the work sheet's impact frame.
static func hammer_hit() -> void:
	if _is_ready():
		_hammer_hits.play()


## Closing sound disabled as an experiment; flip to true to re-enable.
const PLAY_CLOSING: bool = false

## A door or gate changing state.
static func door(opening: bool) -> void:
	if not _is_ready():
		return
	if not opening and not PLAY_CLOSING:
		return
	_doors.stream = DOOR_OPENING if opening else DOOR_CLOSING
	_doors.play()


## False in --script tools runs before _ready() sets the players up.
static func _is_ready() -> bool:
	return _footsteps != null


## Headless has no audio device; skips setup to avoid a leak at exit (see docs/arquitetura/som.md).
static func _no_audio_output() -> bool:
	return DisplayServer.get_name() == "headless"


## Runs once on the `Audio` autoload's node.
func _ready() -> void:
	# Keeps playing through the pause menu instead of pausing with the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Loop is off by default on import; turned on here, not in .import, so it stays visible.
	if _no_audio_output():
		return

	var track: AudioStreamMP3 = MUSIC
	track.loop = true

	_music = _create_player(&"Music", track, MUSIC_VOLUME, 1)

	_footsteps = _create_player(&"Footsteps", _randomizer(FOOTSTEPS, FOOTSTEP_PITCH_VARIATION, FOOTSTEP_VOLUME_VARIATION), FOOTSTEP_VOLUME, CONCURRENT_PLAYS)
	_hammer_hits = _create_player(&"HammerHits", _randomizer([HAMMER_HIT], HAMMER_HIT_PITCH_VARIATION, 0.0), HAMMER_HIT_VOLUME, CONCURRENT_PLAYS)
	_doors = _create_player(&"Doors", null, DOOR_VOLUME, CONCURRENT_PLAYS)

	_music.play()


## Releases static refs so they don't outlive the tree that created them.
func _exit_tree() -> void:
	_music = null
	_footsteps = null
	_hammer_hits = null
	_doors = null


## Builds one player with shared settings (Master bus, explicit polyphony).
func _create_player(player_name: StringName, stream: AudioStream, volume: float, concurrent: int) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume
	player.max_polyphony = concurrent
	add_child(player)
	return player


## Wraps samples in a randomizer with pitch/volume deviation.
func _randomizer(samples: Array, pitch: float, volume: float) -> AudioStreamRandomizer:
	var randomizer := AudioStreamRandomizer.new()
	randomizer.random_pitch = pitch
	randomizer.random_volume_offset_db = volume
	for i: int in samples.size():
		randomizer.add_stream(i, samples[i])
	return randomizer
