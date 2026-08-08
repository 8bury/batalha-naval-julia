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

    configuration = MatchConfiguration("Almirante", PUDDLE, false)
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

    rematch = play_again(controller; rng=MersenneTwister(99), clock)
    @test rematch.configuration == configuration
    @test isnothing(combat_state(rematch).winner)
    @test isempty(combat_state(rematch).history)
    @test combat_state(rematch).player_coins == 0
    @test elapsed_seconds(rematch) == 0
    @test rematch.match.player_board !== controller.match.player_board
    @test rematch.match.computer_board !== controller.match.computer_board
    @test battle_ready(rematch.match.player_board, rematch.match.computer_board)
end
