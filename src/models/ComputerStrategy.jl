orthogonal_neighbors((row, column)) = (
    (row - 1, column), (row + 1, column),
    (row, column - 1), (row, column + 1),
)

function unknown_cell(knowledge::AbstractMatrix{PublicCellState}, cell)
    row, column = cell
    return checkbounds(Bool, knowledge, row, column) && knowledge[row, column] == UNKNOWN
end

function hit_groups(strategy::ComputerStrategy)
    remaining = copy(strategy.pending_hits)
    groups = Vector{Vector{Tuple{Int, Int}}}()
    while !isempty(remaining)
        seed = pop!(remaining)
        group, frontier = [seed], [seed]
        while !isempty(frontier)
            for neighbor in orthogonal_neighbors(pop!(frontier))
                if neighbor in remaining
                    delete!(remaining, neighbor)
                    push!(group, neighbor)
                    push!(frontier, neighbor)
                end
            end
        end
        push!(groups, group)
    end
    return groups
end

function pursuit_candidates(
    strategy::ComputerStrategy,
    knowledge::AbstractMatrix{PublicCellState},
)
    for group in sort(hit_groups(strategy); by=length, rev=true)
        if length(group) >= 2
            rows, columns = unique(first.(group)), unique(last.(group))
            extensions = if length(rows) == 1
                row = only(rows)
                [(row, minimum(columns) - 1), (row, maximum(columns) + 1)]
            elseif length(columns) == 1
                column = only(columns)
                [(minimum(rows) - 1, column), (maximum(rows) + 1, column)]
            else
                Tuple{Int, Int}[]
            end
            candidates = filter(cell -> unknown_cell(knowledge, cell), extensions)
            !isempty(candidates) && return candidates
        end
        candidates = Tuple{Int, Int}[]
        for hit in group, neighbor in orthogonal_neighbors(hit)
            unknown_cell(knowledge, neighbor) && push!(candidates, neighbor)
        end
        unique!(candidates)
        !isempty(candidates) && return candidates
    end
    return Tuple{Int, Int}[]
end

"""Escolhe uma coordenada usando exclusivamente o estado observável do tabuleiro."""
function choose_attack(
    strategy::ComputerStrategy,
    knowledge::AbstractMatrix{PublicCellState};
    rng=Random.default_rng(),
)
    candidates = pursuit_candidates(strategy, knowledge)
    if isempty(candidates)
        candidates = [(row, column) for row in axes(knowledge, 1) for column in axes(knowledge, 2) if knowledge[row, column] == UNKNOWN]
    end
    isempty(candidates) && throw(ArgumentError("Não há coordenadas desconhecidas para atacar."))
    return rand(rng, candidates)
end

"""Atualiza a memória da estratégia somente a partir do resultado e da visão pública."""
function record_attack!(
    strategy::ComputerStrategy,
    cell::Tuple{Int, Int},
    outcome::AttackOutcome,
    knowledge::AbstractMatrix{PublicCellState},
)
    filter!(hit -> checkbounds(Bool, knowledge, hit...) && knowledge[hit...] == DAMAGED, strategy.pending_hits)
    outcome == ATTACK_HIT && push!(strategy.pending_hits, cell)
    return strategy
end

function computer_knowledge(match::CombatMatch)
    dimension = match.player_board.dimension
    return [public_cell(match, PLAYER, row, column) for row in 1:dimension, column in 1:dimension]
end

"""Escolhe e aplica exatamente um ataque do computador."""
function computer_attack!(match::CombatMatch, strategy::ComputerStrategy; rng=Random.default_rng())
    row, column = choose_attack(strategy, computer_knowledge(match); rng)
    result = resolve_attack!(match, COMPUTER, row, column)
    record_attack!(strategy, (row, column), result.outcome, computer_knowledge(match))
    return result
end

"""Aplica exatamente um ataque do computador e informa se o turno continua."""
function available_air_strikes(knowledge::AbstractMatrix{PublicCellState})
    dimension = size(knowledge, 1)
    candidates = Tuple{AirStrikeAxis, Int}[]
    for axis in (STRIKE_ROW, STRIKE_COLUMN), index in 1:dimension
        any(cell -> knowledge[cell...] == UNKNOWN, air_strike_preview(dimension, axis, index)) &&
            push!(candidates, (axis, index))
    end
    return candidates
end

function available_missiles(knowledge::AbstractMatrix{PublicCellState})
    dimension = size(knowledge, 1)
    candidates = Tuple{Int, Int}[]
    for row in 1:(dimension - 1), column in 1:(dimension - 1)
        any(cell -> knowledge[cell...] == UNKNOWN, missile_preview(dimension, row, column).cells) &&
            push!(candidates, (row, column))
    end
    return candidates
end

function computer_can_buy(match::CombatMatch, weapon::WeaponType)
    map = target_board(match, COMPUTER).map
    return match.coins[COMPUTER] >= weapon_price(weapon) &&
           match.purchased[COMPUTER][weapon] < weapon_quota(map, weapon)
end

function remember_public_damage!(strategy::ComputerStrategy, knowledge)
    empty!(strategy.pending_hits)
    for cell in CartesianIndices(knowledge)
        knowledge[cell] == DAMAGED && push!(strategy.pending_hits, Tuple(cell))
    end
    return strategy
end

function computer_special_attack!(match::CombatMatch; rng=Random.default_rng())
    knowledge = computer_knowledge(match)
    if computer_can_buy(match, AIR_STRIKE)
        candidates = available_air_strikes(knowledge)
        if !isempty(candidates)
            buy_weapon!(match, COMPUTER, AIR_STRIKE).valid || return nothing
            axis, index = rand(rng, candidates)
            result = resolve_air_strike!(match, COMPUTER, axis, index)
            remember_public_damage!(match.computer_strategy, computer_knowledge(match))
            return AirStrikeUpdate(result, combat_state(match), combat_directive(match))
        end
    end
    if computer_can_buy(match, MISSILE)
        candidates = available_missiles(knowledge)
        if !isempty(candidates)
            buy_weapon!(match, COMPUTER, MISSILE).valid || return nothing
            row, column = rand(rng, candidates)
            result = resolve_missile!(match, COMPUTER, row, column)
            remember_public_damage!(match.computer_strategy, computer_knowledge(match))
            return MissileUpdate(result, combat_state(match), combat_directive(match))
        end
    end
    return nothing
end

function computer_step!(match::CombatMatch; rng=Random.default_rng())
    combat_directive(match) == CONTINUE_COMPUTER_TURN ||
        throw(ArgumentError("O combate não está aguardando um passo do computador."))
    if match.shop_available[COMPUTER]
        special_update = computer_special_attack!(match; rng)
        !isnothing(special_update) && return special_update
    end
    result = computer_attack!(match, match.computer_strategy; rng)
    return combat_update(match, result)
end
