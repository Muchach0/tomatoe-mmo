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


# Quest completion rewards (optional)
@export var reward_description: String = ""

# Reward: Experience points
@export var reward_experience: int = 0

# Reward: Gold
@export var reward_gold: int = 0

# Reward: Guaranteed items (0 or several items)
# Each dictionary should have "item": Item and "count": int
@export var reward_items: Array[Dictionary] = []

# Reward: Choice items (player can choose one from this list)
# Each dictionary should have "item": Item and "count": int
@export var reward_choice_items: Array[Dictionary] = [] 


# MobSpawner attachment (0 or many)
var mob_spawners: Array[NodePath] = []  # Paths to MobSpawner nodes in the scene

func _init():
    quest_name = "New Quest"
    quest_description = "Quest description"
    quest_type = QuestType.KILL_ENEMIES
    target_count = 10
    enemy_name_filter = ""
    target_item = null
    mob_spawners = []
    reward_description = ""
    reward_experience = 0
    reward_gold = 0
    reward_items = []
    reward_choice_items = []
