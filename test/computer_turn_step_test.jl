using Random
using BatalhaNaval.Application

@testset "passos observaveis do turno do computador" begin
    configuration = create_match_configuration("Teste", PUDDLE; special_terrain=false)
    player_board, computer_board = create_match_boards(configuration; rng=MersenneTwister(3))
    @test auto_place_ships!(player_board; rng=MersenneTwister(4)).success
    controller = CombatController(player_board, computer_board; rng=MersenneTwister(4))
    miss = first(
        (row, column) for row in 1:computer_board.dimension for column in 1:computer_board.dimension
        if isnothing(ship_at(computer_board, row, column))
    )

    @test_throws ArgumentError computer_step!(controller)
    player_update = player_attack!(controller, miss...)
    @test player_update.directive == CONTINUE_COMPUTER_TURN

    computer_update = computer_step!(controller)
    @test computer_update.result.valid
    before = count(
        cell -> cell.public_state in (WATER, DAMAGED, SUNK),
        player_update.state.player_cells,
    )
    after = count(
        cell -> cell.public_state in (WATER, DAMAGED, SUNK),
        computer_update.state.player_cells,
    )
    @test after == before + 1
end
