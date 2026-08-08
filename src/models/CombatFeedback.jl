@enum SoundCue begin
    NO_SOUND
    WATER_SOUND
    EXPLOSION_SOUND
end

struct CombatFeedback
    sound::SoundCue
    shake::Bool
end

"""Deriva feedback apenas de informações já públicas no evento de combate."""
function combat_feedback(event::CombatEvent)
    sound = event.outcome == ATTACK_MISS ? WATER_SOUND :
            event.outcome in (ATTACK_HIT, ATTACK_SUNK) ? EXPLOSION_SOUND : NO_SOUND
    return CombatFeedback(sound, event.outcome == ATTACK_SUNK && CRUISER in event.sunk_ships)
end
