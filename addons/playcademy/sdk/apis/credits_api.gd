class_name CreditsAPI extends RefCounted

# Signals for credits operations
signal balance_succeeded(balance: int)
signal balance_failed(error_message: String)
signal add_succeeded(new_balance: int)
signal add_failed(error_message: String)
signal spend_succeeded(new_balance: int)
signal spend_failed(error_message: String)

var _users_api
var _cached_credits_item_id: String = ""

# Constants - should match @playcademy/data/constants
const PLAYCADEMY_CREDITS_SLUG = "PLAYCADEMY_CREDITS"

func _init(users_api):
	_users_api = users_api
	
	# Connect to users.inventory signals to handle our operations
	_users_api.inventory_get_all_succeeded.connect(_on_inventory_get_all_succeeded)
	_users_api.inventory_get_all_failed.connect(_on_inventory_get_all_failed)
	_users_api.inventory_add_succeeded.connect(_on_inventory_add_succeeded)
	_users_api.inventory_add_failed.connect(_on_inventory_add_failed)
	_users_api.inventory_remove_succeeded.connect(_on_inventory_remove_succeeded)
	_users_api.inventory_remove_failed.connect(_on_inventory_remove_failed)

# Track what operation we're currently performing
enum Operation {
	NONE,
	BALANCE,
	ADD,
	SPEND
}

var _current_operation: Operation = Operation.NONE
var _pending_add_amount: int = 0
var _pending_spend_amount: int = 0

# Gets the current balance of Playcademy Credits
func balance():
	_current_operation = Operation.BALANCE
	_users_api.inventory_get_all()

# Adds Playcademy Credits to the user's inventory
func add(amount: int):
	if amount <= 0:
		emit_signal("add_failed", "Amount must be positive")
		return
	
	_current_operation = Operation.ADD
	_pending_add_amount = amount
	
	if _cached_credits_item_id.is_empty():
		# Need to get inventory first to find credits item ID
		_users_api.inventory_get_all()
	else:
		# We have the ID cached, add directly
		_users_api.inventory_add(_cached_credits_item_id, amount)

# Spends (removes) Playcademy Credits from the user's inventory
func spend(amount: int):
	if amount <= 0:
		emit_signal("spend_failed", "Amount must be positive")
		return
	
	_current_operation = Operation.SPEND
	_pending_spend_amount = amount
	
	if _cached_credits_item_id.is_empty():
		# Need to get inventory first to find credits item ID
		_users_api.inventory_get_all()
	else:
		# We have the ID cached, remove directly
		_users_api.inventory_remove(_cached_credits_item_id, amount)

# Handle inventory get_all success
func _on_inventory_get_all_succeeded(inventory_data: Array):
	var credits_balance = 0
	var found_credits_item = false
	
	# Find the Playcademy Credits item
	for item_entry in inventory_data:
		if item_entry is Dictionary and item_entry.has("item"):
			var item = item_entry.get("item")
			if item is Dictionary and item.has("slug"):
				if item.get("slug") == PLAYCADEMY_CREDITS_SLUG:
					found_credits_item = true
					credits_balance = item_entry.get("quantity", 0)
					
					# Cache the item ID for future operations
					if item.has("id"):
						_cached_credits_item_id = str(item.get("id"))
					
					break
	
	if not found_credits_item:
		var error_msg = "Playcademy Credits item not found in inventory"
		match _current_operation:
			Operation.BALANCE:
				emit_signal("balance_failed", error_msg)
			Operation.ADD:
				emit_signal("add_failed", error_msg)
			Operation.SPEND:
				emit_signal("spend_failed", error_msg)
		_current_operation = Operation.NONE
		return
	
	# Handle the specific operation
	match _current_operation:
		Operation.BALANCE:
			emit_signal("balance_succeeded", credits_balance)
			_current_operation = Operation.NONE
		
		Operation.ADD:
			if _cached_credits_item_id.is_empty():
				emit_signal("add_failed", "Credits item ID not found")
				_current_operation = Operation.NONE
				return
			_users_api.inventory_add(_cached_credits_item_id, _pending_add_amount)
			# Don't reset operation yet - wait for add result
		
		Operation.SPEND:
			if _cached_credits_item_id.is_empty():
				emit_signal("spend_failed", "Credits item ID not found")
				_current_operation = Operation.NONE
				return
			if credits_balance < _pending_spend_amount:
				emit_signal("spend_failed", "Insufficient credits")
				_current_operation = Operation.NONE
				return
			_users_api.inventory_remove(_cached_credits_item_id, _pending_spend_amount)
			# Don't reset operation yet - wait for remove result

func _on_inventory_get_all_failed(error_message: String):
	match _current_operation:
		Operation.BALANCE:
			emit_signal("balance_failed", "Failed to get inventory: " + error_message)
		Operation.ADD:
			emit_signal("add_failed", "Failed to get inventory: " + error_message)
		Operation.SPEND:
			emit_signal("spend_failed", "Failed to get inventory: " + error_message)
	_current_operation = Operation.NONE

func _on_inventory_add_succeeded(response_data):
	if _current_operation == Operation.ADD:
		var new_total = 0
		if response_data is Dictionary and response_data.has("newTotal"):
			new_total = response_data.get("newTotal", 0)
		
		emit_signal("add_succeeded", new_total)
		_current_operation = Operation.NONE
		_pending_add_amount = 0

func _on_inventory_add_failed(error_message: String):
	if _current_operation == Operation.ADD:
		emit_signal("add_failed", "Failed to add credits: " + error_message)
		_current_operation = Operation.NONE
		_pending_add_amount = 0

func _on_inventory_remove_succeeded(response_data):
	if _current_operation == Operation.SPEND:
		var new_total = 0
		if response_data is Dictionary and response_data.has("newTotal"):
			new_total = response_data.get("newTotal", 0)
		
		emit_signal("spend_succeeded", new_total)
		_current_operation = Operation.NONE
		_pending_spend_amount = 0

func _on_inventory_remove_failed(error_message: String):
	if _current_operation == Operation.SPEND:
		emit_signal("spend_failed", "Failed to spend credits: " + error_message)
		_current_operation = Operation.NONE
		_pending_spend_amount = 0 