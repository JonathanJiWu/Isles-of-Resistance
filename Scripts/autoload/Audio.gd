extends Node
## Procedurally synthesized sound effects and ambient music. No audio assets are required.

const RATE := 22050
const MUSIC_RATE := 16000
const POOL_SIZE := 16

var sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _music_task := -1
var _music_data := PackedFloat32Array()
var _noise := RandomNumberGenerator.new()


func _ready() -> void:
	_noise.seed = 1337
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -6.0
	add_child(_music)
	_build_sounds()
	_music_task = WorkerThreadPool.add_task(_generate_music)


func _process(_delta: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_music_stream = _to_wav(_music_data, MUSIC_RATE)
		_music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_music_stream.loop_begin = 0
		_music_stream.loop_end = _music_data.size()
		_music.stream = _music_stream
		_music.volume_db = -40.0
		_music.play()
		create_tween().tween_property(_music, "volume_db", -6.0, 4.0)
		set_process(false)


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


func play(sound_name: String, volume_db: float = 0.0, pitch_var: float = 0.06) -> void:
	if not sounds.has(sound_name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound_name, -1000)) < 35:
		return
	_last_played[sound_name] = now
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = sounds[sound_name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


# --------------------------------------------------------------------------------------------
# Synthesis helpers
# --------------------------------------------------------------------------------------------

func _to_wav(samples: PackedFloat32Array, rate: int = RATE) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b


func _normalize(b: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in b.size():
		b[i] *= k
	return b


func _fade_edges(b: PackedFloat32Array, fade_out: float = 0.02) -> void:
	var n := int(fade_out * RATE)
	for i in mini(n, b.size()):
		b[b.size() - 1 - i] *= float(i) / n


func _tone(b: PackedFloat32Array, start: float, freq: float, dur: float, amp: float, decay: float, harmonics: Array = [1.0]) -> void:
	var i0 := int(start * RATE)
	var n := mini(int(dur * RATE), b.size() - i0)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay) * minf(t * 400.0, 1.0)
		var v := 0.0
		for h in harmonics.size():
			v += sin(TAU * freq * (h + 1) * t) * harmonics[h]
		b[i0 + i] += v * env * amp


func _noise_burst(b: PackedFloat32Array, start: float, dur: float, amp: float, decay: float, lp: float) -> void:
	var i0 := int(start * RATE)
	var n := mini(int(dur * RATE), b.size() - i0)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += (randf_range(-1.0, 1.0) - y) * lp
		b[i0 + i] += y * exp(-t * decay) * amp


func _build_sounds() -> void:
	# UI
	var click := _buf(0.07)
	for i in click.size():
		var t := float(i) / RATE
		click[i] = sin(TAU * (1100.0 - 3000.0 * t) * t) * exp(-t * 55.0) * 0.5
	sounds["click"] = _to_wav(click)

	var hover := _buf(0.04)
	_tone(hover, 0.0, 1650.0, 0.04, 0.18, 90.0)
	sounds["hover"] = _to_wav(hover)

	var err := _buf(0.24)
	for i in err.size():
		var t := float(i) / RATE
		var on := (t < 0.08) or (t > 0.12 and t < 0.2)
		err[i] = (0.35 if sin(TAU * 150.0 * t) > 0.0 else -0.35) * (1.0 if on else 0.0) * 0.6
	_fade_edges(err)
	sounds["error"] = _to_wav(err)

	var build := _buf(0.45)
	_noise_burst(build, 0.0, 0.3, 0.8, 18.0, 0.08)
	_tone(build, 0.0, 85.0, 0.4, 0.7, 10.0)
	_tone(build, 0.05, 1240.0, 0.3, 0.18, 22.0, [1.0, 0.0, 0.4])
	_tone(build, 0.12, 1860.0, 0.25, 0.12, 25.0)
	sounds["build"] = _to_wav(_normalize(build, 0.7))

	var turn := _buf(0.8)
	_tone(turn, 0.0, 659.25, 0.7, 0.35, 5.0, [1.0, 0.25])
	_tone(turn, 0.13, 987.77, 0.65, 0.3, 5.0, [1.0, 0.25])
	sounds["turn"] = _to_wav(_normalize(turn, 0.55))

	var research := _buf(1.1)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for k in notes.size():
		_tone(research, k * 0.09, notes[k], 0.8, 0.28, 4.5, [1.0, 0.3, 0.1])
	sounds["research"] = _to_wav(_normalize(research, 0.55))

	var cleared := _buf(0.9)
	_tone(cleared, 0.0, 783.99, 0.8, 0.3, 4.0, [1.0, 0.3])
	_tone(cleared, 0.12, 1046.5, 0.75, 0.3, 4.0, [1.0, 0.3])
	_tone(cleared, 0.24, 1318.5, 0.6, 0.25, 4.0, [1.0, 0.3])
	sounds["cleared"] = _to_wav(_normalize(cleared, 0.5))

	# Weapons
	var flak := _buf(0.32)
	_noise_burst(flak, 0.0, 0.32, 1.0, 26.0, 0.35)
	_tone(flak, 0.0, 70.0, 0.3, 0.8, 18.0)
	sounds["flak"] = _to_wav(_normalize(flak, 0.55))

	var cannon := _buf(0.42)
	for k in 7:
		_noise_burst(cannon, k * 0.05, 0.06, 0.9, 70.0, 0.5)
		_tone(cannon, k * 0.05, 120.0, 0.05, 0.4, 60.0)
	sounds["cannon"] = _to_wav(_normalize(cannon, 0.45))

	var gun := _buf(0.3)
	for k in 5:
		_noise_burst(gun, k * 0.055, 0.05, 0.9, 80.0, 0.6)
	sounds["gun"] = _to_wav(_normalize(gun, 0.35))

	var sam := _buf(0.9)
	var y := 0.0
	for i in sam.size():
		var t := float(i) / RATE
		var cutoff := 0.04 + 0.4 * minf(t / 0.6, 1.0)
		y += (randf_range(-1.0, 1.0) - y) * cutoff
		var env := minf(t * 25.0, 1.0) * exp(-maxf(t - 0.15, 0.0) * 3.5)
		sam[i] = y * env + sin(TAU * (180.0 + 300.0 * t) * t) * 0.15 * env
	_fade_edges(sam, 0.1)
	sounds["sam"] = _to_wav(_normalize(sam, 0.5))

	var laser := _buf(0.38)
	var ph := 0.0
	for i in laser.size():
		var t := float(i) / RATE
		var f := 2400.0 * exp(-t * 7.0) + 280.0
		ph += TAU * f / RATE
		var s := sin(ph)
		laser[i] = (s * 0.7 + (0.3 if s > 0 else -0.3)) * exp(-t * 7.0) * minf(t * 300.0, 1.0)
	sounds["laser"] = _to_wav(_normalize(laser, 0.4))

	var rockets := _buf(0.5)
	for k in 3:
		_noise_burst(rockets, k * 0.08, 0.25, 0.8, 14.0, 0.25)
	sounds["rockets"] = _to_wav(_normalize(rockets, 0.45))

	var whistle := _buf(0.75)
	ph = 0.0
	for i in whistle.size():
		var t := float(i) / RATE
		ph += TAU * (1900.0 - 1500.0 * t / 0.75) / RATE
		whistle[i] = sin(ph) * minf(t * 10.0, 1.0) * minf((0.75 - t) * 10.0, 1.0) * 0.22
	sounds["whistle"] = _to_wav(whistle)

	sounds["explosion"] = _to_wav(_normalize(_explosion(1.1, 4.5, 50.0), 0.75))
	sounds["big_explosion"] = _to_wav(_normalize(_explosion(2.0, 2.4, 38.0), 0.85))

	var jet := _buf(1.6)
	y = 0.0
	ph = 0.0
	for i in jet.size():
		var t := float(i) / RATE
		var bell := exp(-pow((t - 0.6) / 0.35, 2.0))
		var cutoff := 0.05 + 0.35 * bell
		y += (randf_range(-1.0, 1.0) - y) * cutoff
		ph += TAU * (320.0 - 140.0 * t / 1.6) / RATE
		jet[i] = (y * 0.9 + sin(ph) * 0.12) * bell
	sounds["jet"] = _to_wav(_normalize(jet, 0.5))

	var alarm := _buf(2.0)
	ph = 0.0
	for i in alarm.size():
		var t := float(i) / RATE
		var f := 640.0 + 220.0 * (0.5 + 0.5 * sin(TAU * 1.6 * t))
		ph += TAU * f / RATE
		var tri := 2.0 / PI * asin(sin(ph))
		alarm[i] = tri * minf(t * 8.0, 1.0) * minf((2.0 - t) * 3.0, 1.0) * 0.3
	sounds["alarm"] = _to_wav(alarm)

	var victory := _buf(2.6)
	var fan := [[0.0, 523.25], [0.18, 659.25], [0.36, 783.99], [0.6, 1046.5]]
	for n in fan:
		_tone(victory, n[0], n[1], 2.0, 0.25, 1.6, [1.0, 0.5, 0.3, 0.15])
	_tone(victory, 0.6, 261.63, 2.0, 0.2, 1.2, [1.0, 0.4])
	sounds["victory"] = _to_wav(_normalize(victory, 0.6))

	var defeat := _buf(2.8)
	var dn := [[0.0, 440.0], [0.35, 349.23], [0.7, 293.66], [1.05, 220.0]]
	for n in dn:
		_tone(defeat, n[0], n[1], 1.7, 0.25, 1.5, [1.0, 0.45, 0.2])
	_tone(defeat, 1.05, 110.0, 1.7, 0.25, 1.2, [1.0, 0.3])
	sounds["defeat"] = _to_wav(_normalize(defeat, 0.6))


func _explosion(dur: float, decay: float, sub: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var y := 0.0
	var y2 := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var cutoff := 0.3 * exp(-t * 3.0) + 0.02
		y += (randf_range(-1.0, 1.0) - y) * cutoff
		y2 += (y - y2) * 0.2
		var crack := randf_range(-1.0, 1.0) * exp(-t * 70.0) * 0.6
		b[i] = y2 * 2.2 * exp(-t * decay) + sin(TAU * sub * t * (1.0 - t * 0.15)) * 0.6 * exp(-t * decay * 1.3) + crack
	_fade_edges(b, 0.05)
	return b


# --------------------------------------------------------------------------------------------
# Ambient music: a seamless 32-second loop of slow pads in D minor with a sparse arpeggio.
# Generated on a worker thread at startup.
# --------------------------------------------------------------------------------------------

func _generate_music() -> void:
	var rate := MUSIC_RATE
	var seg := 8.0
	var loop_len := seg * 4.0
	var n := int(loop_len * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	# Chords: Dm, Bb, F, C  (frequencies snapped to 1/32 Hz so the loop is phase-continuous)
	var chords := [
		[146.83, 174.61, 220.0, 293.66],
		[116.54, 174.61, 233.08, 293.66],
		[130.81, 174.61, 220.0, 261.63],
		[130.81, 164.81, 196.0, 261.63],
	]
	var roots := [73.42, 58.27, 87.31, 65.41]
	var fade := 2.5
	for ci in chords.size():
		var freqs: Array = []
		for f in chords[ci]:
			freqs.append(_snap(f, loop_len))
		var root := _snap(roots[ci], loop_len)
		var detune := 5.0 / loop_len
		for i in n:
			var t := float(i) / rate
			var local := fposmod(t - ci * seg + fade, loop_len)
			if local > seg + fade * 2.0:
				continue
			var env := 1.0
			if local < fade * 2.0:
				env = 0.5 - 0.5 * cos(PI * local / (fade * 2.0))
			elif local > seg:
				env = 0.5 + 0.5 * cos(PI * (local - seg) / (fade * 2.0))
			var v := 0.0
			for f in freqs:
				v += sin(TAU * f * t) + sin(TAU * (f + detune) * t) * 0.6
			v *= 0.05
			v += sin(TAU * root * t) * 0.14 + sin(TAU * root * 2.0 * t) * 0.04
			out[i] += v * env
	# Sparse plucked arpeggio
	var pattern := [0, 2, 3, 1, 2, 3, 1, 0]
	for ci in chords.size():
		for k in 8:
			var start := ci * seg + k * 1.0 + 0.5
			if start > loop_len - 1.2:
				continue
			var f: float = _snap(chords[ci][pattern[k]] * 2.0, loop_len)
			var i0 := int(start * rate)
			var len := int(1.1 * rate)
			for j in len:
				if i0 + j >= n:
					break
				var tt := float(j) / rate
				var e := exp(-tt * 3.2) * minf(tt * 200.0, 1.0)
				out[i0 + j] += (sin(TAU * f * tt) + 0.3 * sin(TAU * f * 2.0 * tt)) * e * 0.045
	# Gentle surf wash, silent at every 8s boundary so the loop stays seamless
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / rate
		y += (rng.randf_range(-1.0, 1.0) - y) * 0.06
		y2 += (y - y2) * 0.1
		var swell := pow(sin(PI * fposmod(t, seg) / seg), 2.0)
		out[i] += y2 * swell * 0.5
	var m := 0.0001
	for v in out:
		m = maxf(m, absf(v))
	for i in n:
		out[i] = out[i] / m * 0.6
	_music_data = out


func _snap(f: float, loop_len: float) -> float:
	return roundf(f * loop_len) / loop_len
