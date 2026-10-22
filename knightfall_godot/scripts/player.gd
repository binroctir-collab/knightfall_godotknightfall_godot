extends CharacterBody2D

signal stats_changed
signal died
signal level_up(new_level: int)

const GRAVITY := 1500.0
const WALK_SPEED := 270.0
const JUMP_VELOCITY := -560.0
const MAX_STAMINA := 100.0

var max_health := 120.0
var health := 120.0
var stamina := 100.0
var xp := 0
var xp_to_next := 100
var level := 1
var gold := 0
var potions := 3
var upgrade_points := 0
var facing := 1
var attack_cooldown := 0.0
var attack_timer := 0.0
var attack_damage := 24.0
var heavy_damage := 42.0
var dodge_timer := 0.0
var dodge_cooldown := 0.0
var invulnerable_timer := 0.0
var hurt_flash := 0.0
var dead := false
var blocking := false
var heavy_attack := false
var attack_hit_ids: Array[int] = []
var mobile_left := false
var mobile_right := false
var mobile_jump := false
var mobile_light := false
var mobile_heavy := false
var mobile_dodge := false
var mobile_heal := false
var weapon_bonus := 0.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D

func _ready() -> void:
    add_to_group("player")
    attack_area.body_entered.connect(_on_attack_body_entered)
    stats_changed.emit()

func _physics_process(delta: float) -> void:
    if dead:
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    attack_timer = maxf(0.0, attack_timer - delta)
    dodge_timer = maxf(0.0, dodge_timer - delta)
    dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
    invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
    hurt_flash = maxf(0.0, hurt_flash - delta)

    var input_x := Input.get_axis("move_left", "move_right")
    if mobile_left:
        input_x = -1.0
    if mobile_right:
        input_x = 1.0
    if mobile_left and mobile_right:
        input_x = 0.0

    blocking = Input.is_action_pressed("block")
    if dodge_timer > 0.0:
        velocity.x = facing * 620.0
    else:
        velocity.x = input_x * WALK_SPEED
    if absf(input_x) > 0.05:
        facing = 1 if input_x > 0 else -1

    if not is_on_floor():
        velocity.y += GRAVITY * delta
    else:
        if Input.is_action_just_pressed("jump") or (mobile_jump and not _was_mobile_jump):
            velocity.y = JUMP_VELOCITY
    _was_mobile_jump = mobile_jump

    if Input.is_action_just_pressed("light_attack") or (mobile_light and not _was_mobile_light):
        do_attack(false)
    if Input.is_action_just_pressed("heavy_attack") or (mobile_heavy and not _was_mobile_heavy):
        do_attack(true)
    if Input.is_action_just_pressed("dodge") or (mobile_dodge and not _was_mobile_dodge):
        do_dodge()
    if Input.is_action_just_pressed("heal") or (mobile_heal and not _was_mobile_heal):
        heal()
    _was_mobile_light = mobile_light
    _was_mobile_heavy = mobile_heavy
    _was_mobile_dodge = mobile_dodge
    _was_mobile_heal = mobile_heal

    if attack_timer > 0.0:
        attack_area.position.x = facing * 31.0
        attack_shape.disabled = false
    else:
        attack_shape.disabled = true

    move_and_slide()
    queue_redraw()

var _was_mobile_jump := false
var _was_mobile_light := false
var _was_mobile_heavy := false
var _was_mobile_dodge := false
var _was_mobile_heal := false

func do_attack(is_heavy: bool) -> void:
    if attack_cooldown > 0.0 or dodge_timer > 0.0:
        return
    if is_heavy:
        if stamina < 28.0:
            return
        stamina -= 28.0
        attack_timer = 0.24
        attack_cooldown = 0.72
        heavy_attack = true
        attack_damage = heavy_damage + weapon_bonus
    else:
        attack_timer = 0.16
        attack_cooldown = 0.34
        heavy_attack = false
        attack_damage = 24.0 + weapon_bonus
    attack_hit_ids.clear()
    attack_area.position.x = facing * 31.0
    attack_shape.disabled = false
    stats_changed.emit()

func do_dodge() -> void:
    if dodge_cooldown > 0.0 or stamina < 22.0:
        return
    stamina -= 22.0
    dodge_timer = 0.22
    dodge_cooldown = 0.75
    invulnerable_timer = 0.32
    stats_changed.emit()

