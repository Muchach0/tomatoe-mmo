# Quest Manager - Handles quest tracking and completion
#
# Usage:
#   AUTOMATIC ACTIVATION (Recommended):
#   1. Create a QuestResource (.tres file) in the editor
#   2. Configure the quest (type, targets, etc.)
#   3. Add the QuestManager node to your scene (add to "quest_manager" group for auto-discovery)
#   4. Assign the QuestResource to a MobSpawner's "quest_resource" export property
#   5. When a player enters the MobSpawner's Area2D, the quest will automatically activate!
#
#   MANUAL ACTIVATION:
#   1. Create a QuestResource (.tres file) in the editor
#   2. Configure the quest (type, targets, MobSpawners, etc.)
#   3. Add the QuestManager node to your scene
#   4. Call quest_manager.add_quest(quest_resource) to start tracking
#
# Example (Automatic):
#   - In editor: Assign quest_resource to MobSpawner node
#   - Quest activates when player enters spawner area
#
# Example (Manual):
#   var quest_manager = get_node("QuestManager")
#   var quest_res = preload("res://Resources/Quests/kill_10_orcs.tres")
#   var quest_id = quest_manager.add_quest(quest_res)
#   
#   # Listen for progress updates
#   EventBus.quest_progress_updated.connect(func(id, current, target):
#       print("Quest progress: ", current, "/", target)
#   )
#
class_name QuestManager
extends Node

signal quest_progress_updated(quest_id: String, quest_name: String, quest_resource: QuestResource, current_progress: int, target_progress: int)
signal quest_completed(quest_id: String, quest_resource: QuestResource)

var active_quests: Dictionary = {}  # quest_id -> QuestData
var completed_quests: Array[String] = []
var spawner_to_quest_ids: Dictionary = {}  # MobSpawner node -> Array[quest_id] mapping

# Internal quest data structure
class QuestData:
    var resource: QuestResource
    var current_progress: int = 0
    var target_progress: int = 0
    var mob_spawner_nodes: Array[Node] = []
    
    func _init(quest_res: QuestResource):
        resource = quest_res
        match quest_res.quest_type:
            QuestResource.QuestType.KILL_ENEMIES:
                target_progress = quest_res.target_count
            QuestResource.QuestType.PICKUP_ITEMS:
                target_progress = quest_res.target_count
            _:
                target_progress = 0

func _ready() -> void:
    # Add to quest_manager group for easy discovery
    add_to_group("quest_manager")
    
    # Connect to EventBus signals
    EventBus.one_enemy_die.connect(_on_enemy_died)
    EventBus.item_picked_up.connect(on_item_picked_up)

func add_quest(quest_resource: QuestResource, quest_id: String = "") -> String:
    """Add a quest to track. Returns the quest_id."""
    if quest_id.is_empty():
        quest_id = quest_resource.quest_name
    
    if quest_id in active_quests:
        return quest_id

    if quest_id in completed_quests:
        return quest_id
    
    var quest_data = QuestData.new(quest_resource)
    
    # Resolve MobSpawner node paths if they exist
    if not quest_resource.mob_spawners.is_empty():
        quest_data.mob_spawner_nodes = _resolve_mob_spawners(quest_resource.mob_spawners)
    
    active_quests[quest_id] = quest_data
    print("QuestManager - Added quest: %s (ID: %s)" % [quest_resource.quest_name, quest_id])
    EventBus.quest_activated.emit(quest_id, quest_resource.quest_name, quest_resource)
    return quest_id

func remove_quest(quest_id: String) -> void:
    """Remove a quest from tracking."""
    if quest_id in active_quests:
        # Clean up spawner mapping
        for spawner in spawner_to_quest_ids.keys():
            var quest_ids: Array[String] = spawner_to_quest_ids[spawner]
            if quest_ids.has(quest_id):
                quest_ids.erase(quest_id)
                # Remove spawner entry if no more quests
                if quest_ids.is_empty():
                    spawner_to_quest_ids.erase(spawner)
        
        active_quests.erase(quest_id)
        print("QuestManager - Removed quest: %s" % quest_id)

func get_quest_progress(quest_id: String) -> Dictionary:
    """Get current progress for a quest. Returns {current: int, target: int} or empty dict if not found."""
    if quest_id in active_quests:
        var quest_data = active_quests[quest_id]
        return {
            "current": quest_data.current_progress,
            "target": quest_data.target_progress
        }
    return {}

