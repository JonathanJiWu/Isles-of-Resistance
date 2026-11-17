class_name ResearchPanel
extends Modal
## The technology tree.

signal research(tech_id: String)

const CARD := Vector2(318, 92)
const GAP := Vector2(54, 12)

var st: GameState
var _rp_label: Label
var _tree: Control
var _cards := {}


func _init(p_state: GameState) -> void:
	super(Vector2(1110, 0))
	st = p_state
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	var t := UITheme.label("RESEARCH & DEVELOPMENT", 26, UITheme.ACCENT, UITheme.font_bold)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_rp_label = UITheme.label("", 18, Color(0.6, 0.75, 1.0), UITheme.font_bold)
	head.add_child(_rp_label)
	var close_b := UITheme.button("Close  [R]", 0, 34)
	close_b.pressed.connect(func(): Audio.play("click"); close())
	head.add_child(close_b)
	content.add_child(head)
	var sub := UITheme.label("Unlock new defenses and upgrades. Research points are produced by your Capital and Research Labs each turn.", 13, UITheme.TEXT_DIM)
	content.add_child(sub)
	_tree = Control.new()
	_tree.custom_minimum_size = Vector2(3 * CARD.x + 2 * GAP.x + 20, 6 * CARD.y + 5 * GAP.y + 10)
	_tree.draw.connect(_draw_links)
	content.add_child(_tree)
	for id in Defs.TECHS:
		var def: Dictionary = Defs.TECHS[id]
		var card := _make_card(id)
		card.position = Vector2(10 + def["tier"] * (CARD.x + GAP.x), 4 + def["row"] * (CARD.y + GAP.y))
		_tree.add_child(card)
	refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R:
		get_viewport().set_input_as_handled()
		close()


func _make_card(id: String) -> PanelContainer:
	var def: Dictionary = Defs.TECHS[id]
	var p := PanelContainer.new()
	p.custom_minimum_size = CARD
	p.size = CARD
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	p.add_child(hb)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	var name_l := UITheme.label(def["name"], 15, UITheme.TEXT, UITheme.font_bold)
	vb.add_child(name_l)
	var desc := UITheme.label(def["desc"], 12, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(200, 0)
	vb.add_child(desc)
	hb.add_child(vb)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	var cost := UITheme.label("%d RP" % def["cost"], 14, Color(0.6, 0.75, 1.0), UITheme.font_bold)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(cost)
	var b := UITheme.button("Research", 82, 30)
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(func(): research.emit(id))
	right.add_child(b)
	hb.add_child(right)
	_cards[id] = {"panel": p, "button": b, "name": name_l, "cost": cost}
	return p


func refresh() -> void:
	_rp_label.text = "%d RP  (+%d/turn)" % [st.rp, st.rp_income()]
	for id in _cards:
		var c: Dictionary = _cards[id]
		var status := st.tech_status(id)
		var p: PanelContainer = c["panel"]
		var b: Button = c["button"]
		match status:
			"done":
				p.add_theme_stylebox_override("panel", UITheme.box(Color(0.07, 0.24, 0.25, 0.97), UITheme.ACCENT, 2, 7, Vector4(12, 8, 10, 8)))
				b.text = "Done"
				b.disabled = true
				c["name"].add_theme_color_override("font_color", UITheme.ACCENT)
			"available":
				var ok: bool = st.rp >= Defs.TECHS[id]["cost"]
				p.add_theme_stylebox_override("panel", UITheme.box(Color(0.07, 0.11, 0.17, 0.97), UITheme.ACCENT if ok else UITheme.BORDER, 1, 7, Vector4(12, 8, 10, 8)))
				b.text = "Research"
				b.disabled = not ok
				b.tooltip_text = "" if ok else "Not enough research points"
				c["name"].add_theme_color_override("font_color", UITheme.TEXT)
			"locked":
				p.add_theme_stylebox_override("panel", UITheme.box(Color(0.04, 0.06, 0.09, 0.9), Color(0.2, 0.25, 0.3, 0.6), 1, 7, Vector4(12, 8, 10, 8)))
				b.text = "Locked"
				b.disabled = true
				b.tooltip_text = st.research_check(id)
				c["name"].add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_tree.queue_redraw()


func _draw_links() -> void:
	for id in Defs.TECHS:
		var def: Dictionary = Defs.TECHS[id]
		var to: PanelContainer = _cards[id]["panel"]
		for r in def["req"]:
			var from: PanelContainer = _cards[r]["panel"]
			var a := from.position + Vector2(CARD.x, CARD.y * 0.5)
			var b := to.position + Vector2(0, CARD.y * 0.5)
			var col := UITheme.ACCENT if st.has_tech(r) else Color(0.3, 0.38, 0.45, 0.7)
			var mid := (a.x + b.x) * 0.5
			_tree.draw_polyline(PackedVector2Array([a, Vector2(mid, a.y), Vector2(mid, b.y), b]), col, 2.0, true)
			_tree.draw_circle(b, 3.5, col)
