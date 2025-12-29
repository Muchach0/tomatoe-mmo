extends Control


@export var slot_parent : Control

var skill_slots : Array[SkillSlot] = []

var _skills : Array[Skill] = []


func _ready():
    for child in slot_parent.get_children():
        if child is SkillSlot:
            skill_slots.append(child)

    EventBus.attach_skills_to_ui.connect(display_skills)
    
    

func display_skills(skills: Array[Skill]):
    if _skills != skills:
        if _skills != null:
            if EventBus.skills_changed.is_connected(on_skills_update):
                EventBus.skills_changed.disconnect(on_skills_update)
        EventBus.skills_changed.connect(on_skills_update)
    _skills = skills
    on_skills_update()


func on_skills_update():
    for index in skill_slots.size():
        var skill : Skill = _skills[index]
        skill_slots[index].skill = skill
