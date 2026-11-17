class_name MusicSynth
extends RefCounted
## Offline procedural music renderer. Builds seamless loops from a small score using wavetable
## synths, Karplus-Strong plucks, FM bells, a synthesized drum kit and a Schroeder reverb.
## Safe to run on a worker thread (touches no scene nodes).

const SR := 22050
const TBL := 2048
const MASK := 2047
const TAIL := 4.0

# Chord voicings (MIDI) and bass roots, all in D minor.
const CHORDS := {
	"Dm": [62, 65, 69], "Bb": [58, 62, 65], "F": [60, 65, 69], "C": [60, 64, 67],
	"Gm": [62, 67, 70], "A": [61, 64, 69],
}
const ROOTS := {"Dm": 38, "Bb": 34, "F": 41, "C": 36, "Gm": 43, "A": 33}

var dry := PackedFloat32Array()
var wet := PackedFloat32Array()
var rng := RandomNumberGenerator.new()
var sine := PackedFloat32Array()
var saw := PackedFloat32Array()
var soft := PackedFloat32Array()
var bpm := 120.0
var loop_len := 0


func _init(seed_value: int = 7) -> void:
	rng.seed = seed_value
	sine = _table([1.0])
	var h_saw: Array = []
	for k in range(1, 13):
		h_saw.append(1.0 / k)
	saw = _table(h_saw)
	soft = _table([1.0, 0.35, 0.12, 0.05])


func _table(harmonics: Array) -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(TBL)
	var peak := 0.0001
	for i in TBL:
		var v := 0.0
		for h in harmonics.size():
			v += sin(TAU * (h + 1) * i / TBL) * harmonics[h]
		t[i] = v
		peak = maxf(peak, absf(v))
	for i in TBL:
		t[i] /= peak
	return t


