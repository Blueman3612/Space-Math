extends Node

signal balance_succeeded(balance: int)
signal balance_failed(error_message: String)
signal add_succeeded(new_balance: int)
signal add_failed(error_message: String)
signal spend_succeeded(new_balance: int)
signal spend_failed(error_message: String)

var _credits_api

func _init(inventory_api):
	_credits_api = CreditsAPI.new(inventory_api)
	_credits_api.balance_succeeded.connect(_on_original_balance_succeeded)
	_credits_api.balance_failed.connect(_on_original_balance_failed)
	_credits_api.add_succeeded.connect(_on_original_add_succeeded)
	_credits_api.add_failed.connect(_on_original_add_failed)
	_credits_api.spend_succeeded.connect(_on_original_spend_succeeded)
	_credits_api.spend_failed.connect(_on_original_spend_failed)

func balance():
	_credits_api.balance()

func add(amount: int):
	_credits_api.add(amount)

func spend(amount: int):
	_credits_api.spend(amount)

func _on_original_balance_succeeded(balance: int):
	emit_signal("balance_succeeded", balance)

func _on_original_balance_failed(error_message: String):
	emit_signal("balance_failed", error_message)

func _on_original_add_succeeded(new_balance: int):
	emit_signal("add_succeeded", new_balance)

func _on_original_add_failed(error_message: String):
	emit_signal("add_failed", error_message)

func _on_original_spend_succeeded(new_balance: int):
	emit_signal("spend_succeeded", new_balance)

func _on_original_spend_failed(error_message: String):
	emit_signal("spend_failed", error_message) 