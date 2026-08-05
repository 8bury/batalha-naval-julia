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
    )
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
    placement = ship_at(board, row, column)
    if isnothing(placement)
        match.turn = opponent(participant)
        return AttackResult(true, ATTACK_MISS, row, column, nothing)
    end

    if ship_sunk(placement, attacks)
        if fleet_destroyed(board, attacks)
            match.winner = participant
        end
        return AttackResult(true, ATTACK_SUNK, row, column, nothing)
    end
    return AttackResult(true, ATTACK_HIT, row, column, nothing)
end

"""Expõe o estado observável de uma casa sem tipos de Gtk4."""
function public_cell(match::CombatMatch, owner::Participant, row::Int, column::Int)
    board = owner == PLAYER ? match.player_board : match.computer_board
    attacks = owner == PLAYER ? match.computer_attacks : match.player_attacks
    cell = (row, column)
    cell in board.terrain.reefs && return PUBLIC_REEF
    cell in attacks || return UNKNOWN
    placement = ship_at(board, row, column)
    isnothing(placement) && return WATER
    return ship_sunk(placement, attacks) ? SUNK : DAMAGED
end

function combat_cells(match::CombatMatch, owner::Participant)
    board = owner == PLAYER ? match.player_board : match.computer_board
    return [
        begin
            placement = ship_at(board, row, column)
            CombatCellState(
                public_cell(match, owner, row, column),
                terrain_at(board, row, column),
                owner == PLAYER && !isnothing(placement) ? placement.ship_type : nothing,
            )
        end for row in 1:board.dimension, column in 1:board.dimension
    ]
end

"""Retorna todo o estado observável do combate sem expor sua representação mutável."""
function combat_state(match::CombatMatch)
    return CombatState(
        match.player_board.dimension,
        combat_cells(match, PLAYER),
        combat_cells(match, COMPUTER),
        match.turn,
        match.winner,
    )
end

combat_directive(match::CombatMatch) =
    !isnothing(match.winner) ? END_COMBAT :
    match.turn == COMPUTER ? CONTINUE_COMPUTER_TURN : AWAIT_PLAYER

combat_update(match::CombatMatch, result::AttackResult) =
    CombatUpdate(result, combat_state(match), combat_directive(match))

"""Aplica um ataque do jogador e devolve uma transição observável completa."""
function player_attack!(match::CombatMatch, row::Int, column::Int)
    return combat_update(match, resolve_attack!(match, PLAYER, row, column))
end