func activate_quest_from_spawner(quest_resource: QuestResource, spawner: Node) -> String:
    """Activate a quest when a player enters a MobSpawner's area. Returns the quest_id."""
    print("QuestManager - activate_quest_from_spawner() - Spawner: %s, Quest: %s" % [spawner.name, quest_resource.quest_name])
    
    # Check if this specific quest is already active for this spawner
    if spawner in spawner_to_quest_ids:
        var existing_quest_ids: Array = spawner_to_quest_ids[spawner]
        for existing_quest_id in existing_quest_ids:
            if existing_quest_id in active_quests:
                var existing_quest_data = active_quests[existing_quest_id]
                # Check if it's the same quest resource
                if existing_quest_data.resource == quest_resource or existing_quest_data.resource.quest_name == quest_resource.quest_name:
                    print("QuestManager - activate_quest_from_spawner() - Quest already active for this spawner: %s" % existing_quest_id)
                    return existing_quest_id
    
    # Check if quest is already active globally (by quest name or resource)
    var quest_id = _find_existing_quest_id(quest_resource)
    if quest_id.is_empty():
        # Create a new quest ID based on spawner and quest name
        quest_id = quest_resource.quest_name + "_" + str(spawner.get_instance_id())
    
    if quest_id in completed_quests:
        return ""

    # Ensure the spawner is in the quest's mob_spawners list
    var spawner_path = spawner.get_path()
    if not quest_resource.mob_spawners.has(spawner_path):
        quest_resource.mob_spawners.append(spawner_path)
    
    # Add the quest
    quest_id = add_quest(quest_resource, quest_id)
    
    # Link spawner to quest (support multiple quests per spawner)
    if spawner not in spawner_to_quest_ids:
        spawner_to_quest_ids[spawner] = []
    if not spawner_to_quest_ids[spawner].has(quest_id):
        spawner_to_quest_ids[spawner].append(quest_id)
    
    # Ensure the spawner is in the quest data's mob_spawner_nodes
    if quest_id in active_quests:
        var quest_data = active_quests[quest_id]
        if not quest_data.mob_spawner_nodes.has(spawner):
            quest_data.mob_spawner_nodes.append(spawner)
    
    var spawner_name_str: String = "Unknown"
    if spawner.has_method("get_spawner_name"):
        spawner_name_str = spawner.get_spawner_name()
    elif spawner.has_method("get") and spawner.get("name"):
        spawner_name_str = str(spawner.name)
    print("QuestManager - Activated quest '%s' from spawner '%s' (ID: %s)" % [quest_resource.quest_name, spawner_name_str, quest_id])
    
    return quest_id

func _find_existing_quest_id(quest_resource: QuestResource) -> String:
    """Find if a quest with the same resource is already active."""
    for quest_id in active_quests.keys():
        var quest_data = active_quests[quest_id]
        if quest_data.resource == quest_resource:
            return quest_id
        # Also check by name as fallback
        if quest_data.resource.quest_name == quest_resource.quest_name:
            return quest_id
    return ""

func _on_enemy_died(enemy_group_names: Array[StringName]) -> void:
    """Handle enemy death event from EventBus."""
    # if not multiplayer or not multiplayer.is_server():
    #     return
    print(multiplayer.get_unique_id(), "- QuestManager - _on_enemy_died() - Enemy died: %s" % enemy_group_names)
    for quest_id in active_quests.keys():
        var quest_data = active_quests[quest_id]
        
        if quest_data.resource.quest_type != QuestResource.QuestType.KILL_ENEMIES:
            continue
        
        # Check if this enemy should count for this quest
        if not _should_count_enemy_for_quest(quest_data, enemy_group_names):
            print(multiplayer.get_unique_id(), "- QuestManager - _on_enemy_died() - Enemy does not count for quest: %s" % quest_id)
            continue
        
        print(multiplayer.get_unique_id(), "- QuestManager - _on_enemy_died() - Enemy counts for quest: %s" % quest_id)
        quest_data.current_progress += 1
        quest_progress_updated.emit(quest_id, quest_data.resource.quest_name, quest_data.resource, quest_data.current_progress, quest_data.target_progress)
        EventBus.quest_progress_updated.emit(quest_id, quest_data.resource.quest_name, quest_data.resource, quest_data.current_progress, quest_data.target_progress)
        
        print("QuestManager - Quest '%s' progress: %d/%d" % [
            quest_data.resource.quest_name,
            quest_data.current_progress,
            quest_data.target_progress
        ])
        
        # Check if quest is completed
        if quest_data.current_progress >= quest_data.target_progress:
            _complete_quest(quest_id, quest_data)

