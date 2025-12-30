extends Node

# Audio Manager to handle all game sounds
# Game logic should use EventBus signals to trigger sounds
# Configure sounds in the Inspector by assigning AudioStream resources

# Sound effect resources - assign in Inspector
@export var sound_explosion: AudioStream
@export var sound_pickup_coin: AudioStream
@export var sound_bonus_pickup: AudioStream
@export var sound_bonus_used: AudioStream
@export var sound_laser_shoot: AudioStream
@export var sound_hit: AudioStream
@export var sound_win: AudioStream  # Optional win sound
@export var sound_level_up: AudioStream  # Optional level up sound
@export var sound_wave_cleared: AudioStream  # Optional wave cleared sound
@export var sound_enemy_die: AudioStream # Optional enemy die sound

# Background music resource - assign in Inspector
@export var music_background: AudioStream

# Audio player nodes (created dynamically if not in scene)
var music_player: AudioStreamPlayer
var sound_effects_container: Node

# Pool of AudioStreamPlayer nodes for sound effects (allows multiple sounds simultaneously)
var sound_effect_pool: Array[AudioStreamPlayer] = []
const MAX_POOL_SIZE = 10  # Maximum number of simultaneous sound effects

# Volume settings - configure in Inspector
@export_range(0.0, 1.0, 0.01) var master_volume: float = 1.0
@export_range(0.0, 1.0, 0.01) var music_volume: float = 0.7
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = 1.0

# Shooting sound cooldown - configure in Inspector (seconds between shots)
@export_range(0.0, 1.0, 0.01) var shoot_sound_cooldown: float = 0.1

# Background music toggle - configure in Inspector
@export var music_enabled: bool = true

# Track if music is playing
var is_music_playing: bool = false

# Track last time shooting sound was played
var last_shoot_sound_time: float = 0.0


func _ready() -> void:
	# Load default sounds if not set in Inspector
	_load_default_sounds()
	
	# Create music player if it doesn't exist
	if not music_player:
		music_player = AudioStreamPlayer.new()
		music_player.name = "MusicPlayer"
		music_player.stream = music_background
		music_player.volume_db = linear_to_db(music_volume * master_volume)
		add_child(music_player)
	
	# Create sound effects container if it doesn't exist
	if not sound_effects_container:
		sound_effects_container = Node.new()
		sound_effects_container.name = "SoundEffects"
		add_child(sound_effects_container)
	
	# Pre-populate sound effect pool
	_create_sound_effect_pool()
	
	# Connect to EventBus signals
	_connect_to_event_bus()
	
	# Start background music if enabled
	if music_enabled:
		play_background_music()

func _connect_to_event_bus() -> void:
	"""Connect to all relevant EventBus signals for audio triggers."""
	
	# Existing audio signals
	# EventBus.audio_explosion_play.connect(_on_explosion_play)
	# EventBus.audio_win_play.connect(_on_win_play)
	EventBus.audio_shoot_play.connect(_on_shoot_play)
	
	# # Player events
	# EventBus.player_hit.connect(_on_player_hit)
	# EventBus.player_died.connect(_on_player_died)
	
	# Enemy events
	EventBus.one_enemy_die.connect(_on_enemy_die)
	
	# # Bonus events
	# EventBus.bonus_touched.connect(_on_bonus_touched)
	# EventBus.bonus_used.connect(_on_bonus_used)
	
	# Item events
	EventBus.item_picked_up.connect(_on_item_picked_up)
	
	# Game state events
	# EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.leveled_up.connect(_on_leveled_up)
	# EventBus.stage_finished.connect(_on_stage_finished)
	
	# Level events
	EventBus.start_level.connect(_on_level_started)


func _load_default_sounds() -> void:
	"""Load default sounds if not assigned in Inspector."""
	if not sound_explosion:
		sound_explosion = load("res://Art/Sounds/explosion.wav")
	if not sound_pickup_coin:
		sound_pickup_coin = load("res://Art/Sounds/pickupCoin.wav")
	if not sound_bonus_pickup:
		sound_bonus_pickup = load("res://Art/Sounds/bonusPickUp.wav")
	if not sound_bonus_used:
		sound_bonus_used = load("res://Art/Sounds/bonusUsed.wav")
	if not sound_laser_shoot:
		sound_laser_shoot = load("res://Art/Sounds/laserShoot.wav")
	if not sound_hit:
		sound_hit = load("res://Art/Sounds/sounds_effect/Hit.wav")
	if not music_background:
		music_background = load("res://Art/Sounds/background_music/whispering_dawn_1.ogg")


