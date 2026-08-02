using Test
using Random
using BatalhaNaval

include(joinpath(@__DIR__, "..", "src", "ui", "GtkApplication.jl"))

@testset "callback do turno do computador na UI" begin
    configuration = create_match_configuration("Teste", PUDDLE; special_terrain=false)
    player_board, computer_board = create_match_boards(configuration; rng=MersenneTwister(3))
    @test auto_place_ships!(player_board; rng=MersenneTwister(4)).success
    match = create_combat_match(player_board, computer_board)
    match.turn = COMPUTER

    scheduled_callback = Ref{Any}(nothing)
    scheduled_interval = Ref(0)
    scheduler = function (callback, interval)
        scheduled_callback[] = callback
        scheduled_interval[] = interval
        return 1
    end
    reported = AttackResult[]

    GtkApplication.schedule_computer_attacks!(
        match,
        ComputerStrategy();
        interval_ms=600,
        scheduler,
    ) do result
        push!(reported, result)
    end

    @test scheduled_interval[] == 600
    @test !isnothing(scheduled_callback[])
    scheduled_callback[]()
    @test length(reported) == 1
    @test length(match.computer_attacks) == 1
end