func _should_count_enemy_for_quest(quest_data: QuestData, enemy_group_names: Array[StringName]) -> bool:
    """Check if an enemy should count towards a quest."""
    var resource = quest_data.resource
    # If quest has MobSpawners attached, only count enemies from those spawners
    if not quest_data.mob_spawner_nodes.is_empty():
        var should_count = false
        for spawner in quest_data.mob_spawner_nodes:
            if spawner and spawner.has_method("get") and spawner.get("spawner_name"):
                var spawner_name = spawner.get_spawner_name()
                if spawner_name in enemy_group_names:
                    should_count = true
                    break
        if not should_count:
            return false
    
    # If enemy_name_filter is set, check if it matches
    if not resource.enemy_name_filter.is_empty():
        # Check if the filter matches any group name
        var matches = false
        for group_name in enemy_group_names:
            if resource.enemy_name_filter in str(group_name):
                matches = true
                break
        if not matches:
            return false
    
    return true

func on_item_picked_up(item: Item, count: int = 1) -> void:
    """Handle item pickup event. Should be called when a player picks up an item."""
    # if not multiplayer or not multiplayer.is_server():
    #     return
    for quest_id in active_quests.keys():
        var quest_data = active_quests[quest_id]
        
        if quest_data.resource.quest_type != QuestResource.QuestType.PICKUP_ITEMS:
            continue
        # Check if this item should count for this quest
        if _should_count_item_for_quest(quest_data, item):
            quest_data.current_progress += count
            quest_progress_updated.emit(quest_id, quest_data.resource.quest_name, quest_data.resource, quest_data.current_progress, quest_data.target_progress)
            EventBus.quest_progress_updated.emit(quest_id, quest_data.resource.quest_name, quest_data.resource, quest_data.current_progress, quest_data.target_progress)
            
            print("QuestManager - Quest '%s' progress: %d/%d" % [
                quest_data.resource.quest_name,
                quest_data.current_progress,
                quest_data.target_progress
            ])
            
            # Check if quest is completed
            if quest_data.current_progress >= quest_data.target_progress:
                _complete_quest(quest_id, quest_data)
func _should_count_item_for_quest(quest_data: QuestData, item: Item) -> bool:
    """Check if an item should count towards a quest."""
    var resource = quest_data.resource
    
    # If target_item is null, count all items
    if resource.target_item == null:
        return true
    # Otherwise, check if the item matches
    return resource.target_item == item or (resource.target_item.item_name == item.item_name)

func _complete_quest(quest_id: String, quest_data: QuestData) -> void:
    """Mark a quest as completed."""
    if quest_id in completed_quests:
        return  # Already completed
    print(multiplayer.get_unique_id(), "- QuestManager - _complete_quest() - Quest completed: %s" % quest_id)
    print(multiplayer.get_unique_id(), "- QuestManager - _complete_quest() - Quest data: %s" % quest_data.resource.quest_name)

    completed_quests.append(quest_id)
    quest_completed.emit(quest_id, quest_data.resource.quest_name,quest_data.resource)
    EventBus.quest_completed.emit(quest_id, quest_data.resource.quest_name,quest_data.resource)
    
    print("QuestManager - Quest completed: %s" % quest_data.resource.quest_name)
    
    # Optionally remove from active quests (or keep it for tracking)
    active_quests.erase(quest_id)

func _resolve_mob_spawners(spawner_paths: Array[NodePath]) -> Array[Node]:
    """Resolve NodePaths to actual MobSpawner nodes."""
    var spawners: Array[Node] = []
    var scene_root = get_tree().current_scene
    
    if not scene_root:
        push_warning("QuestManager - Cannot resolve MobSpawners: no current scene")
        return spawners
    
    for path in spawner_paths:
        var node = scene_root.get_node_or_null(path)
        if node:
            spawners.append(node)
        else:
            push_warning("QuestManager - Could not find MobSpawner at path: %s" % path)
    
    return spawners
