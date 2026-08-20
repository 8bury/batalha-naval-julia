"""Cria uma partida pronta para combate, sem qualquer dependência da interface."""
function create_combat_match(
    player_board::PositioningBoard,
    computer_board::PositioningBoard,
)
    battle_ready(player_board, computer_board) ||
        throw(ArgumentError("As duas frotas devem estar completas antes do combate."))
    player_board.dimension == computer_board.dimension ||
        throw(ArgumentError("Os tabuleiros da partida devem ter a mesma dimensão."))
    return CombatMatch(
        player_board,
        computer_board,
        Set{Tuple{Int, Int}}(),
        Set{Tuple{Int, Int}}(),
        PLAYER,
        nothing,
        ComputerStrategy(),
        Dict(PLAYER => 0, COMPUTER => 0),
        Dict(participant => Dict(weapon => 0 for weapon in weapons()) for participant in (PLAYER, COMPUTER)),
        Dict(participant => Dict(weapon => 0 for weapon in weapons()) for participant in (PLAYER, COMPUTER)),
        Dict(PLAYER => true, COMPUTER => false),
        CombatEvent[],
    )
end

coordinate_label(row, column) = "$(Char(Int('A') + column - 1))$(row)"
participant_label(participant) = participant == PLAYER ? "Jogador" : "Computador"

function record_event!(match, actor, weapon, target, outcome, hits, sunk_ships)
    result = outcome == ATTACK_MISS ? "água" :
             outcome == ATTACK_SUNK ? "afundou $(join(ship_label.(sunk_ships), ", "))" : "acerto"
    subject = isnothing(weapon) ? target : weapon_label(weapon)
    push!(match.history, CombatEvent(
        actor, weapon, target, outcome, hits, sunk_ships,
        "$(participant_label(actor)) - $subject: $result.",
    ))
end

attacks_by(match::CombatMatch, participant::Participant) =
    participant == PLAYER ? match.player_attacks : match.computer_attacks

target_board(match::CombatMatch, participant::Participant) =
    participant == PLAYER ? match.computer_board : match.player_board

opponent(participant::Participant) = participant == PLAYER ? COMPUTER : PLAYER

function ship_sunk(placement::ShipPlacement, attacks::Set{Tuple{Int, Int}})
    return all(cell -> cell in attacks, placement_cells(placement))
end

function fleet_destroyed(board::PositioningBoard, attacks::Set{Tuple{Int, Int}})
    return all(placement -> ship_sunk(placement, attacks), board.placements)
end

"""Processa um ataque básico. Tentativas inválidas não alteram o turno."""
function resolve_attack!(match::CombatMatch, participant::Participant, row::Int, column::Int)
    if !isnothing(match.winner)
        return AttackResult(false, ATTACK_INVALID, row, column, MATCH_FINISHED)
    end
    if match.turn != participant
        return AttackResult(false, ATTACK_INVALID, row, column, WRONG_TURN)
    end

    board = target_board(match, participant)
    attacks = attacks_by(match, participant)
    cell = (row, column)
    if !(1 <= row <= board.dimension && 1 <= column <= board.dimension)
        return AttackResult(false, ATTACK_INVALID, row, column, OUT_OF_BOUNDS)
    end
    if cell in board.terrain.reefs
        return AttackResult(false, ATTACK_INVALID, row, column, REEF_TARGET)
    end
    if cell in attacks
        return AttackResult(false, ATTACK_INVALID, row, column, ALREADY_ATTACKED)
    end

    push!(attacks, cell)
    match.shop_available[participant] = false
    placement = ship_at(board, row, column)
    if isnothing(placement)
        match.turn = opponent(participant)
        match.shop_available[match.turn] = true
        result = AttackResult(true, ATTACK_MISS, row, column, nothing)
        record_event!(match, participant, nothing, coordinate_label(row, column), result.outcome, 0, ShipType[])
        return result
    end

    match.coins[participant] += 10

    if ship_sunk(placement, attacks)
        match.coins[participant] += 10
        if fleet_destroyed(board, attacks)
            match.winner = participant
        end
        result = AttackResult(true, ATTACK_SUNK, row, column, nothing)
        record_event!(match, participant, nothing, coordinate_label(row, column), result.outcome, 1, [placement.ship_type])
        return result
    end
    result = AttackResult(true, ATTACK_HIT, row, column, nothing)
    record_event!(match, participant, nothing, coordinate_label(row, column), result.outcome, 1, ShipType[])
    return result
end
