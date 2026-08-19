class_name Spring2D
extends RefCounted
## Simple damped spring for 2D UI physics.

var position: float = 0.0
var velocity: float = 0.0
var target: float = 0.0
var stiffness: float = 420.0
var damping: float = 18.0


func step(delta: float) -> float:
	var displacement := target - position
	var force := stiffness * displacement - damping * velocity
	velocity += force * delta
	position += velocity * delta
	return position


func snap_to(value: float) -> void:
	target = value
	position = value
	velocity = 0.0
