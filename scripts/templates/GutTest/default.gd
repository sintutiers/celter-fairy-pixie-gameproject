# meta-name: SPDX GUT test
# meta-description: GUT test w/ EUPL-1.2 SPDX header + setup/teardown hooks
# meta-default: true
# SPDX-FileCopyrightText: 2026 Dean Henny Anton Lemans <deanlemans@mailbox.org>
# SPDX-License-Identifier: EUPL-1.2
extends _BASE_


#region Setup/Teardown
func before_all() -> void:
	pass


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func after_all() -> void:
	pass
#endregion


#region Tests
func test_pending() -> void:
	pending()
#endregion
