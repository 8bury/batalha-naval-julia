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

function shop_items(match::CombatMatch, participant::Participant)
    map = target_board(match, participant).map
    return [ShopItemState(
        weapon,
        weapon_price(weapon),
        weapon_quota(map, weapon) - match.purchased[participant][weapon],
        match.inventories[participant][weapon],
    ) for weapon in weapons()]
end

function buy_weapon!(match::CombatMatch, participant::Participant, weapon::WeaponType)
    match.shop_available[participant] && match.turn == participant && isnothing(match.winner) ||
        return PurchaseResult(false, weapon, SHOP_CLOSED)
    price = weapon_price(weapon)
    match.coins[participant] >= price ||
        return PurchaseResult(false, weapon, INSUFFICIENT_FUNDS)
    map = target_board(match, participant).map
    match.purchased[participant][weapon] < weapon_quota(map, weapon) ||
        return PurchaseResult(false, weapon, QUOTA_EXHAUSTED)
    match.coins[participant] -= price
    match.purchased[participant][weapon] += 1
    match.inventories[participant][weapon] += 1
    return PurchaseResult(true, weapon, nothing)
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

function missile_preview(dimension::Int, row::Int, column::Int)
    cells = [(row + row_offset, column + column_offset) for row_offset in 0:1 for column_offset in 0:1]
    return MissilePreview(all(cell -> 1 <= cell[1] <= dimension && 1 <= cell[2] <= dimension, cells), cells)
end

function apply_special_attack!(match, participant, weapon, board, attacks, candidate_cells)
    cells = filter(cell -> cell ∉ board.terrain.reefs && cell ∉ attacks, candidate_cells)
    isempty(cells) && return (
        valid=false,
        cells=cells,
        hits=0,
        sunk=0,
        rejection=NO_ATTACKABLE_CELLS,
    )

    sunk_before = count(placement -> ship_sunk(placement, attacks), board.placements)
    union!(attacks, cells)
    hits = count(cell -> !isnothing(ship_at(board, cell...)), cells)
    sunk = count(placement -> ship_sunk(placement, attacks), board.placements) - sunk_before
    sunk_ships = [placement.ship_type for placement in board.placements if
        ship_sunk(placement, attacks) && any(cell -> cell in cells, placement_cells(placement))]
    match.coins[participant] += 10 * (hits + sunk)
    match.inventories[participant][weapon] -= 1
    match.shop_available[participant] = false
    if fleet_destroyed(board, attacks)
        match.winner = participant
    elseif hits == 0
        match.turn = opponent(participant)
        match.shop_available[match.turn] = true
    end
    outcome = !isempty(sunk_ships) ? ATTACK_SUNK : hits > 0 ? ATTACK_HIT : ATTACK_MISS
    record_event!(match, participant, weapon, "", outcome, hits, sunk_ships)
    return (valid=true, cells=cells, hits=hits, sunk=sunk, rejection=nothing)
end

function resolve_missile!(match::CombatMatch, participant::Participant, row::Int, column::Int)
    empty_result(rejection) = MissileResult(false, row, column, Tuple{Int, Int}[], 0, 0, rejection)
    !isnothing(match.winner) && return empty_result(MATCH_FINISHED)
    match.turn == participant || return empty_result(WRONG_TURN)
    match.inventories[participant][MISSILE] > 0 || return empty_result(WEAPON_UNAVAILABLE)

    board = target_board(match, participant)
    preview = missile_preview(board.dimension, row, column)
    preview.valid || return empty_result(OUT_OF_BOUNDS)
    attacks = attacks_by(match, participant)
    resolution = apply_special_attack!(match, participant, MISSILE, board, attacks, preview.cells)
    resolution.valid || return empty_result(resolution.rejection)
    return MissileResult(
        true,
        row,
        column,
        resolution.cells,
        resolution.hits,
        resolution.sunk,
        nothing,
    )
end

function player_missile!(match::CombatMatch, row::Int, column::Int)
    result = resolve_missile!(match, PLAYER, row, column)
    return MissileUpdate(result, combat_state(match), combat_directive(match))
end

function air_strike_preview(dimension::Int, axis::AirStrikeAxis, index::Int)
    1 <= index <= dimension || return Tuple{Int, Int}[]
    return axis == STRIKE_ROW ?
        [(index, column) for column in 1:dimension] :
        [(row, index) for row in 1:dimension]
end

function resolve_air_strike!(
    match::CombatMatch,
    participant::Participant,
    axis::AirStrikeAxis,
    index::Int,
)
    empty_result(rejection) = AirStrikeResult(false, axis, index, Tuple{Int, Int}[], 0, 0, rejection)
    !isnothing(match.winner) && return empty_result(MATCH_FINISHED)
    match.turn == participant || return empty_result(WRONG_TURN)
    match.inventories[participant][AIR_STRIKE] > 0 || return empty_result(WEAPON_UNAVAILABLE)

    board = target_board(match, participant)
    candidate_cells = air_strike_preview(board.dimension, axis, index)
    isempty(candidate_cells) && return empty_result(OUT_OF_BOUNDS)
    attacks = attacks_by(match, participant)
    resolution = apply_special_attack!(
        match,
        participant,
        AIR_STRIKE,
        board,
        attacks,
        candidate_cells,
    )
    resolution.valid || return empty_result(resolution.rejection)
    return AirStrikeResult(
        true,
        axis,
        index,
        resolution.cells,
        resolution.hits,
        resolution.sunk,
        nothing,
    )
end

function player_air_strike!(match::CombatMatch, axis::AirStrikeAxis, index::Int)
    result = resolve_air_strike!(match, PLAYER, axis, index)
    return AirStrikeUpdate(result, combat_state(match), combat_directive(match))
end
