export CombatController,
       CombatCellState,
       CombatState,
       combat_state,
       computer_step!,
       player_attack!,
       buy_weapon!,
       missile_preview,
       player_missile!,
       CombatUpdate,
       MissileUpdate,
       air_strike_preview,
       player_air_strike!,
       AirStrikeUpdate,
       elapsed_seconds,
       match_summary,
       play_again

mutable struct CombatController{R<:AbstractRNG, C}
    match::CombatMatch
    configuration::MatchConfiguration
    rng::R
    clock::C
    started_at::Union{Nothing, Float64}
    ended_at::Union{Nothing, Float64}
end

function CombatController(player::PositioningBoard, computer::PositioningBoard;
                          configuration=MatchConfiguration("Jogador", player.map, false),
                          rng=Random.default_rng(), clock=time)
    return CombatController(create_combat_match(player, computer), configuration, rng,
                            clock, nothing, nothing)
end

combat_state(controller::CombatController) = combat_state(controller.match)

function record_timing!(controller::CombatController, valid::Bool)
    valid || return controller
    now = Float64(controller.clock())
    isnothing(controller.started_at) && (controller.started_at = now)
    !isnothing(controller.match.winner) && isnothing(controller.ended_at) &&
        (controller.ended_at = now)
    return controller
end

function timed_attack!(action, controller::CombatController)
    update = action()
    record_timing!(controller, update.result.valid)
    return update
end

player_attack!(controller::CombatController, row::Int, column::Int) =
    timed_attack!(() -> player_attack!(controller.match, row, column), controller)
computer_step!(controller::CombatController) =
    timed_attack!(() -> computer_step!(controller.match; rng=controller.rng), controller)
buy_weapon!(controller::CombatController, weapon::WeaponType) = buy_weapon!(controller.match, PLAYER, weapon)
player_missile!(controller::CombatController, row::Int, column::Int) =
    timed_attack!(() -> player_missile!(controller.match, row, column), controller)
player_air_strike!(controller::CombatController, axis::AirStrikeAxis, index::Int) =
    timed_attack!(() -> player_air_strike!(controller.match, axis, index), controller)

function elapsed_seconds(controller::CombatController)
    isnothing(controller.started_at) && return 0
    stop = isnothing(controller.ended_at) ? Float64(controller.clock()) : controller.ended_at
    return max(0, floor(Int, stop - controller.started_at))
end

function match_summary(controller::CombatController)
    winner = controller.match.winner
    isnothing(winner) && throw(ArgumentError("A partida ainda nao terminou."))
    # Permite resumir partidas concluidas pelo motor ou fixtures deterministicas.
    isnothing(controller.ended_at) && (controller.ended_at = Float64(controller.clock()))
    board = controller.match.player_board
    enemy_hits = controller.match.computer_attacks
    player_hits = count(cell -> !isnothing(ship_at(controller.match.computer_board, cell...)),
                        controller.match.player_attacks)
    surviving = count(placement -> !ship_sunk(placement, enemy_hits), board.placements)
    intact = sum(count(cell -> cell ∉ enemy_hits, placement_cells(placement))
                 for placement in board.placements)
    duration = elapsed_seconds(controller)
    won = winner == PLAYER
    score = calculate_score(player_hits, surviving, intact, duration, won)
    return MatchSummary(won, duration, player_hits, surviving, intact,
                        controller.match.coins[PLAYER], score)
end

"""Cria uma revanche equivalente, com terreno e duas frotas novamente sorteados."""
function play_again(controller::CombatController; rng=Random.default_rng(), clock=controller.clock)
    player, computer = create_match_boards(controller.configuration; rng)
    result = auto_place_ships!(player; rng)
    result.success || error("Nao foi possivel posicionar a frota da revanche.")
    return CombatController(player, computer; configuration=controller.configuration, rng, clock)
end
