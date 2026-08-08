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

"""Mantém o combate final visível até o tremor interno completar seu ciclo."""
combat_completion_delay_ms(event::CombatEvent) = combat_feedback(event).shake ? 325 : 0

"""Seleciona eventos ainda não entregues e devolve o novo cursor monotônico."""
function pending_feedback_events(events::AbstractVector{CombatEvent}, delivered::Int)
    cursor = clamp(delivered, 0, length(events))
    return (events=events[(cursor + 1):end], delivered=length(events))
end
