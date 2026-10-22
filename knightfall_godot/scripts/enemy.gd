extends CharacterBody2D

signal defeated(xp_reward: int)

const GRAVITY := 1500.0
var enemy_type := "zombie"
var max_health := 60.0
var health := 60.0
var speed := 72.0
var damage := 12.0
var xp_reward := 25
var attack_range := 40.0
var attack_cooldown := 0.0
var hurt_flash := 0.0
var dead := false
var facing := -1
var attack_windup := 0.0
var player: Node2D
var tint := Color("#6e9a6c")

func setup(kind: String = "zombie", difficulty: float = 1.0) -> void:
    enemy_type = kind
    match enemy_type:
        "ghoul":
            max_health = 42.0
            speed = 132.0
            damage = 10.0
            xp_reward = 32
            tint = Color("#b6a06b")
        "armored":
            max_health = 115.0
            speed = 48.0
            damage = 21.0
            xp_reward = 48
            tint = Color("#77849b")
        "archer":
            max_health = 48.0
            speed = 42.0
            damage = 12.0
            xp_reward = 38
            tint = Color("#9d7ba4")
        _:
            max_health = 65.0
            speed = 68.0
            damage = 13.0
            xp_reward = 25
            tint = Color("#6e9a6c")
    max_health *= difficulty
    health = max_health
    damage *= difficulty

func _ready() -> void:
    add_to_group("enemies")
    player = get_tree().get_first_node_in_group("player")
    if player == null:
        call_deferred("_find_player")

func _find_player() -> void:
    player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
    if dead:
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    hurt_flash = maxf(0.0, hurt_flash - delta)
    if player == null or not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player")
        return
    var dx := player.global_position.x - global_position.x
    facing = 1 if dx > 0 else -1
    if not is_on_floor():
        velocity.y += GRAVITY * delta
    if absf(dx) > attack_range:
        velocity.x = facing * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed * 5.0 * delta)
        if attack_cooldown <= 0.0 and absf(player.global_position.y - global_position.y) < 70.0:
            attack_cooldown = 1.25 if enemy_type != "ghoul" else 0.95
            attack_windup = 0.22
    if attack_windup > 0.0:
        attack_windup -= delta
        if attack_windup <= 0.0 and absf(dx) < attack_range + 22.0:
            if player.has_method("take_damage"):
                player.take_damage(damage, global_position.x)
    move_and_slide()
    queue_redraw()

func take_damage(amount: float, source_x: float = 0.0) -> void:
    if dead:
        return
    var actual := amount
    if enemy_type == "armored":
        actual *= 0.72
    health -= actual
    hurt_flash = 0.12
    velocity.x = signf(global_position.x - source_x) * 180.0
    if health <= 0.0:
        health = 0.0
        dead = true
        defeated.emit(xp_reward)
        var p := get_tree().get_first_node_in_group("player")
        if p and p.has_method("gain_xp"):
            p.gain_xp(xp_reward)
        queue_redraw()
        await get_tree().create_timer(0.22).timeout
        if is_instance_valid(self):
            queue_free()

func _draw() -> void:
    var c := Color("#ff6868") if hurt_flash > 0.0 else tint
    var d := float(facing)
    # ragged cloak/body
    draw_colored_polygon(PackedVector2Array([Vector2(-13, -42), Vector2(12, -42), Vector2(16, -8), Vector2(8, -3), Vector2(0, -10), Vector2(-9, -2), Vector2(-16, -9)]), c)
    # legs
    draw_rect(Rect2(-10, -12, 7, 12), Color("#292b34"))
    draw_rect(Rect2(3, -12, 7, 12), Color("#292b34"))
    # head
    draw_circle(Vector2(0, -47), 10, c.lightened(0.1))
    draw_rect(Rect2(-7, -49, 5, 3), Color("#f5d16a"))
    draw_rect(Rect2(2, -49, 5, 3), Color("#f5d16a"))
    draw_line(Vector2(6 * d, -29), Vector2(18 * d, -22), Color("#4b463d"), 5.0)
    if enemy_type == "armored":
        draw_rect(Rect2(-15, -38, 30, 24), Color("#394353"))
        draw_line(Vector2(-11, -33), Vector2(11, -33), Color("#a6b2c4"), 2.0)
    elif enemy_type == "ghoul":
        draw_line(Vector2(9 * d, -30), Vector2(20 * d, -17), Color("#e2d4a0"), 3.0)
    elif enemy_type == "archer":
        draw_line(Vector2(7 * d, -34), Vector2(17 * d, -20), Color("#9a7144"), 3.0)
    # tiny health bar
    draw_rect(Rect2(-16, -62, 32, 4), Color("#241f2a"))
    draw_rect(Rect2(-16, -62, 32.0 * (health / max_health), 4), Color("#c94350"))
