# Event bus to communicate between nodes
extends Node

signal player_hit
signal player_died
signal respawn_player
signal star_touched
signal add_player # Signal to synchronize player data across peers when a new player connects
signal remove_player # Signal to remove player data across peers when a player disconnects
signal set_player_node_name_and_init_position # Signal to set the player node name for synchronization

signal bullets_init_and_start # Signal sent on server to spawn bullets (the server is running the randomization and send to clients)
signal start_level # Signal to update the UI with the current level and number of bullets (sent from server)

signal is_server_running_a_busy_round # Signal to indicate if a game is currently running - UI will display the label accordingly

# UI related signals
signal is_server_label_visible # Signal to notify the UI that the server label should be visible or not
signal game_over_screen_text_and_visibility # Signal to notify the UI that the game over screen text and visibility should be updated
signal update_wave_ui # Signal to notify the UI that the wave number and enemy count should be updated
signal restart_button_pressed # Signal to notify the UI that the restart button has been pressed
signal wave_cleared # Signal to notify the UI that the wave has been cleared

# Signal linked to bonus
signal bonus_touched # Signal to notify the game logic that a player touched a bonus
signal bonus_used # Signal to notify the game logic that a player used a bonus
signal sync_bonus_count # Signal to notify the UI that a player touched a bonus


# AI Test
signal ai_test_button_pressed # Signal to notify the AI manager that the AI test button has been pressed
signal ai_response_received # Signal to notify the UI that the AI has responded
signal ai_request_failed # Signal to notify the UI that the AI request has failed


# Audio related signals
signal audio_explosion_play # Signal to notify the UI that the audio explosion should be played
signal audio_win_play # Signal to notify the UI that the audio win should be played


# Signal linked to upgrades
signal upgrade_touched_on_authority_player # Signal to notify the game logic that a player touched an upgrade
signal add_upgrade_to_player # Signal to notify the game logic that a player should add an upgrade to their bullet strategies


# Enemy handling
signal one_enemy_die # Signal to notify the game logic that an enemy has died
signal update_score # Signal to notify the game logic that the score should be updated


# Level selection related signals
signal level_selected # Signal to notify the game logic that a level has been selected
signal level_started # Signal to notify the game logic that the level should be started


# Signal related to zones (for visibility handling)
signal zone_touched # Signal to notify the game logic that a zone has been touched
signal refresh_visibility # Signal to notify the game logic that the visibility should be refreshed