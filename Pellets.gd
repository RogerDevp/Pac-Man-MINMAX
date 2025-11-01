extends Node2D

signal power_pellet_eaten
signal pellet_eaten



func _on_Pellet_eaten():
	emit_signal("pellet_eaten")


func _on_Power_Pellet_eaten():
	emit_signal("power_pellet_eaten")
