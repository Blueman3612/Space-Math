extends Node

const RuntimeAPI = preload("res://addons/playcademy/sdk/apis/runtime_api.gd")

var _runtime_api

func _init(playcademy_client: JavaScriptObject):
	_runtime_api = RuntimeAPI.new(playcademy_client)

func exit():
	_runtime_api.exit() 