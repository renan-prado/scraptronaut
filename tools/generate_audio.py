# Prepares the game's audio from the raw files in inbox/reference/audio/.
#
#   assets/audio/lastro_music.mp3    216 s   background music, looped
#   assets/audio/footstep_1..7.wav   ~0.22 s  one step each, for variation
#   assets/audio/hammer_hit.wav      ~0.40 s  the pickaxe hit
#   assets/audio/door_opening.wav    ~0.43 s  automatic door opening
#   assets/audio/door_closing.wav    ~0.43 s  the SAME one, reversed
#
# WHY THIS GENERATOR EXISTS
#
# inbox/ is gitignored whole, so raw files in inbox/reference/audio/
# never enter a commit — the game would load audio the repo doesn't have.
# assets/ is versioned and is what the game reads. Copying by hand would
# hide the cuts the raw audio REQUIRES, which the sections below record.
#
# WHY WAV FOR EFFECTS, MP3 ONLY FOR MUSIC
#
# MP3 decoding returns a few ms of encoder-added silence — 70ms for the raw
# hammer-hit file. For a percussive sound tied to an animation frame, 70ms
# is audible delay. WAV has no such preamble and costs no per-play decode
# CPU, which is what a short effect fired several times a second wants.
#
# Music is MP3 for the opposite reason: 216s in WAV is ~76MB against 3.3 for
# MP3, and continuous-track decode latency doesn't matter. It's COPIED
# without reprocessing — re-exporting an already-compressed MP3 loses quality twice for nothing.
#
# WHY THE FOOTSTEP IS SLICED
#
# footstep.mp3 isn't one footstep: it's SEVEN, 0.54s apart, a recording of
# someone walking. Looping the whole file was the first idea and is wrong —
# animation cadence is driven by distance traveled (see WALK_STRIDE_PIXELS in
# scripts/player.gd), and at full speed the foot hits almost 4 times a
# second, over twice the recording's rate. Sliced, each contact frame fires
# ONE footstep, and the seven become variation in scripts/sound.gd's AudioStreamRandomizer.
#
# WHY THE FOOTSTEP WINDOW IS SHORT ON PURPOSE
#
# Each footstep decays to 2% of peak within 80-170ms, but the file leaves
# 0.54s of air after it. At the game's cadence — one footstep every 0.26s —
# keeping that air would overlap three samples at once. 0.22s covers every
# footstep's audible tail and ends before the next one.
#
# WHY THE DOOR CLOSING IS THE SAME SAMPLE REVERSED
#
# Requested, and a known sound-design trick: open-door.mp3's profile is a
# crescendo to a peak with a short drop-off, so reversed it becomes a smooth
# entry ending in a sharp hit — reading as a leaf meeting its frame. There's
# no closing recording, and reversing costs one line.
import os
import shutil
import subprocess
import wave

import numpy as np

INPUT = "inbox/reference/audio"
OUTPUT = "assets/audio"

## The music is only copied — see header. To swap the track, change this name
## and rerun: the game always reads MUSIC, never the raw file's name.
RAW_MUSIC = "scraptronaut-audio-2.mp3"
MUSIC = "lastro_music.mp3"

## Above this peak (fraction of full scale) a 10ms window counts as a footstep start.
FOOTSTEP_THRESHOLD: float = 0.06

## How much before the threshold crossing a slice starts, so the attack isn't decapitated.
BEFORE: float = 0.008

## Each footstep's window, and how much of its end is faded to avoid a click.
FOOTSTEP: float = 0.22
FOOTSTEP_FADE_OUT: float = 0.03

## Hammer hit: how much to keep after the attack.
HAMMER_HIT: float = 0.40
HAMMER_HIT_FADE_OUT: float = 0.06

## Below this is edge silence, and gets trimmed. Lower than FOOTSTEP_THRESHOLD
## on purpose: this isn't looking for an attack, just where the file actually starts.
SILENCE_THRESHOLD: float = 0.0015

## How much to advance the start of door_opening.wav/door_closing.wav, BEYOND
## the silence trim above. open-door.mp3 has ~0.4s of quiet breath before the
## real door hit, and the game swaps the door's art on the SAME frame it
## triggers the sound (no animation — see _paint_door in station_map.gd), so
## that whole breath played before the hit landed, making the door look like
## it opened with delayed sound. 0.15s eats part of the breath without
## reaching the hit (~0.38s in). Zero reverts to the silence-only trim.
ADVANCE_DOOR: float = 0.15

## Short fade-in on every trimmed sample, so starting on a nonzero sample doesn't click.
SHORT_FADE_IN: float = 0.002


def _read(path: str) -> tuple:
	"""Decodes an audio file into (samples, rate, channels).

	Samples come out as float -1..1, shaped (frames, channels). Decoding goes
	through ffmpeg since no installed Python library here reads MP3, and it's
	already on PATH.
	"""
	probe = subprocess.run(
		[
			"ffprobe", "-v", "error",
			"-select_streams", "a:0",
			"-show_entries", "stream=sample_rate,channels",
			"-of", "csv=p=0",
			path,
		],
		capture_output=True, text=True, check=True,
	)
	rate_text, channels_text = probe.stdout.strip().split(",")[:2]
	rate = int(rate_text)
	channels = int(channels_text)

	raw = subprocess.run(
		["ffmpeg", "-v", "error", "-i", path, "-f", "s16le", "-acodec", "pcm_s16le", "-"],
		capture_output=True, check=True,
	).stdout
	samples = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
	return samples.reshape(-1, channels), rate, channels


