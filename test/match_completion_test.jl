using Random
using Test
using BatalhaNaval
using BatalhaNaval.Application
import BatalhaNaval: MatchConfiguration, auto_place_ships!, battle_ready,
                      create_match_boards, placement_cells

@testset "pontuacao, cronometro e revanche" begin
    @test calculate_score(3, 2, 4, 125, true).total == 2_475
    @test calculate_score(3, 2, 4, 125, true).hit_points == 300
    @test calculate_score(3, 2, 4, 125, true).survivor_points == 600
    @test calculate_score(3, 2, 4, 125, true).integrity_points == 200
    @test calculate_score(3, 2, 4, 125, true).time_points == 875
    @test calculate_score(3, 2, 4, 125, true).victory_points == 500
    @test calculate_score(1, 0, 0, 1_200, false).total == 100
    @test format_duration(125) == "02:05"

    configuration = MatchConfiguration("Almirante", PUDDLE, true)
    player, computer = create_match_boards(configuration; rng=MersenneTwister(41))
    auto_place_ships!(player; rng=MersenneTwister(42))
    times = [10.0]
    clock() = times[1]
    controller = CombatController(player, computer; configuration, rng=MersenneTwister(43), clock)

    @test elapsed_seconds(controller) == 0
    invalid = player_attack!(controller, 0, 0)
    @test !invalid.result.valid
    times[1] = 15.0
    @test elapsed_seconds(controller) == 0

    target = first(placement_cells(first(computer.placements)))
    @test player_attack!(controller, target...).result.valid
    times[1] = 140.9
    @test elapsed_seconds(controller) == 125

    # Exemplo literal: 6 acertos, 3 sobreviventes, 6 casas intactas,
    # 125 s e vitoria => 600+900+300+875+500 = 3175.
    union!(controller.match.player_attacks,
        Iterators.flatten(placement_cells.(computer.placements)))
    controller.match.winner = PLAYER
    summary = match_summary(controller)
    @test summary.duration_seconds == 125
    @test summary.hits == 6
    @test summary.surviving_ships == 3
    @test summary.intact_cells == 6
    @test summary.score.total == 3_175
    times[1] = 999.0
    @test elapsed_seconds(controller) == 125

    # Suja deliberadamente todas as categorias mutaveis antes da revanche.
    push!(controller.match.computer_attacks, (1, 1))
    push!(controller.match.computer_strategy.pending_hits, (2, 2))
    controller.match.coins[PLAYER] = 70
    controller.match.coins[COMPUTER] = 40
    controller.match.inventories[PLAYER][MISSILE] = 1
    controller.match.inventories[COMPUTER][AIR_STRIKE] = 1
    controller.match.purchased[PLAYER][MISSILE] = 1
    controller.match.purchased[COMPUTER][AIR_STRIKE] = 1
    controller.match.shop_available[PLAYER] = false
    controller.match.shop_available[COMPUTER] = true

    rematch = play_again(controller; rng=MersenneTwister(99), clock)
    state = combat_state(rematch)
    @test rematch.configuration.player_name == "Almirante"
    @test rematch.configuration.map == PUDDLE
    @test rematch.configuration.special_terrain

    # Exemplo literal da aleatoriedade injetada da revanche (seed 99).
    @test rematch.match.player_board.terrain.reefs == Set([(5, 3)])
    @test rematch.match.player_board.terrain.shallow_waters == Set([(3, 4)])
    @test [(ship.ship_type, ship.start_row, ship.start_column, ship.orientation)
           for ship in rematch.match.player_board.placements] == [
        (CRUISER, 1, 3, HORIZONTAL),
        (SUBMARINE, 3, 3, VERTICAL),
        (PATROL, 4, 5, VERTICAL),
    ]
    @test [(ship.ship_type, ship.start_row, ship.start_column, ship.orientation)
           for ship in rematch.match.computer_board.placements] == [
        (CRUISER, 3, 2, VERTICAL),
        (SUBMARINE, 2, 5, VERTICAL),
        (PATROL, 1, 3, VERTICAL),
    ]
    @test rematch.match.player_board.terrain != controller.match.player_board.terrain
    @test rematch.match.player_board.placements != controller.match.player_board.placements
    @test rematch.match.computer_board.placements != controller.match.computer_board.placements

    @test isempty(rematch.match.player_attacks)
    @test isempty(rematch.match.computer_attacks)
    @test isempty(state.history)
    @test isnothing(state.winner)
    @test state.turn == PLAYER
    @test state.player_coins == 0
    @test state.computer_coins == 0
    @test all(==(0), values(state.player_inventory))
    @test all(==(0), values(state.computer_inventory))
    @test all(==(0), values(rematch.match.purchased[PLAYER]))
    @test all(==(0), values(rematch.match.purchased[COMPUTER]))
    @test state.shop_available
    @test rematch.match.shop_available == Dict(PLAYER => true, COMPUTER => false)
    @test isempty(rematch.match.computer_strategy.pending_hits)
    @test elapsed_seconds(rematch) == 0
    @test isnothing(rematch.started_at)
    @test isnothing(rematch.ended_at)
    @test rematch.match.player_board !== controller.match.player_board
    @test rematch.match.computer_board !== controller.match.computer_board
    @test battle_ready(rematch.match.player_board, rematch.match.computer_board)
end
