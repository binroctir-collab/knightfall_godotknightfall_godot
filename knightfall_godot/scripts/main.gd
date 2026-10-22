extends Node2D

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const BOSS_SCENE := preload("res://scenes/Boss.tscn")

var player: CharacterBody2D
var boss: CharacterBody2D
var hud: CanvasLayer
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var xp_bar: ProgressBar
var status_label: Label
var toast_label: Label
var boss_bar: ProgressBar
var pause_panel: PanelContainer
var death_panel: PanelContainer
var victory_panel: PanelContainer
var skill_panel: PanelContainer
var world_time := 0.0
var paused_by_menu := false
var boss_spawned := false
var boss_dead := false
var platform_nodes: Array[ColorRect] = []
var touch_buttons: Array[Button] = []
var touch_controls: Control

func _ready() -> void:
    _setup_input()
    _build_world()
    _spawn_player()
    _spawn_enemies()
    _build_ui()
    player.stats_changed.connect(_update_hud)
    player.died.connect(_on_player_died)
    player.level_up.connect(_on_level_up)
    _update_hud()

func _setup_input() -> void:
    _add_key_action("move_left", [KEY_A, KEY_LEFT])
    _add_key_action("move_right", [KEY_D, KEY_RIGHT])
    _add_key_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
    _add_key_action("light_attack", [KEY_J])
    _add_key_action("heavy_attack", [KEY_K])
    _add_key_action("dodge", [KEY_L])
    _add_key_action("heal", [KEY_I])
    _add_key_action("block", [KEY_SHIFT])

func _add_key_action(action: String, keys: Array) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action)
    for keycode in keys:
        var ev := InputEventKey.new()
        ev.physical_keycode = keycode
        InputMap.action_add_event(action, ev)

func _build_world() -> void:
    # Moonlit background
    var sky := ColorRect.new()
    sky.color = Color("#111725")
    sky.position = Vector2(-1000, -1000)
    sky.size = Vector2(4000, 1800)
    add_child(sky)
    # distant moon
    var moon := Polygon2D.new()
    moon.polygon = PackedVector2Array([Vector2(0,-52),Vector2(28,-44),Vector2(48,-20),Vector2(50,8),Vector2(32,34),Vector2(5,47),Vector2(-24,37),Vector2(-45,13),Vector2(-43,-17),Vector2(-22,-42)])
    moon.color = Color("#c6d0df")
    moon.position = Vector2(950, 115)
    add_child(moon)
    # far castle silhouette
    var castle := Polygon2D.new()
    castle.polygon = PackedVector2Array([Vector2(0,0),Vector2(0,-190),Vector2(35,-190),Vector2(35,-245),Vector2(58,-245),Vector2(58,-190),Vector2(92,-190),Vector2(92,-290),Vector2(121,-290),Vector2(121,-190),Vector2(158,-190),Vector2(158,-240),Vector2(180,-240),Vector2(180,-190),Vector2(220,-190),Vector2(220,0)])
    castle.color = Color("#222a3a")
    castle.position = Vector2(810, 465)
    add_child(castle)
    # broken towers and gravestones
    for i in range(12):
        var stone := Polygon2D.new()
        var x := 100.0 + i * 110.0
        stone.polygon = PackedVector2Array([Vector2(-14,0),Vector2(-14,-30),Vector2(-9,-38),Vector2(9,-38),Vector2(14,-30),Vector2(14,0)])
        stone.color = Color("#414454") if i % 2 == 0 else Color("#34394a")
        stone.position = Vector2(x, 515 + float(i % 3) * 8)
        add_child(stone)
        if i % 3 == 0:
            var cross := Line2D.new()
            cross.points = PackedVector2Array([Vector2(x, 470), Vector2(x, 490)])
            cross.width = 3
            cross.default_color = Color("#686b7a")
            add_child(cross)
            var arm := Line2D.new()
            arm.points = PackedVector2Array([Vector2(x-8, 477), Vector2(x+8, 477)])
            arm.width = 3
            arm.default_color = Color("#686b7a")
            add_child(arm)
    # ground
    var ground := StaticBody2D.new()
    ground.position = Vector2(640, 650)
    var shape := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = Vector2(3000, 120)
    shape.shape = rect
    ground.add_child(shape)
    add_child(ground)
    var ground_visual := Polygon2D.new()
    ground_visual.polygon = PackedVector2Array([Vector2(-1600,-58),Vector2(1600,-58),Vector2(1600,70),Vector2(-1600,70)])
    ground_visual.color = Color("#292d39")
    ground_visual.position = Vector2(640, 650)
    add_child(ground_visual)
    var top_line := Line2D.new()
    top_line.points = PackedVector2Array([Vector2(-900,592),Vector2(2300,592)])
    top_line.width = 4
    top_line.default_color = Color("#656052")
    add_child(top_line)
    # raised platforms
    _add_platform(Vector2(390, 510), Vector2(190, 24))
    _add_platform(Vector2(720, 445), Vector2(170, 24))
    _add_platform(Vector2(1110, 520), Vector2(210, 24))
    # fire pits
    for fx in [300.0, 850.0, 1240.0]:
        var fire := Node2D.new()
        fire.position = Vector2(fx, 585)
        fire.set_script(load("res://scripts/fire.gd"))
        add_child(fire)

