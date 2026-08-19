extends Node
## Optional StoreKit facade — IAPManager is the primary integration point.

var _plugin: Object = null


func _ready() -> void:
	if OS.get_name() == "iOS" and Engine.has_singleton("StoreKit"):
		_plugin = Engine.get_singleton("StoreKit")
