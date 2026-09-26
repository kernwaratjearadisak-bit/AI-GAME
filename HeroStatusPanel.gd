extends ColorRect

const MAX_HEROES := 4
const STAT_UPGRADE_COST: int = preload("res://Hero.gd").STAT_UPGRADE_COST
# ปุ่ม Tab ที่ i = Hero ที่ recruit_index == i (HeroTab0..3 ใน Main.tscn)
const TAB_COUNT := MAX_HEROES
# ดันข้อความบนปุ่ม Tab ขึ้น ให้ที่แถบ HP ขอบล่าง
const TAB_TEXT_BOTTOM_MARGIN := 22.0

enum TabState { EMPTY, ALIVE, SELECTED, DEAD }

const TAB_STYLE_COLORS := {
	TabState.EMPTY: [Color(0.16, 0.16, 0.16), Color(0.25, 0.25, 0.25), 2],
	TabState.ALIVE: [Color(0.22, 0.24, 0.3), Color(0.4, 0.42, 0.5), 2],
	# เหลือง = สีเดียวกับ SelectedIndicator เหนือหัว Hero
	TabState.SELECTED: [Color(0.2, 0.34, 0.6), Color(1.0, 0.85, 0.2), 4],
	TabState.DEAD: [Color(0.2, 0.2, 0.2), Color(0.3, 0.3, 0.3), 2],
}

@onready var atk_label: Label = $ATKLabel
@onready var hp_label: Label = $HPLabel
@onready var hp_max_label: Label = $HPMaxLabel
@onready var atk_speed_label: Label = $AttackSpeedLabel
@onready var heroes_label: Label = $HeroesLabel
@onready var str_label: Label = $STRLabel
@onready var vit_label: Label = $VITLabel
@onready var agi_label: Label = $AGILabel
@onready var def_label: Label = $DEFLabel
@onready var str_plus_button: Button = $STRPlusButton
@onready var vit_plus_button: Button = $VITPlusButton
@onready var agi_plus_button: Button = $AGIPlusButton
@onready var class_label: Label = $ClassLabel
@onready var skill_label: Label = $SkillLabel
@onready var recruit_warrior_button: Button = $RecruitWarriorButton
@onready var recruit_archer_button: Button = $RecruitArcherButton

var hero_tabs: Array[Button] = []
# state ล่าสุดของแต่ละ Tab — เปลี่ยน style เฉพาะตอน state เปลี่ยน ไม่สร้าง StyleBox ใหม่ทุกเฟรม
var tab_states: Array[int] = []
var tab_styles := {}


func _ready() -> void:
	recruit_warrior_button.pressed.connect(_on_recruit_pressed.bind(HeroClasses.HeroClass.WARRIOR))
	recruit_archer_button.pressed.connect(_on_recruit_pressed.bind(HeroClasses.HeroClass.ARCHER))
	str_plus_button.pressed.connect(_on_stat_plus_pressed.bind(&"strength"))
	vit_plus_button.pressed.connect(_on_stat_plus_pressed.bind(&"vitality"))
	agi_plus_button.pressed.connect(_on_stat_plus_pressed.bind(&"agility"))
	for state in TAB_STYLE_COLORS:
		tab_styles[state] = _make_tab_style(TAB_STYLE_COLORS[state][0], TAB_STYLE_COLORS[state][1], TAB_STYLE_COLORS[state][2])
	for i in TAB_COUNT:
		var tab: Button = get_node("HeroTab%d" % i)
		tab.pressed.connect(_on_hero_tab_pressed.bind(i))
		hero_tabs.append(tab)
		tab_states.append(-1)


