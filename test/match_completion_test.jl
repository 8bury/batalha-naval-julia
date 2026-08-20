using Random
using Test
using BatalhaNaval
using BatalhaNaval.Application

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
    player = create_positioning_board(PUDDLE)
    computer = create_positioning_board(PUDDLE)
    for board in (player, computer)
        @test place_ship!(board, CRUISER, 1, 1, HORIZONTAL)
        @test place_ship!(board, SUBMARINE, 2, 1, HORIZONTAL)
        @test place_ship!(board, PATROL, 3, 1, HORIZONTAL)
    end
    times = [10.0]
    clock() = times[1]
    controller = CombatController(player, computer; configuration, rng=MersenneTwister(43), clock)

    @test combat_in_progress(controller)
    @test elapsed_seconds(controller) == 0
    invalid = player_attack!(controller, 0, 0)
    @test !invalid.result.valid
    times[1] = 15.0
    @test elapsed_seconds(controller) == 0

    @test player_attack!(controller, 1, 1).result.valid
    times[1] = 140.9
    @test elapsed_seconds(controller) == 125

    # Exemplo literal: 6 acertos, 3 sobreviventes, 6 casas intactas,
    # 125 s e vitoria => 600+900+300+875+500 = 3175.
    for target in ((1, 2), (1, 3), (2, 1), (2, 2), (3, 1))
        @test player_attack!(controller, target...).result.valid
    end
    @test !combat_in_progress(controller)
    summary = match_summary(controller)
    @test summary.duration_seconds == 125
    @test summary.hits == 6
    @test summary.surviving_ships == 3
    @test summary.intact_cells == 6
    @test summary.score.total == 3_175
    times[1] = 999.0
    @test elapsed_seconds(controller) == 125

    rematch = play_again(controller; rng=MersenneTwister(99), clock)
    state = combat_state(rematch)
    preserved = match_configuration(rematch)
    @test preserved.player_name == "Almirante"
    @test preserved.map == PUDDLE
    @test preserved.special_terrain

    @test isempty(state.history)
    @test isnothing(state.winner)
    @test state.turn == PLAYER
    @test state.player_coins == 0
    @test state.computer_coins == 0
    @test all(==(0), values(state.player_inventory))
    @test all(==(0), values(state.computer_inventory))
    @test state.shop_available
    @test elapsed_seconds(rematch) == 0
    @test any(cell -> !isnothing(cell.own_ship_type), state.player_cells)
    @test all(cell -> isnothing(cell.own_ship_type), state.computer_cells)
end
