function combat_cell_appearance(cell::CombatCellState, owner::Participant)
    cell.public_state == WATER && return ("○", "Água", "combat-water")
    cell.public_state == DAMAGED && return ("×", "Embarcação atingida", "combat-damaged")
    if cell.public_state == SUNK
        revealed = isnothing(cell.revealed_ship_type) ? "Embarcação" : ship_label(cell.revealed_ship_type)
        return ("■", "$revealed afundado", "combat-sunk")
    end
    cell.public_state == PUBLIC_REEF && return (terrain_symbol(REEF), terrain_tooltip(REEF), "cell-reef")
    if owner == PLAYER && !isnothing(cell.own_ship_type)
        return (ship_symbol(cell.own_ship_type), ship_label(cell.own_ship_type), "cell-occupied")
    end
    cell.terrain == SHALLOW_WATER && return (terrain_symbol(SHALLOW_WATER), terrain_tooltip(SHALLOW_WATER), "cell-shallow-water")
    return ("·", "Casa ainda desconhecida", "cell-empty")
end

function attack_rejection_message(rejection::AttackRejection)
    rejection == MATCH_FINISHED && return "A partida já terminou."
    rejection == WRONG_TURN && return "Não é o seu turno."
    rejection == OUT_OF_BOUNDS && return "A coordenada está fora do tabuleiro."
    rejection == REEF_TARGET && return "Recifes não podem ser atacados."
    rejection == ALREADY_ATTACKED && return "Esta coordenada já foi atacada."
    rejection == WEAPON_UNAVAILABLE && return "A arma selecionada não está disponível no inventário."
    rejection == NO_ATTACKABLE_CELLS && return "A área não contém casas inéditas e atacáveis."
    throw(ArgumentError("Rejeição de ataque sem mensagem: $rejection"))
end

function purchase_rejection_message(rejection::PurchaseRejection)
    rejection == SHOP_CLOSED && return "A loja só abre no início do seu turno."
    rejection == INSUFFICIENT_FUNDS && return "Saldo insuficiente para esta compra."
    rejection == QUOTA_EXHAUSTED && return "A cota desta arma acabou neste mapa."
    throw(ArgumentError("Rejeição de compra sem mensagem: $rejection"))
end

function fleet_status_text(status::FleetShipStatus)
    state = status.state == FLEET_HIDDEN ? "oculto" :
            status.state == FLEET_INTACT ? "intacto" :
            status.state == FLEET_DAMAGED ? "danificado" : "afundado"
    label = isnothing(status.ship_type) ? "Embarcação inimiga" : ship_label(status.ship_type)
    return "$label: $state"
end