func heal() -> void:
    if potions <= 0 or health >= max_health or dead:
        return
    potions -= 1
    health = minf(max_health, health + 48.0)
    stats_changed.emit()

func take_damage(amount: float, source_position: float = 0.0) -> void:
    if dead or invulnerable_timer > 0.0:
        return
    var final_damage := amount
    if blocking and stamina > 0.0:
        final_damage *= 0.35
        stamina = maxf(0.0, stamina - amount * 0.55)
    health -= final_damage
    hurt_flash = 0.18
    invulnerable_timer = 0.42
    velocity.x = signf(global_position.x - source_position) * 220.0
    stats_changed.emit()
    if health <= 0.0:
        health = 0.0
        dead = true
        died.emit()
    queue_redraw()

func gain_xp(amount: int) -> void:
    xp += amount
    gold += randi_range(4, 13)
    while xp >= xp_to_next:
        xp -= xp_to_next
        level += 1
        xp_to_next = int(xp_to_next * 1.28) + 35
        upgrade_points += 1
        max_health += 12.0
        health = max_health
        attack_damage += 2.0
        heavy_damage += 3.0
        level_up.emit(level)
    stats_changed.emit()

func upgrade_health() -> void:
    if upgrade_points <= 0:
        return
    upgrade_points -= 1
    max_health += 25.0
    health = minf(max_health, health + 25.0)
    stats_changed.emit()

func upgrade_weapon() -> void:
    if upgrade_points <= 0:
        return
    upgrade_points -= 1
    weapon_bonus += 8.0
    stats_changed.emit()

func _on_attack_body_entered(body: Node2D) -> void:
    if body == self or not body.is_in_group("enemies"):
        return
    var id := body.get_instance_id()
    if attack_timer <= 0.0 or attack_hit_ids.has(id):
        return
    attack_hit_ids.append(id)
    if body.has_method("take_damage"):
        body.take_damage(attack_damage, global_position.x)
        if heavy_attack and body is CharacterBody2D:
            body.velocity.x = facing * 330.0

func _draw() -> void:
    var main_color := Color("#a9b5c9")
    if hurt_flash > 0.0:
        main_color = Color("#ff5d63")
    var dir := float(facing)
    # cape
    draw_colored_polygon(PackedVector2Array([Vector2(-9, -45), Vector2(-19 * dir, -39), Vector2(-17 * dir, -10), Vector2(-3, -18)]), Color("#6e1f2a"))
    # legs and boots
    draw_rect(Rect2(-10, -17, 8, 17), Color("#303545"))
    draw_rect(Rect2(2, -17, 8, 17), Color("#303545"))
    draw_rect(Rect2(-12, -4, 12, 5), Color("#171923"))
    draw_rect(Rect2(1, -4, 12, 5), Color("#171923"))
    # torso armor
    draw_rect(Rect2(-12, -39, 24, 24), main_color)
    draw_rect(Rect2(-9, -35, 18, 14), Color("#5e6c83"))
    draw_line(Vector2(0, -37), Vector2(0, -18), Color("#242b39"), 2.0)
    # head / helmet
    draw_rect(Rect2(-10, -54, 20, 16), Color("#aab4c3"))
    draw_rect(Rect2(-9, -52, 18, 4), Color("#e0e5ec"))
    draw_rect(Rect2(-7, -46, 14, 4), Color("#202633"))
    draw_line(Vector2(-7, -44), Vector2(7, -44), Color("#df3947"), 2.0)
    # sword
    var sword_start := Vector2(10 * dir, -28)
    var sword_end := Vector2(31 * dir, -48 if attack_timer > 0 else -36)
    draw_line(sword_start, sword_end, Color("#dce7f4"), 5.0)
    draw_line(sword_start + Vector2(-2 * dir, 3), sword_start + Vector2(2 * dir, -3), Color("#c28a45"), 4.0)
    # shield when blocking
    if blocking:
        draw_colored_polygon(PackedVector2Array([Vector2(10 * dir, -40), Vector2(24 * dir, -36), Vector2(22 * dir, -18), Vector2(12 * dir, -14)]), Color("#536b82"))
        draw_line(Vector2(13 * dir, -34), Vector2(20 * dir, -22), Color("#d3b56d"), 2.0)
