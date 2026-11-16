extends Control

@onready var _save_file_dialog: FileDialog = %SaveFileDialog
@onready var _save_data_status_label: Label = %SaveDataStatusLabel


func _on_ResetGameControl_reset_confirmed() -> void:
	GameState.reset()


func _on_export_save_button_pressed() -> void:
	_save_file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_file_dialog.current_file = "save.json"
	_save_file_dialog.popup_centered_ratio()


func _on_import_save_button_pressed() -> void:
	_save_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_save_file_dialog.popup_centered_ratio()


# One dialog for both buttons, its mode tells which one opened it.
func _on_save_file_dialog_file_selected(path: String) -> void:
	if _save_file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		var error: Error = GameState.export_save(path)
		_save_data_status_label.text = "Exported to %s" % path if error == OK else "Could not export: %s" % error_string(error)
		return
	if not GameState.import_save(path):
		_save_data_status_label.text = "%s is not a save file" % path.get_file()
		return
	# Same as reset: scene reloads, so player and menus read imported save.
	get_tree().paused = false
	get_tree().reload_current_scene()