func _add_platform(pos: Vector2, size: Vector2) -> void:
    var body := StaticBody2D.new()
    body.position = pos
    var collision := CollisionShape2D.new()
    var rect := RectangleShape2D.new()
    rect.size = size
    collision.shape = rect
    body.add_child(collision)
    add_child(body)
    var visual := Polygon2D.new()
    visual.polygon = PackedVector2Array([Vector2(-size.x/2,-size.y/2),Vector2(size.x/2,-size.y/2),Vector2(size.x/2,size.y/2),Vector2(-size.x/2,size.y/2)])
    visual.color = Color("#4a4a52")
    visual.position = pos
    add_child(visual)
    var edge := Line2D.new()
    edge.points = PackedVector2Array([Vector2(pos.x-size.x/2,pos.y-size.y/2),Vector2(pos.x+size.x/2,pos.y-size.y/2)])
    edge.width = 3
    edge.default_color = Color("#9b7752")
    add_child(edge)

func _spawn_player() -> void:
    player = PLAYER_SCENE.instantiate()
    player.position = Vector2(140, 570)
    add_child(player)

func _spawn_enemies() -> void:
    _spawn_enemy("zombie", Vector2(430, 565), 1.0)
    _spawn_enemy("ghoul", Vector2(600, 565), 1.0)
    _spawn_enemy("armored", Vector2(820, 565), 1.0)
    _spawn_enemy("archer", Vector2(1050, 565), 1.0)
    _spawn_enemy("zombie", Vector2(1320, 565), 1.2)

func _spawn_enemy(kind: String, pos: Vector2, difficulty: float) -> void:
    var e = ENEMY_SCENE.instantiate()
    e.position = pos
    e.setup(kind, difficulty)
    add_child(e)

func _build_ui() -> void:
    hud = CanvasLayer.new()
    add_child(hud)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud.add_child(root)
    # top-left HUD
    var panel := PanelContainer.new()
    panel.position = Vector2(18, 16)
    panel.custom_minimum_size = Vector2(300, 120)
    root.add_child(panel)
    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    panel.add_child(vbox)
    status_label = Label.new()
    status_label.text = "KNIGHTFALL  |  LEVEL 1"
    status_label.add_theme_font_size_override("font_size", 18)
    vbox.add_child(status_label)
    health_bar = _make_bar(vbox, "HEALTH", Color("#b9334b"), 120)
    stamina_bar = _make_bar(vbox, "STAMINA", Color("#d6a64d"), 100)
    xp_bar = _make_bar(vbox, "XP", Color("#7b8fca"), 100)
    var gold_label := Label.new()
    gold_label.name = "GoldLabel"
    gold_label.text = "GOLD 0   |   POTIONS 3"
    gold_label.add_theme_font_size_override("font_size", 14)
    vbox.add_child(gold_label)
    toast_label = Label.new()
    toast_label.position = Vector2(400, 24)
    toast_label.size = Vector2(480, 40)
    toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    toast_label.add_theme_font_size_override("font_size", 22)
    toast_label.add_theme_color_override("font_color", Color("#f1d7a0"))
    root.add_child(toast_label)
    # boss bar at top center
    var boss_title := Label.new()
    boss_title.text = "THE UNDEAD KING"
    boss_title.position = Vector2(475, 16)
    boss_title.size = Vector2(330, 24)
    boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_title.add_theme_font_size_override("font_size", 18)
    root.add_child(boss_title)
    boss_bar = ProgressBar.new()
    boss_bar.position = Vector2(470, 42)
    boss_bar.size = Vector2(340, 16)
    boss_bar.max_value = 720
    boss_bar.value = 720
    boss_bar.show_percentage = false
    boss_bar.add_theme_stylebox_override("fill", _flat_style(Color("#9c263c")))
    boss_bar.add_theme_stylebox_override("background", _flat_style(Color("#251a24")))
    root.add_child(boss_bar)
    boss_title.visible = false
    boss_bar.visible = false
    boss_bar.set_meta("title_label", boss_title)
    # menu buttons
    var pause_button := Button.new()
    pause_button.text = "Ⅱ"
    pause_button.position = Vector2(1215, 18)
    pause_button.size = Vector2(48, 42)
    pause_button.pressed.connect(_toggle_pause)
    root.add_child(pause_button)
    var skill_button := Button.new()
    skill_button.text = "SKILLS"
    skill_button.position = Vector2(1080, 18)
    skill_button.size = Vector2(110, 42)
    skill_button.pressed.connect(_show_skills)
    root.add_child(skill_button)
    _build_touch_controls(root)
    _build_overlay_panels(root)
    _update_hud()