def _write(name: str, data: np.ndarray, rate: int) -> None:
	"""Writes a 16-bit WAV. Godot imports this with no conversion."""
	ints = np.round(np.clip(data, -1.0, 1.0) * 32767.0).astype("<i2")
	path = os.path.join(OUTPUT, name)
	with wave.open(path, "wb") as file:
		file.setnchannels(data.shape[1])
		file.setsampwidth(2)
		file.setframerate(rate)
		file.writeframes(ints.tobytes())
	print("generated: %s/%s (%.3f s, %d channels, %d Hz)" % (
		OUTPUT, name, len(data) / rate, data.shape[1], rate
	))


def _envelope(data: np.ndarray, rate: int, window: float) -> np.ndarray:
	"""Absolute peak of each window, channels combined by the max."""
	width = max(1, int(rate * window))
	mono = np.max(np.abs(data), axis=1)
	leftover = len(mono) % width
	if leftover:
		mono = mono[:-leftover]
	return np.max(mono.reshape(-1, width), axis=1)


def _shape(data: np.ndarray, rate: int, fade_in: float, fade_out: float) -> np.ndarray:
	"""Linear fade in/out at the edges, so the slice doesn't click."""
	shaped = data.copy()
	n_in = min(len(shaped), int(rate * fade_in))
	if n_in > 1:
		shaped[:n_in] *= np.linspace(0.0, 1.0, n_in, dtype=np.float32)[:, None]
	n_out = min(len(shaped), int(rate * fade_out))
	if n_out > 1:
		shaped[-n_out:] *= np.linspace(1.0, 0.0, n_out, dtype=np.float32)[:, None]
	return shaped


def _first_sound(data: np.ndarray, threshold: float) -> int:
	"""First frame above `threshold`, or zero if the file is all silence."""
	above = np.nonzero(np.max(np.abs(data), axis=1) > threshold)[0]
	return int(above[0]) if len(above) else 0


def _last_sound(data: np.ndarray, threshold: float) -> int:
	above = np.nonzero(np.max(np.abs(data), axis=1) > threshold)[0]
	return int(above[-1]) + 1 if len(above) else len(data)


def _find_footsteps(data: np.ndarray, rate: int) -> list:
	"""Start frame of each footstep in the recording. Measured, not assumed."""
	window = 0.01
	envelope = _envelope(data, rate, window)
	starts: list = []
	playing = False
	for i, peak in enumerate(envelope):
		if peak > FOOTSTEP_THRESHOLD and not playing:
			starts.append(max(0, int((i * window - BEFORE) * rate)))
			playing = True
		elif peak < FOOTSTEP_THRESHOLD * 0.5 and playing:
			playing = False
	return starts


def generate_music() -> None:
	dest = os.path.join(OUTPUT, MUSIC)
	shutil.copyfile(os.path.join(INPUT, RAW_MUSIC), dest)
	print("copied: %s (%.1f MB)" % (dest, os.path.getsize(dest) / 1048576.0))


def generate_footsteps() -> None:
	data, rate, _ = _read(os.path.join(INPUT, "footstep.mp3"))
	length = int(rate * FOOTSTEP)
	for number, start in enumerate(_find_footsteps(data, rate), start=1):
		slice_ = data[start:start + length]
		_write("footstep_%d.wav" % number, _shape(slice_, rate, SHORT_FADE_IN, FOOTSTEP_FADE_OUT), rate)


def generate_hammer_hit() -> None:
	data, rate, _ = _read(os.path.join(INPUT, "metal-hammer-hit.mp3"))
	start = max(0, _first_sound(data, SILENCE_THRESHOLD) - int(rate * BEFORE))
	slice_ = data[start:start + int(rate * HAMMER_HIT)]
	_write("hammer_hit.wav", _shape(slice_, rate, SHORT_FADE_IN, HAMMER_HIT_FADE_OUT), rate)


def generate_door() -> None:
	data, rate, _ = _read(os.path.join(INPUT, "open-door.mp3"))
	end = _last_sound(data, SILENCE_THRESHOLD)
	start = _first_sound(data, SILENCE_THRESHOLD) + int(rate * ADVANCE_DOOR)
	trimmed = data[min(start, end):end]
	_write("door_opening.wav", _shape(trimmed, rate, SHORT_FADE_IN, FOOTSTEP_FADE_OUT), rate)
	# ::-1 reverses FRAMES, not channels: the stereo pair stays in place.
	_write("door_closing.wav", _shape(trimmed[::-1], rate, SHORT_FADE_IN, FOOTSTEP_FADE_OUT), rate)


def main() -> None:
	os.makedirs(OUTPUT, exist_ok=True)
	generate_music()
	generate_footsteps()
	generate_hammer_hit()
	generate_door()


if __name__ == "__main__":
	main()
