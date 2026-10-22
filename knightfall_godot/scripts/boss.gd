extends CharacterBody2D

signal boss_defeated

const GRAVITY := 1500.0
var max_health := 720.0
var health := 720.0
var speed := 58.0
var damage := 28.0
var player: Node2D
var attack_cooldown := 1.4
var windup := 0.0
var phase := 1
var dead := false
var hurt_flash := 0.0
var facing := -1
var attack_kind := 0

func _ready() -> void:
    add_to_group("enemies")
    player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
    if dead:
        return
    if player == null or not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player")
        return
    hurt_flash = maxf(0.0, hurt_flash - delta)
    attack_cooldown -= delta
    if health < max_health * 0.55:
        phase = 2
    var dx := player.global_position.x - global_position.x
    facing = 1 if dx > 0 else -1
    if not is_on_floor():
        velocity.y += GRAVITY * delta
    var range_needed := 110.0 if attack_kind == 1 else 78.0
    if absf(dx) > range_needed:
        velocity.x = facing * speed * (1.35 if phase == 2 else 1.0)
    else:
        velocity.x = move_toward(velocity.x, 0.0, 250.0 * delta)
    if attack_cooldown <= 0.0 and absf(dx) < 180.0:
        attack_cooldown = 1.8 if phase == 1 else 1.25
        windup = 0.42 if phase == 1 else 0.28
        attack_kind = randi_range(0, 1)
    if windup > 0.0:
        windup -= delta
        if windup <= 0.0:
            var dist := absf(player.global_position.x - global_position.x)
            if dist < (155.0 if attack_kind == 1 else 105.0):
                player.take_damage(damage * (1.25 if phase == 2 else 1.0), global_position.x)
                if attack_kind == 1:
                    player.velocity.x = facing * 370.0
    move_and_slide()
    queue_redraw()

func take_damage(amount: float, source_x: float = 0.0) -> void:
    if dead:
        return
    health -= amount
    hurt_flash = 0.12
    velocity.x = signf(global_position.x - source_x) * 90.0
    if health <= 0.0:
        health = 0.0
        dead = true
        boss_defeated.emit()
        var p := get_tree().get_first_node_in_group("player")
        if p and p.has_method("gain_xp"):
            p.gain_xp(250)
        await get_tree().create_timer(0.6).timeout
        if is_instance_valid(self):
            queue_free()

func _draw() -> void:
    var c := Color("#ff5c63") if hurt_flash > 0.0 else (Color("#8f2538") if phase == 1 else Color("#b64b32"))
    var d := float(facing)
    # ragged king cloak
    draw_colored_polygon(PackedVector2Array([Vector2(-31, -76), Vector2(29, -76), Vector2(44, -8), Vector2(18, -1), Vector2(0, -12), Vector2(-21, -1), Vector2(-43, -8)]), Color("#321b2b"))
    # body armor
    draw_rect(Rect2(-29, -81, 58, 52), c)
    draw_rect(Rect2(-22, -74, 44, 31), Color("#3a3545"))
    draw_line(Vector2(-19, -65), Vector2(19, -65), Color("#d4b46c"), 4.0)
    # crown
    draw_rect(Rect2(-25, -105, 50, 25), Color("#d3a94e"))
    draw_colored_polygon(PackedVector2Array([Vector2(-25, -103), Vector2(-22, -119), Vector2(-10, -108), Vector2(0, -124), Vector2(10, -108), Vector2(23, -119), Vector2(25, -103)]), Color("#e6bf5b"))
    draw_rect(Rect2(-15, -96, 8, 5), Color("#ff344a"))
    draw_rect(Rect2(7, -96, 8, 5), Color("#ff344a"))
    # giant cleaver
    draw_line(Vector2(26 * d, -56), Vector2(47 * d, -22), Color("#aab8ca"), 8.0)
    draw_line(Vector2(20 * d, -60), Vector2(33 * d, -48), Color("#d5a94e"), 5.0)
    # boss health bar
    draw_rect(Rect2(-48, -133, 96, 6), Color("#21151d"))
    draw_rect(Rect2(-48, -133, 96.0 * (health / max_health), 6), Color("#db3347"))
    if phase == 2:
        draw_circle(Vector2(0, -65), 47, Color(0.8, 0.12, 0.2, 0.08))