func _make_bar(parent: Node, title: String, color: Color, max_val: float) -> ProgressBar:
    var label := Label.new()
    label.text = title
    label.add_theme_font_size_override("font_size", 11)
    parent.add_child(label)
    var bar := ProgressBar.new()
    bar.custom_minimum_size = Vector2(265, 14)
    bar.max_value = max_val
    bar.value = max_val
    bar.show_percentage = false
    bar.add_theme_stylebox_override("fill", _flat_style(color))
    bar.add_theme_stylebox_override("background", _flat_style(Color("#242631")))
    parent.add_child(bar)
    return bar

func _flat_style(color: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.corner_radius_top_left = 3
    s.corner_radius_top_right = 3
    s.corner_radius_bottom_left = 3
    s.corner_radius_bottom_right = 3
    return s

func _build_touch_controls(root: Control) -> void:
    touch_controls = Control.new()
    touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(touch_controls)
    _touch_button("◀", Vector2(24, 590), Vector2(64, 64), func(down): player.mobile_left = down)
    _touch_button("▶", Vector2(96, 590), Vector2(64, 64), func(down): player.mobile_right = down)
    _touch_button("JUMP", Vector2(168, 590), Vector2(70, 64), func(down): player.mobile_jump = down)
    _touch_button("HIT", Vector2(1010, 590), Vector2(70, 64), func(down): player.mobile_light = down)
    _touch_button("HEAVY", Vector2(1086, 590), Vector2(76, 64), func(down): player.mobile_heavy = down)
    _touch_button("DODGE", Vector2(1168, 590), Vector2(76, 64), func(down): player.mobile_dodge = down)
    _touch_button("HEAL", Vector2(1086, 518), Vector2(76, 56), func(down): player.mobile_heal = down)

func _touch_button(caption: String, pos: Vector2, size: Vector2, callback: Callable) -> void:
    var b := Button.new()
    b.text = caption
    b.position = pos
    b.size = size
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 14)
    b.add_theme_color_override("font_color", Color("#f4e8d3"))
    b.add_theme_stylebox_override("normal", _flat_style(Color(0.12, 0.14, 0.2, 0.82)))
    b.add_theme_stylebox_override("pressed", _flat_style(Color(0.45, 0.17, 0.24, 0.95)))
    b.button_down.connect(func(): callback.call(true))
    b.button_up.connect(func(): callback.call(false))
    touch_controls.add_child(b)
    touch_buttons.append(b)

func _build_overlay_panels(root: Control) -> void:
    pause_panel = _overlay_panel(root, "PAUSED", ["RESUME", "RESTART"])
    pause_panel.visible = false
    var pause_vbox := pause_panel.get_child(0) as VBoxContainer
    pause_vbox.get_child(1).pressed.connect(_toggle_pause)
    pause_vbox.get_child(2).pressed.connect(_restart_game)

    death_panel = _overlay_panel(root, "YOU HAVE FALLEN", ["TRY AGAIN"])
    death_panel.visible = false
    (death_panel.get_child(0).get_child(1) as Button).pressed.connect(_restart_game)

    victory_panel = _overlay_panel(root, "THE KING HAS FALLEN", ["PLAY AGAIN"])
    victory_panel.visible = false
    (victory_panel.get_child(0).get_child(1) as Button).pressed.connect(_restart_game)

    skill_panel = _overlay_panel(root, "UPGRADE YOUR KNIGHT", ["+25 HEALTH", "+8 WEAPON DAMAGE", "CLOSE"])
    skill_panel.visible = false
    var sv := skill_panel.get_child(0) as VBoxContainer
    (sv.get_child(1) as Button).pressed.connect(func(): player.upgrade_health(); _show_toast("MAX HEALTH INCREASED"))
    (sv.get_child(2) as Button).pressed.connect(func(): player.upgrade_weapon(); _show_toast("WEAPON UPGRADED"))
    (sv.get_child(3) as Button).pressed.connect(func(): skill_panel.visible = false)

