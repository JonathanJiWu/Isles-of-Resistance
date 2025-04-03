extends Control

var score = 0
var wave = 1

func update_score(new_score):
	score = new_score
	$ScoreLabel.text = "Score: %d" % score

func update_wave(new_wave):
	wave = new_wave
	$WaveLabel.text = "Wave: %d" % wave