static func freq(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


func beat() -> float:
	return 60.0 / bpm


## Seconds at a position given in beats.
func at(beats: float) -> float:
	return beats * beat()


func begin(p_bpm: float, bars: int) -> void:
	bpm = p_bpm
	loop_len = int(bars * 4 * beat() * SR)
	var total := loop_len + int(TAIL * SR)
	dry = PackedFloat32Array()
	dry.resize(total)
	wet = PackedFloat32Array()
	wet.resize(total)


# --------------------------------------------------------------------------------------------
# Instruments
# --------------------------------------------------------------------------------------------

## Two detuned wavetable oscillators through a one-pole low-pass whose cutoff glides from
## cut0 to cut1 over the note.
func synth(start: float, dur: float, midi: float, amp: float, table: PackedFloat32Array,
		attack: float = 0.01, release: float = 0.2, cut0: float = 3000.0, cut1: float = 1500.0,
		detune: float = 8.0, send: float = 0.2, vib: float = 0.0) -> void:
	var f := freq(midi)
	var i0 := int(start * SR)
	var n := int((dur + release) * SR)
	var inc1 := f / SR * TBL
	var inc2 := f * pow(2.0, detune / 1200.0) / SR * TBL
	var p1 := rng.randf() * TBL
	var p2 := rng.randf() * TBL
	var c0 := 1.0 - exp(-TAU * cut0 / SR)
	var c1 := 1.0 - exp(-TAU * cut1 / SR)
	var size := dry.size()
	var vph := 0.0
	var vinc := 5.2 / SR * TBL
	var y := 0.0
	var inv_dur := 1.0 / maxf(dur, 0.001)
	for k in n:
		var idx := i0 + k
		if idx >= size:
			break
		var tt := float(k) / SR
		var env := 1.0
		if tt < attack:
			env = tt / attack
		elif tt > dur:
			env = 1.0 - (tt - dur) / release
			env *= env
		var c := lerpf(c0, c1, minf(tt * inv_dur, 1.0))
		var m := 1.0
		if vib > 0.0:
			vph += vinc
			m = 1.0 + vib * sine[int(vph) & MASK] * minf(tt * 2.0, 1.0)
		p1 += inc1 * m
		p2 += inc2 * m
		y += (table[int(p1) & MASK] + table[int(p2) & MASK] - y) * c
		var v := y * env * amp
		dry[idx] += v
		wet[idx] += v * send


## Karplus-Strong plucked string (harp / guitar-like).
func pluck(start: float, midi: float, amp: float, dur: float = 1.6, fb: float = 0.996, send: float = 0.35) -> void:
	var period := maxi(2, int(round(SR / freq(midi))))
	var line := PackedFloat32Array()
	line.resize(period)
	for k in period:
		line[k] = rng.randf_range(-1.0, 1.0)
	for k in range(1, period):
		line[k] = (line[k] + line[k - 1]) * 0.5
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var size := dry.size()
	var idx := 0
	var fade_n := 600
	for k in n:
		var o := i0 + k
		if o >= size:
			break
		var cur := line[idx]
		var nxt := idx + 1
		if nxt == period:
			nxt = 0
		line[idx] = (cur + line[nxt]) * 0.5 * fb
		var fade := 1.0 if k < n - fade_n else float(n - k) / fade_n
		var v := cur * amp * fade * minf(k / 40.0, 1.0)
		dry[o] += v
		wet[o] += v * send
		idx = nxt


## FM bell / celesta.
func bell(start: float, midi: float, amp: float, dur: float = 2.2, send: float = 0.5) -> void:
	var f := freq(midi)
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var size := dry.size()
	var pc := 0.0
	var pm := 0.0
	var ic := f / SR * TBL
	var im := f * 3.5 / SR * TBL
	var scale := TBL / TAU
	for k in n:
		var o := i0 + k
		if o >= size:
			break
		var tt := float(k) / SR
		var index := 2.2 * exp(-tt * 4.0)
		pc += ic
		pm += im
		var v := sine[int(pc + index * sine[int(pm) & MASK] * scale) & MASK]
		v *= exp(-tt * 2.4) * minf(tt * 300.0, 1.0) * amp
		dry[o] += v
		wet[o] += v * send


func kick(start: float, amp: float = 1.0) -> void:
	var i0 := int(start * SR)
	var n := int(0.42 * SR)
	var size := dry.size()
	var ph := 0.0
	for k in n:
		var o := i0 + k
		if o >= size:
			break
		var tt := float(k) / SR
		ph += (44.0 + 115.0 * exp(-tt * 32.0)) / SR * TBL
		var v := sine[int(ph) & MASK] * exp(-tt * 6.5) + rng.randf_range(-1.0, 1.0) * exp(-tt * 260.0) * 0.25
		dry[o] += v * amp


func snare(start: float, amp: float = 1.0, send: float = 0.18) -> void:
	var i0 := int(start * SR)
	var n := int(0.28 * SR)
	var size := dry.size()
	var ph := 0.0
	var lp := 0.0
	for k in n:
		var o := i0 + k
		if o >= size:
			break
		var tt := float(k) / SR
		ph += 190.0 / SR * TBL
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.25
		var v := (sine[int(ph) & MASK] * exp(-tt * 22.0) * 0.55 + (x - lp) * exp(-tt * 15.0) * 0.9) * minf(k / 12.0, 1.0)
		dry[o] += v * amp
		wet[o] += v * amp * send


func hat(start: float, amp: float = 1.0, open: bool = false) -> void:
	var i0 := int(start * SR)
	var n := int((0.3 if open else 0.07) * SR)
	var size := dry.size()
	var lp := 0.0
	var lp2 := 0.0
	var decay := 11.0 if open else 75.0
	for k in n:
		var o := i0 + k
		if o >= size:
			break
		var tt := float(k) / SR
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.5
		var hp := x - lp
		lp2 += (hp - lp2) * 0.6
		dry[o] += (hp - lp2 * 0.3) * exp(-tt * decay) * amp * minf(k / 12.0, 1.0)


func tom(start: float, midi: float, amp: float = 1.0) -> void:
	var i0 := int(start * SR)
	var n := int(0.45 * SR)
	var size := dry.size()
	var f := freq(midi)
	var ph := 0.0
	for k in n:
		var o := i0 + k
		if o >= size:
			break
		var tt := float(k) / SR
		ph += f * (1.0 + 0.6 * exp(-tt * 25.0)) / SR * TBL
		var v := sine[int(ph) & MASK] * exp(-tt * 9.0) * amp
		dry[o] += v
		wet[o] += v * 0.2


func timpani(start: float, midi: float, amp: float = 1.0) -> void:
	var i0 := int(start * SR)
	var n := int(2.2 * SR)
	var size := dry.size()
	var f := freq(midi)
	var ph := 0.0
	var ph2 := 0.0
	var lp := 0.0
	for k in n:
		var o := i0 + k
		if o >= size:
			break
		var tt := float(k) / SR
		var df := 1.0 + 0.04 * exp(-tt * 8.0)
		ph += f * df / SR * TBL
		ph2 += f * 1.5 * df / SR * TBL
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.08
		var v := (sine[int(ph) & MASK] + sine[int(ph2) & MASK] * 0.35) * exp(-tt * 2.6) + lp * exp(-tt * 30.0) * 2.0
		dry[o] += v * amp
		wet[o] += v * amp * 0.35


func crash(start: float, amp: float = 1.0, dur: float = 2.6) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var size := dry.size()
	var lp := 0.0
	for k in n:
		var o := i0 + k
		if o >= size:
			break
		var tt := float(k) / SR
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.35
		var v := (x - lp) * exp(-tt * 2.2) * minf(tt * 400.0, 1.0) * amp
		dry[o] += v
		wet[o] += v * 0.4


## Rising noise swell that leads into the downbeat at `start + dur`.
func swell(start: float, dur: float, amp: float = 1.0) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var size := dry.size()
	var lp := 0.0
	for k in n:
		var o := i0 + k
		if o >= size:
			break
		var p := float(k) / n
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * (0.05 + 0.4 * p)
		var v := lp * p * p * amp
		dry[o] += v
		wet[o] += v * 0.5


# --------------------------------------------------------------------------------------------
# Mixdown
# --------------------------------------------------------------------------------------------

func _reverb(x: PackedFloat32Array) -> PackedFloat32Array:
	var n := x.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for d in [557, 593, 641, 677]:
		var buf := PackedFloat32Array()
		buf.resize(d)
		var idx := 0
		var filt := 0.0
		for i in n:
			var y := buf[idx]
			filt = y * 0.7 + filt * 0.3
			buf[idx] = x[i] + filt * 0.82
			out[i] += y
			idx += 1
			if idx == d:
				idx = 0
	for d in [223, 79]:
		var buf := PackedFloat32Array()
		buf.resize(d)
		var idx := 0
		for i in n:
			var b := buf[idx]
			var inp := out[i]
			buf[idx] = inp + b * 0.5
			out[i] = b - inp
			idx += 1
			if idx == d:
				idx = 0
	for i in n:
		out[i] *= 0.22
	return out


## Mixes dry + reverb, folds the tail into the loop start (seamless loop), limits and normalises.
func finish(level: float = 0.85) -> PackedFloat32Array:
	var rev := _reverb(wet)
	var total := dry.size()
	var out := PackedFloat32Array()
	out.resize(total)
	for i in total:
		out[i] = dry[i] + rev[i]
	for i in range(loop_len, total):
		out[i - loop_len] += out[i]
	out.resize(loop_len)
	var lp := 0.0
	var peak := 0.0001
	for i in loop_len:
		# Gentle DC blocker.
		lp += (out[i] - lp) * 0.0005
		out[i] -= lp
		peak = maxf(peak, absf(out[i]))
	for i in loop_len:
		var v := out[i] / peak
		out[i] = (1.5 * v - 0.5 * v * v * v) * level
	return out


static func to_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	return data


# --------------------------------------------------------------------------------------------
# Score
# --------------------------------------------------------------------------------------------

func render(track: String) -> PackedFloat32Array:
	match track:
		"theme":
			return _theme()
		"planning":
			return _planning()
		"battle":
			return _battle()
	return PackedFloat32Array()


func _theme() -> PackedFloat32Array:
	begin(84.0, 16)
	var prog := ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A", "Bb", "F", "C", "Dm", "Bb", "F", "Gm", "A"]
	var arp := [0, 1, 2, 3, 2, 1, 3, 2]
	for b in prog.size():
		var ch: Array = CHORDS[prog[b]]
		var root: int = ROOTS[prog[b]]
		var t0 := at(b * 4.0)
		for nt in ch:
			synth(t0, at(4.0), nt, 0.085, soft, 0.6, 1.2, 1700.0, 1100.0, 9.0, 0.55)
			if b >= 8:
				synth(t0, at(4.0), nt + 12, 0.04, saw, 0.9, 1.2, 2400.0, 1400.0, 7.0, 0.6)
		synth(t0, at(4.0), root, 0.2, saw, 0.04, 0.5, 520.0, 300.0, 5.0, 0.1)
		synth(t0, at(4.0), root - 12, 0.12, sine, 0.04, 0.5, 400.0, 300.0, 0.0, 0.0)
		var tones := [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24]
		for k in 8:
			pluck(t0 + at(k * 0.5), tones[arp[k]], 0.2 if k % 2 == 0 else 0.14, 1.2)
		if b % 4 == 0:
			timpani(t0, 38 if prog[b] != "A" else 33, 0.5)
	timpani(at(31.0), 33, 0.35)
	timpani(at(31.5), 33, 0.45)
	crash(0.0, 0.18)
	crash(at(32.0), 0.25)
	swell(at(30.0), at(2.0), 0.2)
	var melody := [
		[32.0, 2.0, 69], [34.0, 1.0, 70], [35.0, 1.0, 69],
		[36.0, 2.0, 65], [38.0, 1.0, 67], [39.0, 1.0, 69],
		[40.0, 3.0, 64], [43.0, 1.0, 60],
		[44.0, 4.0, 62],
		[48.0, 2.0, 74], [50.0, 1.0, 72], [51.0, 1.0, 70],
		[52.0, 2.0, 69], [54.0, 2.0, 65],
		[56.0, 1.0, 67], [57.0, 1.0, 69], [58.0, 2.0, 70],
		[60.0, 3.0, 69], [63.0, 1.0, 73],
	]
	for m in melody:
		synth(at(m[0]), at(m[1]) * 0.95, m[2], 0.12, saw, 0.07, 0.35, 2200.0, 1300.0, 6.0, 0.45, 0.006)
	return finish(0.85)


func _planning() -> PackedFloat32Array:
	begin(70.0, 8)
	var prog := ["Dm", "Bb", "F", "C", "Gm", "Bb", "Dm", "A"]
	var pattern := [[0.0, 0], [1.5, 2], [2.0, 1], [3.0, 3]]
	for b in prog.size():
		var ch: Array = CHORDS[prog[b]]
		var root: int = ROOTS[prog[b]]
		var t0 := at(b * 4.0)
		for nt in ch:
			synth(t0, at(4.0), nt, 0.075, soft, 1.2, 2.0, 1200.0, 900.0, 10.0, 0.65)
		synth(t0, at(4.0), root, 0.16, sine, 0.3, 1.0, 900.0, 600.0, 0.0, 0.05)
		var tones := [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[0] + 24]
		for p in pattern:
			pluck(t0 + at(p[0]), tones[p[1]], 0.13, 2.4, 0.997, 0.5)
		if b % 2 == 1:
			bell(t0 + at(2.0), ch[2] + 12, 0.09)
			bell(t0 + at(3.0), ch[1] + 12, 0.06)
		for k in 8:
			hat(t0 + at(k * 0.5), 0.05 if k % 2 == 0 else 0.03)
	return finish(0.8)


func _battle() -> PackedFloat32Array:
	begin(132.0, 16)
	var prog := ["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A", "Bb", "C", "Dm", "Dm", "Gm", "Bb", "A", "A"]
	var bass_pat := [0, 0, 12, 0, 7, 0, 12, 7]
	for b in prog.size():
		var ch: Array = CHORDS[prog[b]]
		var root: int = ROOTS[prog[b]]
		var t0 := at(b * 4.0)
		var fill := b == 7 or b == 15
		# Drums
		kick(t0, 0.9)
		kick(t0 + at(1.5), 0.6)
		kick(t0 + at(2.0), 0.85)
		if not fill:
			kick(t0 + at(3.5), 0.5)
		snare(t0 + at(1.0), 0.55)
		if fill:
			for k in 8:
				tom(t0 + at(2.0 + k * 0.25), 50.0 - k * 2.0, 0.45)
		else:
			snare(t0 + at(3.0), 0.55)
		for k in 8:
			hat(t0 + at(k * 0.5), 0.12 if k % 2 == 0 else 0.07, k == 7 and not fill)
		# Bass ostinato
		for k in 8:
			synth(t0 + at(k * 0.5), at(0.42), root + 12 + bass_pat[k], 0.17, saw, 0.004, 0.06, 1500.0, 380.0, 4.0, 0.03)
		# Brass stabs
		for nt in ch:
			synth(t0, at(0.9), nt, 0.07, saw, 0.01, 0.25, 3800.0, 900.0, 9.0, 0.3)
			synth(t0 + at(2.5), at(0.4), nt, 0.05, saw, 0.01, 0.15, 3200.0, 900.0, 9.0, 0.25)
		# Staccato strings from the second phrase on
		if b >= 4:
			var hi := [ch[2] + 12, ch[1] + 12, ch[0] + 12, ch[1] + 12]
			for k in 8:
				synth(t0 + at(k * 0.5), at(0.22), hi[k % 4], 0.045, saw, 0.005, 0.08, 3600.0, 2000.0, 6.0, 0.2)
		if b % 8 == 0:
			timpani(t0, 38, 0.55)
	crash(0.0, 0.3)
	crash(at(32.0), 0.35)
	swell(at(30.0), at(2.0), 0.25)
	var lead := [
		[32.0, 1.5, 74], [33.5, 0.5, 72], [34.0, 1.0, 74], [35.0, 1.0, 77],
		[36.0, 3.0, 76], [39.0, 1.0, 72],
		[40.0, 1.5, 74], [41.5, 0.5, 69], [42.0, 1.0, 74], [43.0, 1.0, 76],
		[44.0, 2.0, 77], [46.0, 1.0, 76], [47.0, 1.0, 74],
		[48.0, 1.5, 79], [49.5, 0.5, 77], [50.0, 2.0, 74],
		[52.0, 1.5, 77], [53.5, 0.5, 74], [54.0, 2.0, 70],
		[56.0, 2.0, 73], [58.0, 2.0, 76],
		[60.0, 3.0, 81],
	]
	for m in lead:
		synth(at(m[0]), at(m[1]) * 0.92, m[2], 0.1, saw, 0.03, 0.2, 3200.0, 1900.0, 7.0, 0.35, 0.005)
	return finish(0.88)
