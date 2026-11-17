extends Node
## Procedurally synthesized sound effects and music. No audio assets are required.
## Music cues ("theme", "planning", "battle") are rendered by MusicSynth on a worker thread
## the first time the game runs, cached in user://, and crossfaded on demand.

const RATE := 22050
const POOL_SIZE := 16
const MUSIC_VERSION := 4
const TRACKS := ["theme", "planning", "battle"]
const SILENT_DB := -80.0

var sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _music_players := {}
var _music_tweens := {}
var _wanted := ""
var _current := ""
var _tasks: Array = []
var _mutex := Mutex.new()
var _rendered := {}


func _ready() -> void:
	# Keep sound and music running while the game is paused (pause menu clicks, ambience).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for t in TRACKS:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		mp.volume_db = SILENT_DB
		add_child(mp)
		_music_players[t] = mp
	_build_sounds()
	var missing: Array = []
	for t in TRACKS:
		var cached := _load_cached(t)
		if cached.is_empty():
			missing.append(t)
		else:
			_install(t, cached)
	# Render missing cues in parallel; each finishes independently.
	for t in missing:
		_tasks.append(WorkerThreadPool.add_task(_render_track.bind(t)))


func _process(_delta: float) -> void:
	if _tasks.is_empty():
		return
	_mutex.lock()
	var done := _rendered.duplicate()
	_rendered.clear()
	_mutex.unlock()
	for t in done:
		_install(t, done[t])
		_save_cached(t, done[t])
	for id in _tasks.duplicate():
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_tasks.erase(id)


func _exit_tree() -> void:
	for id in _tasks:
		WorkerThreadPool.wait_for_task_completion(id)
	_tasks.clear()


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
# Music
# --------------------------------------------------------------------------------------------

## Crossfades to a music cue ("theme", "planning", "battle", or "" for silence).
## The planning cue keeps its place when interrupted so it resumes smoothly after battles.
func music(track: String, fade: float = 1.6) -> void:
	_wanted = track
	_apply_music(fade)


func current_music() -> String:
	return _current


func music_ready(track: String) -> bool:
	return _music_players.has(track) and _music_players[track].stream != null


func _apply_music(fade: float) -> void:
	if _wanted == _current:
		return
	if _wanted != "" and not music_ready(_wanted):
		return
	var prev := _current
	_current = _wanted
	for t in _music_players:
		var mp: AudioStreamPlayer = _music_players[t]
		if mp.stream == null:
			continue
		if t != _current and not mp.playing:
			continue
		if _music_tweens.has(t) and _music_tweens[t] != null:
			_music_tweens[t].kill()
		var tw := create_tween()
		_music_tweens[t] = tw
		var from := clampf(db_to_linear(mp.volume_db), 0.0, 1.0)
		if t == _current:
			if not mp.playing:
				from = 0.0
				mp.play(0.0)
			elif t == "battle" and prev != "battle":
				mp.play(0.0)
			# Equal-power fade in from the current level.
			tw.tween_method(func(p: float): mp.volume_db = linear_to_db(maxf(lerpf(from, 1.0, sin(p * PI * 0.5)), 0.0001)), 0.0, 1.0, fade)
		else:
			tw.tween_method(func(p: float): mp.volume_db = linear_to_db(maxf(from * cos(p * PI * 0.5), 0.0001)), 0.0, 1.0, fade)
			# Planning keeps rolling silently underneath; other cues stop once faded out.
			if t != "planning" or _current == "theme" or _current == "":
				tw.tween_callback(mp.stop)


func _install(track: String, pcm: PackedByteArray) -> void:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MusicSynth.SR
	w.stereo = false
	w.data = pcm
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = pcm.size() / 2
	_music_players[track].stream = w
	if _wanted == track:
		_apply_music(2.5)


func _render_track(track: String) -> void:
	var synth := MusicSynth.new(TRACKS.find(track) * 101 + 7)
	var pcm := MusicSynth.to_pcm16(synth.render(track))
	_mutex.lock()
	_rendered[track] = pcm
	_mutex.unlock()


func _cache_path(track: String) -> String:
	return "user://music_v%d_%s.pcm" % [MUSIC_VERSION, track]


func _load_cached(track: String) -> PackedByteArray:
	var path := _cache_path(track)
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var data := f.get_buffer(f.get_length())
	f.close()
	return data if data.size() > 1000 else PackedByteArray()


func _save_cached(track: String, pcm: PackedByteArray) -> void:
	var f := FileAccess.open(_cache_path(track), FileAccess.WRITE)
	if f != null:
		f.store_buffer(pcm)
		f.close()


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
