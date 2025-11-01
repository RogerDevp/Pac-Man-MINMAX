extends CanvasLayer

var score := 0
var high_score := 0
var level_active := true


func new_game(lives: int):
	draw_lives(lives)
	$GameText.visible = false


func reset():
	score = 0
	$Game_Over_Text.visible = false


func level_won():
	Print.info("Level Cleared!")


func add_score(value: int):
	score += value
	if score > high_score:
		high_score = score
	$Score.text = str(score)
	$HighScore.text = str(score)


func draw_lives(lives: int):
	$Life1.visible = lives >= 1
	$Life2.visible = lives >= 2
	$Life3.visible = lives >= 3
	$Life4.visible = lives >= 4
	$Life5.visible = lives >= 5


func game_over():
	$Game_Over_Text.visible = true
