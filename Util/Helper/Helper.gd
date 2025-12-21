# Helper functions for the game
extends Node


func get_players_id_in_current_world(current_world: String) -> Array:
    var players_id_in_current_world: Array = []
    for player_id in EventBus.players:
        if EventBus.players[player_id]["current_world"] == current_world:
            players_id_in_current_world.append(player_id)
    return players_id_in_current_world
