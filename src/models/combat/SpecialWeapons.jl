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
