# Loot table for enemies (Resource)
class_name LootTable
extends Resource


## Items that always drop
@export var guaranteed_rolls : Array[ItemRoll]

## Items that drop randomly based on weight
@export var random_rolls : Array[ItemRoll]

@export var roll_times := 1

var rng := RandomNumberGenerator.new()


func roll_loot() -> Array[ItemStack]:
	var items : Array[ItemStack]
	
	# Add all guaranteed items
	for roll in guaranteed_rolls:
		if roll.item:
			items.append(ItemStack.new(roll.item, roll.count))
	
	# Roll for random items
	if random_rolls.size() > 0:
		var weights : Array = random_rolls.map(func(roll: ItemRoll): return roll.weight)
		
		for i in roll_times:
			var index := rng.rand_weighted(weights)
			var roll : ItemRoll = random_rolls[index]
			if roll.item:
				items.append(ItemStack.new(roll.item, roll.count))
	
	return items
