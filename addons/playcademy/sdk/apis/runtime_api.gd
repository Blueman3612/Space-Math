class_name RuntimeAPI extends RefCounted

var _main_client: JavaScriptObject

func _init(client_js_object: JavaScriptObject):
	_main_client = client_js_object
	print("[RuntimeAPI] Initialized with client.")

func exit():
	if _main_client == null:
		printerr("[RuntimeAPI] Main client not set. Cannot call exit().")
		return

	if not ('runtime' in _main_client and _main_client.runtime is JavaScriptObject and 'exit' in _main_client.runtime):
		printerr("[RuntimeAPI] client.runtime.exit() path not found on JavaScriptObject.")
		return

	_main_client.runtime.exit()