func _overlay_panel(root: Control, heading: String, buttons: Array[String]) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-190, -160)
    panel.custom_minimum_size = Vector2(380, 320)
    root.add_child(panel)
    var v := VBoxContainer.new()
    v.alignment = BoxContainer.ALIGNMENT_CENTER
    v.add_theme_constant_override("separation", 14)
    panel.add_child(v)
    var title := Label.new()
    title.text = heading
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    v.add_child(title)
    for caption in buttons:
        var b := Button.new()
        b.text = caption
        b.custom_minimum_size = Vector2(240, 44)
        v.add_child(b)
    return panel

func _update_hud() -> void:
    if not is_instance_valid(player) or health_bar == null:
        return
    health_bar.max_value = player.max_health
    health_bar.value = player.health
    stamina_bar.max_value = 100.0
    stamina_bar.value = player.stamina
    xp_bar.max_value = player.xp_to_next
    xp_bar.value = player.xp
    status_label.text = "KNIGHTFALL  |  LEVEL %d  |  POINTS %d" % [player.level, player.upgrade_points]
    var gold_label := get_node_or_null("CanvasLayer/Control/PanelContainer/VBoxContainer/GoldLabel")
    if gold_label:
        gold_label.text = "GOLD %d   |   POTIONS %d" % [player.gold, player.potions]

func _process(delta: float) -> void:
    world_time += delta
    if is_instance_valid(player) and player.global_position.x > 1480 and not boss_spawned:
        _spawn_boss()
    if is_instance_valid(player):
        player.stamina = minf(100.0, player.stamina + delta * (14.0 if not player.blocking else 5.0))
        if int(world_time * 2.0) % 2 == 0:
            pass
    if is_instance_valid(boss) and boss_bar:
        boss_bar.value = boss.health
    if boss_spawned and is_instance_valid(boss):
        var title_label = boss_bar.get_meta("title_label")
        title_label.visible = true
        boss_bar.visible = true
    if toast_label and toast_label.visible:
        toast_label.modulate.a = maxf(0.0, toast_label.modulate.a - delta * 0.25)
        if toast_label.modulate.a <= 0.0:
            toast_label.visible = false
    _update_hud()

func _spawn_boss() -> void:
    boss_spawned = true
    boss = BOSS_SCENE.instantiate()
    boss.position = Vector2(1710, 565)
    add_child(boss)
    boss.boss_defeated.connect(_on_boss_defeated)
    _show_toast("THE UNDEAD KING HAS AWAKENED")
    var title_label = boss_bar.get_meta("title_label")
    title_label.visible = true
    boss_bar.visible = true

func _on_boss_defeated() -> void:
    boss_dead = true
    boss_bar.visible = false
    boss_bar.get_meta("title_label").visible = false
    victory_panel.visible = true
    get_tree().paused = true

func _on_player_died() -> void:
    death_panel.visible = true
    get_tree().paused = true

func _on_level_up(new_level: int) -> void:
    _show_toast("LEVEL UP! LEVEL %d — SKILL POINT EARNED" % new_level)

func _show_toast(message: String) -> void:
    toast_label.text = message
    toast_label.modulate.a = 1.0
    toast_label.visible = true

func _toggle_pause() -> void:
    if get_tree().paused:
        get_tree().paused = false
        pause_panel.visible = false
        paused_by_menu = false
    else:
        get_tree().paused = true
        pause_panel.visible = true
        paused_by_menu = true

func _show_skills() -> void:
    skill_panel.visible = not skill_panel.visible
    if skill_panel.visible:
        get_tree().paused = true
    else:
        get_tree().paused = false

func _restart_game() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()
