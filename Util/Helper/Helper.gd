# Helper functions for the game
extends Node


func get_players_id_in_current_world(current_world: String) -> Array:
    var players_id_in_current_world: Array = []
    for player_id in EventBus.players:
        if EventBus.players[player_id]["current_world"] == current_world:
            players_id_in_current_world.append(player_id)
    return players_id_in_current_world


func find_player_by_peer_id(peer_id: int) -> Player:
    for player in get_tree().get_nodes_in_group("Player"):
        if player.peer_id == peer_id:
            return player
    return null