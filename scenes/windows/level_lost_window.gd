@tool
extends PopupWindowPanel

signal restart_pressed
signal main_menu_pressed

func _ready() -> void:
	super._ready()
	if OS.has_feature("web"):
		%ExitButton.hide()

func _on_exit_button_pressed():
	%ExitConfirmation.show()

func _on_main_menu_button_pressed():
	%MainMenuConfirmation.show()

func _on_close_button_pressed():
	_unpause_on_close()
	restart_pressed.emit()
	close()

func _on_main_menu_confirmation_confirmed():
	_unpause_on_close()
	main_menu_pressed.emit()
	close()

func _on_exit_confirmation_confirmed():
	get_tree().quit()

# close() puts back pause state from when window opened. Dying with console open
# ("sanity 0") records paused, so restarted level would stay frozen.
func _unpause_on_close() -> void:
	_initial_pause_state = false
