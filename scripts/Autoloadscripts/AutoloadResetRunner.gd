extends Node

var names: Array = [
	"SettingsManager",
	"JsonData",
	"PlayerInventory",
	"SkillState",
	"SaveState",
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
	SkillState.reset()
	SaveState.reset()
	JsonData.reset()
	SettingsManager.reset()
	EntityAutoload.reset()
