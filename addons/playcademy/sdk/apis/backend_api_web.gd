extends Node

const BackendAPI = preload("res://addons/playcademy/sdk/apis/backend_api.gd")

# Signals for backend requests
signal request_succeeded(response_data: Dictionary)
signal request_failed(error_message: String)

var _backend_api

func _init(playcademy_client: JavaScriptObject):
	_backend_api = BackendAPI.new(playcademy_client)
	_backend_api.request_succeeded.connect(_on_original_request_succeeded)
	_backend_api.request_failed.connect(_on_original_request_failed)

func request(path: String, method: String = "GET", body: Dictionary = {}):
	_backend_api.request(path, method, body)

# Signal forwarding
func _on_original_request_succeeded(response_data):
	emit_signal("request_succeeded", response_data)

func _on_original_request_failed(error_message):
	emit_signal("request_failed", error_message)