func _process(_delta: float) -> void:
	_update_hero_tabs()
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader:
		class_label.text = "Class: %s" % HeroClasses.get_config(leader.hero_class)["display_name"]
		hp_label.text = "HP: %.2f/%.2f" % [leader.hp, leader.max_hp]
		# ค่าจริงหลังคิด stat แล้ว (สูตรใน CombatStats.gd) — attack_interval คิด class + AGI แล้ว
		atk_label.text = "ATK: %.2f" % CombatStats.get_damage_output(leader.attack_damage, leader.strength)
		hp_max_label.text = "HP Max: %.2f" % leader.max_hp
		atk_speed_label.text = "Attack interval: %.2fs" % leader.attack_interval
		def_label.text = "DEF: %.2f%%" % (CombatStats.get_damage_reduction(leader.vitality) * 100.0)
		str_label.text = "STR: %d" % leader.strength
		vit_label.text = "VIT: %d" % leader.vitality
		agi_label.text = "AGI: %d" % leader.agility
		skill_label.text = _get_skill_text(leader.skills)

	# ไม่มี leader หรือ coin กองกลางไม่พอ = กดไม่ได้
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	var can_upgrade: bool = leader != null and hero_party != null and hero_party.can_afford(STAT_UPGRADE_COST)
	str_plus_button.disabled = not can_upgrade
	vit_plus_button.disabled = not can_upgrade
	agi_plus_button.disabled = not can_upgrade

	# MAX_HEROES นับรวมทุก class — ครบแล้ว disable ทั้งสองปุ่ม
	var hero_count := get_tree().get_nodes_in_group("heroes").size()
	var is_full := hero_count >= MAX_HEROES
	if is_full:
		heroes_label.text = "Heroes: %d/%d (Max)" % [hero_count, MAX_HEROES]
	else:
		heroes_label.text = "Heroes: %d/%d" % [hero_count, MAX_HEROES]
	recruit_warrior_button.disabled = is_full
	recruit_archer_button.disabled = is_full


# "Bash: 12s   Regen: Active (3/5)" / "Charge: Charging…   Push: 2/3" — class ที่ไม่มี skill แสดง "Skill: —"
func _get_skill_text(skills: HeroSkills) -> String:
	if not skills.has_skills():
		return "Skill: —"
	var parts: Array[String] = []
	for skill_id in skills.skill_ids:
		var skill_name: String = SkillData.get_config(skill_id)["short_name"]
		var cooldown := skills.get_cooldown(skill_id)
		var active_status := skills.get_active_status(skill_id)
		if active_status != "":
			parts.append("%s: %s" % [skill_name, active_status])
		elif cooldown > 0.0:
			parts.append("%s: %ds" % [skill_name, ceili(cooldown)])
		else:
			parts.append("%s: Ready" % skill_name)
	return "   ".join(parts)


# อ่านใหม่ทุกเฟรม — Hero ที่เพิ่ง recruit / ตาย / ฟื้นตอน reset stage อัปเดตทันที
func _update_hero_tabs() -> void:
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	for i in TAB_COUNT:
		var tab := hero_tabs[i]
		var hero: Node2D = hero_party.get_hero_by_index(i) if hero_party else null
		var fill: ColorRect = tab.get_node("HPBarBack/HPBarFill")
		var bar_width: float = tab.get_node("HPBarBack").size.x
		var state: int
		if hero == null:
			state = TabState.EMPTY
			tab.text = "—"
			fill.size.x = 0.0
		else:
			if hero.hp <= 0:
				state = TabState.DEAD
			elif hero.is_selected:
				state = TabState.SELECTED
			else:
				state = TabState.ALIVE
			tab.text = "Hero %d (%s)" % [i + 1, HeroClasses.get_config(hero.hero_class)["short_name"]]
			fill.size.x = bar_width * clampf(hero.hp / hero.max_hp, 0.0, 1.0)
		tab.disabled = state == TabState.EMPTY or state == TabState.DEAD
		if state != tab_states[i]:
			tab_states[i] = state
			_apply_tab_style(tab, tab_styles[state])


func _make_tab_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.content_margin_bottom = TAB_TEXT_BOTTOM_MARGIN
	return style


# ใช้ style เดียวกันทุกสถานะของปุ่ม — สีบอกสถานะ Hero ไม่ใช่สถานะเมาส์ (DEAD/EMPTY สีตัวอักษรเทาจาก disabled)
func _apply_tab_style(tab: Button, style: StyleBoxFlat) -> void:
	for style_name in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		tab.add_theme_stylebox_override(style_name, style)


func _on_hero_tab_pressed(index: int) -> void:
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	var hero: Node2D = hero_party.get_hero_by_index(index) if hero_party else null
	if hero and hero.hp > 0:
		hero.select()


func _on_recruit_pressed(hero_class: HeroClasses.HeroClass) -> void:
	var hero_party := get_tree().get_first_node_in_group("hero_party")
	if hero_party:
		hero_party.recruit_hero(hero_class)


# อัป stat ของ Hero ที่ถูกเลือก ด้วย coin กองกลาง — logic อยู่ใน Hero.try_upgrade_stat()
func _on_stat_plus_pressed(stat_name: StringName) -> void:
	var leader := get_tree().get_first_node_in_group("party_leader")
	if leader:
		leader.try_upgrade_stat(stat_name)

# TODO: upgrade buttons จะมาทีหลัง
