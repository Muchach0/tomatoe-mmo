extends Node


func _ready() -> void:
    EventBus.upgrade_touched_on_authority_player.connect(on_upgrade_touched_on_authority)

# This is only called by the player authority. We should then broadcast the upgrade to all other players.
func on_upgrade_touched_on_authority(upgrade_name: String, bullet_strategy: BulletStrategy, player_name: String) -> void:
    print("upgrade_manager.gd - on_upgrade_touched() - Upgrade touched: ", bullet_strategy)
    # Send a String over the network (prefer script global class name, fallback to script path)
    var script: Script = bullet_strategy.get_script()
    var identifier: String = script.get_global_name()
    if identifier == "":
        identifier = script.resource_path
    upgrade_touched_by_player_broadcast.rpc(upgrade_name, identifier, player_name)
    pass

@rpc("any_peer", "call_local", "reliable")
func upgrade_touched_by_player_broadcast(upgrade_name: String, upgrade_identifier: String, player_name: String) -> void:
    print("upgrade_manager.gd - upgrade_touched_by_player_broadcast() - Upgrade touched: '", upgrade_name, "' of type: ", upgrade_identifier, " by player: ", player_name)

    # Rebuild a BulletStrategy instance on each peer from the class name
    var bullet_strategy: BulletStrategy = _instantiate_strategy_from_class_name(upgrade_identifier)
    if bullet_strategy == null:
        push_error("upgrade_manager.gd - Unknown BulletStrategy identifier: %s" % upgrade_identifier)
        return


    EventBus.add_upgrade_to_player.emit(bullet_strategy, player_name)



    # if multiplayer != null and multiplayer.is_server():
    print("[SERVER]:upgrade_manager.gd - upgrade_touched_by_player_broadcast() - Deleting the upgrade '", upgrade_name, "' from the server")
    var upgrade_node = get_node_or_null(NodePath(upgrade_name))
    if upgrade_node == null:
        print("[SERVER]:upgrade_manager.gd - upgrade_touched_by_player_broadcast() - Upgrade node not found: ", upgrade_name)
        return
    upgrade_node.queue_free()  # Safe deletion
    print("[SERVER]: Player node %s removed." % upgrade_name)


# This is used to instantiate a BulletStrategy instance from a class name.
func _instantiate_strategy_from_class_name(strategy_class_name: String) -> BulletStrategy:
    var classes = ProjectSettings.get_global_class_list()
    for entry in classes:
        if entry is Dictionary and entry.get("class", "") == strategy_class_name:
            var path = entry.get("path", "")
            if path == "":
                continue
            var script = load(path)
            if script == null:
                continue
            return script.new()
    return null
