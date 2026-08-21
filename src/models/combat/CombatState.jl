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
                !isnothing(placement) && ship_sunk(placement, owner == PLAYER ? match.computer_attacks : match.player_attacks) ? placement.ship_type : nothing,
            )
        end for row in 1:board.dimension, column in 1:board.dimension
    ]
end

function fleet_status(match::CombatMatch, owner::Participant)
    board = owner == PLAYER ? match.player_board : match.computer_board
    attacks = owner == PLAYER ? match.computer_attacks : match.player_attacks
    return [begin
        cells = placement_cells(placement)
        hits = count(cell -> cell in attacks, cells)
        sunk = hits == length(cells)
        state = sunk ? FLEET_SUNK : owner == COMPUTER ? FLEET_HIDDEN : hits > 0 ? FLEET_DAMAGED : FLEET_INTACT
        public_type = owner == PLAYER || sunk ? placement.ship_type : nothing
        FleetShipStatus(public_type, state, sunk || owner == PLAYER ? cells : Tuple{Int, Int}[])
    end for placement in board.placements]
end

"""Retorna todo o estado observável do combate sem expor sua representação mutável."""
function combat_state(match::CombatMatch)
    return CombatState(
        match.player_board.dimension,
        combat_cells(match, PLAYER),
        combat_cells(match, COMPUTER),
        match.turn,
        match.winner,
        match.coins[PLAYER],
        match.coins[COMPUTER],
        copy(match.inventories[PLAYER]),
        copy(match.inventories[COMPUTER]),
        match.turn == PLAYER && match.shop_available[PLAYER] && isnothing(match.winner),
        shop_items(match, PLAYER),
        fleet_status(match, PLAYER),
        fleet_status(match, COMPUTER),
        reverse(copy(match.history[max(1, end - 4):end])),
        copy(match.history),
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
