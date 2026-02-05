extends Node

var names: Array = [
	"SettingsManager",
	"JsonData",
	"PlayerInventory",
	"Setting",
	"Logger",
	"MerchantRegistry",
	"EntityAutoload",
	"GlobalRNG",
]


func reset_all() -> void:
	GlobalRNG.reset()
	MerchantRegistry.reset()
	EntityAutoload.reset()
	Setting.reset()
	PlayerInventory.reset()
	JsonData.reset()
	SettingsManager.reset()