func _create_sound_effect_pool() -> void:
	"""Create a pool of AudioStreamPlayer nodes for sound effects."""
	for i in range(MAX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.name = "SoundEffectPlayer_%d" % i
		player.volume_db = linear_to_db(sfx_volume * master_volume)
		sound_effects_container.add_child(player)
		sound_effect_pool.append(player)





func _get_available_sound_player() -> AudioStreamPlayer:
	"""Get an available AudioStreamPlayer from the pool, or create a new one if all are busy."""
	for player in sound_effect_pool:
		if not player.playing:
			return player
	
	# If all players are busy, create a temporary one (will be cleaned up when done)
	var temp_player = AudioStreamPlayer.new()
	temp_player.volume_db = linear_to_db(sfx_volume * master_volume)
	sound_effects_container.add_child(temp_player)
	return temp_player


func play_sound_effect(stream: AudioStream, pitch_scale: float = 1.0) -> void:
	"""Play a sound effect using an available player from the pool."""
	if not stream:
		push_warning("AudioManager: Attempted to play null audio stream")
		return
	
	var player = _get_available_sound_player()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.play()
	
	# If this is a temporary player (not in pool), free it when done
	if player not in sound_effect_pool:
		player.finished.connect(func(): player.queue_free())


func play_background_music() -> void:
	"""Start playing background music (looped)."""
	if not music_enabled:
		return
	
	if music_player and music_background:
		music_player.stream = music_background
		music_player.play()
		music_player.finished.connect(_on_music_finished)  # Loop music
		is_music_playing = true


func stop_background_music() -> void:
	"""Stop background music."""
	if music_player:
		music_player.stop()
		is_music_playing = false


func set_master_volume(volume: float) -> void:
	"""Set master volume (0.0 to 1.0)."""
	master_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()


func set_music_volume(volume: float) -> void:
	"""Set music volume (0.0 to 1.0)."""
	music_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()


func set_sfx_volume(volume: float) -> void:
	"""Set sound effects volume (0.0 to 1.0)."""
	sfx_volume = clamp(volume, 0.0, 1.0)
	_update_volumes()


func set_music_enabled(enabled: bool) -> void:
	"""Enable or disable background music."""
	music_enabled = enabled
	if not music_enabled:
		stop_background_music()
	elif not is_music_playing:
		play_background_music()


func _update_volumes() -> void:
	"""Update all audio player volumes based on current settings."""
	if music_player:
		music_player.volume_db = linear_to_db(music_volume * master_volume)
	
	for player in sound_effect_pool:
		player.volume_db = linear_to_db(sfx_volume * master_volume)


func _on_music_finished() -> void:
	"""Loop background music when it finishes."""
	if not music_enabled:
		is_music_playing = false
		return
	
	if is_music_playing and music_player:
		music_player.play()


# Signal handlers for game events
func _on_explosion_play() -> void:
	play_sound_effect(sound_explosion)


func _on_win_play() -> void:
	if sound_win:
		play_sound_effect(sound_win)
	else:
		play_sound_effect(sound_pickup_coin)  # Fallback to coin sound


func _on_player_hit(_player_id: int, _player_name: String, _number_of_life: int) -> void:
	play_sound_effect(sound_hit)


func _on_player_died() -> void:
	# Could play a death sound if available
	play_sound_effect(sound_explosion, 0.8)  # Lower pitch for death


func _on_enemy_die(_groups: Array = []) -> void:
	play_sound_effect(sound_enemy_die)


func _on_bonus_touched(_bonus_name: String = "") -> void:
	play_sound_effect(sound_bonus_pickup)


func _on_bonus_used() -> void:
	play_sound_effect(sound_bonus_used)


func _on_item_picked_up(_item, _count: int) -> void:
	play_sound_effect(sound_pickup_coin)


func _on_wave_cleared(_wave_number: int, _total_waves: int) -> void:
	# Play a success sound for wave cleared
	if sound_wave_cleared:
		play_sound_effect(sound_wave_cleared)
	else:
		play_sound_effect(sound_pickup_coin, 1.2)  # Higher pitch for success


func _on_leveled_up(_level: int, _levels_gained: int, _skill_points: int) -> void:
	# Play a level up sound
	if sound_level_up:
		play_sound_effect(sound_level_up)
	else:
		play_sound_effect(sound_pickup_coin, 1.3)  # Higher pitch for level up


func _on_stage_finished() -> void:
	# Play stage completion sound
	if sound_win:
		play_sound_effect(sound_win)
	else:
		play_sound_effect(sound_pickup_coin, 1.1)


func _on_level_started() -> void:
	# Ensure background music is playing when level starts (if enabled)
	if music_enabled and not is_music_playing:
		play_background_music()


# Signal handler for shooting sound
func _on_shoot_play() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	var time_since_last_shoot = current_time - last_shoot_sound_time
	
	# Only play sound if enough time has passed since last shot
	if time_since_last_shoot >= shoot_sound_cooldown:
		play_sound_effect(sound_laser_shoot)
		last_shoot_sound_time = current_time
