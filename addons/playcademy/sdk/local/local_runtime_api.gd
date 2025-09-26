extends Node

class_name LocalRuntimeAPI

# No signals needed now; could add exit_succeeded/failed later

var _base_url: String

func _init(base_url: String):
	_base_url = base_url.rstrip("/")

func exit():
	print("[LocalRuntimeAPI] exit() called in local dev mode. Attempting to notify sandbox and close game window.")
	# Attempt to notify sandbox (non-blocking)
	var http := HTTPRequest.new()
	add_child(http)
	# Not connecting a callback; fire and forget
	http.request("%s/runtime/exit" % _base_url, PackedStringArray(), HTTPClient.METHOD_POST, "")
	# Then close the game window
	get_tree().quit() 