extends CanvasLayer
## Pause menu: Esc interrupts the game, offers resume or quit.
## Always processes, not just-when-paused — see docs/padroes/arquitetura.md.

## Built in code, not its own scene — born from a single station node.
const PANEL_MARGIN: int = 24
const BUTTON_GAP: int = 12
const BUTTON_WIDTH: int = 220

## The game's only large-size text. See docs/arquitetura/interface-e-camera.md.
const SIZE: int = Fonts.LARGE

var _background: ColorRect
var _resume_button: Button
var _quit_button: Button


func _ready() -> void:
	layer = 100
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		resume()
	else:
		pause()


func pause() -> void:
	visible = true
	get_tree().paused = true
	_resume_button.grab_focus()


func resume() -> void:
	visible = false
	get_tree().paused = false


func quit() -> void:
	get_tree().quit()


# --- UI assembly -------------------------------------------------------------

func _build() -> void:
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = Color(0, 0, 0, 0.6)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_background)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side: StringName in [
		&"theme_override_constants/margin_left",
		&"theme_override_constants/margin_top",
		&"theme_override_constants/margin_right",
		&"theme_override_constants/margin_bottom",
	]:
		margin.set(side, PANEL_MARGIN)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.set(&"theme_override_constants/separation", BUTTON_GAP)
	margin.add_child(column)

	_resume_button = _build_button("Voltar ao jogo", resume)
	column.add_child(_resume_button)

	_quit_button = _build_button("Sair do jogo", quit)
	column.add_child(_quit_button)


func _build_button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.add_theme_font_size_override(&"font_size", SIZE)
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, 0)
	button.pressed.connect(action)
	return button
