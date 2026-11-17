class_name CyberOpsPanel
extends Modal
## Hacking operations against the Eastern Theater, paid for with research points.

signal run(op: String)

var st: GameState
var _rows := {}
var _rp: Label


func _init(p_state: GameState) -> void:
	super(Vector2(760, 0))
	st = p_state
	var head := HBoxContainer.new()
	var t := UITheme.label("CYBER OPERATIONS", 26, Color(0.75, 1.0, 0.45), UITheme.font_bold)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_rp = UITheme.label("", 16, Color(0.6, 0.75, 1.0), UITheme.font_bold)
	head.add_child(_rp)
	content.add_child(head)
	var sub := UITheme.label("Signals Directorate, basement level 3. Every operation costs research points the labs would rather spend on actual research.", 13, UITheme.TEXT_DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(700, 0)
	content.add_child(sub)
	for op in Lore.OPS:
		var d: Dictionary = Lore.OPS[op]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.box(Color(0.03, 0.08, 0.05, 0.95), Color(0.75, 1.0, 0.45, 0.35), 1, 6, Vector4(14, 10, 12, 10)))
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 12)
		card.add_child(hb)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 1)
		vb.add_child(UITheme.label(d["name"], 17, UITheme.TEXT, UITheme.font_bold))
		vb.add_child(UITheme.label(d["ticket"], 11, Color(0.75, 1.0, 0.45, 0.8)))
		var desc := UITheme.label(d["desc"], 13, UITheme.TEXT_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(520, 0)
		vb.add_child(desc)
		var status := UITheme.label("", 12, Defs.WARN)
		vb.add_child(status)
		hb.add_child(vb)
		var right := VBoxContainer.new()
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		var cost := UITheme.label("%d RP" % int(d["cost"]), 15, Color(0.6, 0.75, 1.0), UITheme.font_bold)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(cost)
		var b := UITheme.button("Run", 90, 36)
		b.pressed.connect(func():
			run.emit(op)
			refresh())
		right.add_child(b)
		hb.add_child(right)
		content.add_child(card)
		_rows[op] = {"button": b, "status": status}
	var done := UITheme.button("Close  [O]", 160, 38)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func(): Audio.play("click"); close())
	content.add_child(done)
	refresh()


func refresh() -> void:
	_rp.text = "%d RP available" % st.rp
	for op in _rows:
		var reason := st.story.op_check(st, op)
		_rows[op]["button"].disabled = reason != ""
		_rows[op]["status"].text = reason


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_O:
		get_viewport().set_input_as_handled()
		close()
