# Quest Resource - Configurable quest data
class_name QuestResource
extends Resource

enum QuestType {
	KILL_ENEMIES,
	PICKUP_ITEMS
}

@export var quest_name: String = "New Quest"
@export var quest_description: String = "Quest description"
@export var quest_type: QuestType = QuestType.KILL_ENEMIES

# For KILL_ENEMIES quests
@export var enemy_name_filter: String = ""  # If empty, counts all enemies. Otherwise filters by enemy name or spawner name

# For PICKUP_ITEMS quests
@export var target_item: Item = null  # If null, counts all items. Otherwise filters by specific item

# For KILL_ENEMIES and PICKUP_ITEMS quests
@export var target_count: int = 10

# MobSpawner attachment (0 or many)
@export var mob_spawners: Array[NodePath] = []  # Paths to MobSpawner nodes in the scene

# Quest completion rewards (optional)
@export var reward_description: String = ""

func _init():
	quest_name = "New Quest"
	quest_description = "Quest description"
	quest_type = QuestType.KILL_ENEMIES
	target_count = 10
	enemy_name_filter = ""
	target_item = null
	mob_spawners = []
	reward_description = ""


