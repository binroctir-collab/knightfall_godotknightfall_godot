extends Node2D

var t := 0.0

func _process(delta: float) -> void:
    t += delta
    queue_redraw()

func _draw() -> void:
    var flicker := sin(t * 13.0) * 3.0
    draw_colored_polygon(PackedVector2Array([Vector2(-13,0),Vector2(-8,-19-flicker),Vector2(-1,-31-flicker),Vector2(4,-17),Vector2(12,-4)]), Color("#e65d32"))
    draw_colored_polygon(PackedVector2Array([Vector2(-7,0),Vector2(-2,-17-flicker),Vector2(3,-24-flicker),Vector2(8,-5)]), Color("#ffc66e"))
    draw_circle(Vector2(0,-2), 14, Color(0.9,0.25,0.05,0.12))
