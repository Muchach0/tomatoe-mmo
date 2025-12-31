class_name EncounterResource
extends Resource

# An encounter is a Resource that consist of: 
# 1 Spawner
# 1 or several quests
# The encounter get assigned randomly by the server to an event site node in the scene. 


@export var spawner: EnemySpawnerResourceClass = null
@export var quests: Array[QuestResource] = []

