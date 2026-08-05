@testset "missil 2x2" begin
    function missile_match(; reefs=Set{Tuple{Int, Int}}())
        player = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        enemy = combat_board(reefs=reefs, ships=[
            ShipPlacement(1, PATROL, 5, 5, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 2, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        return create_combat_match(player, enemy)
    end

    function stock_missile!(match; second_hit=(3, 1))
        for cell in ((5, 5), second_hit)
            @test player_attack!(match, cell...).result.valid
        end
        @test player_attack!(match, 4, 5).result.outcome == ATTACK_MISS
        while combat_state(match).turn == COMPUTER
            computer_step!(match; rng=MersenneTwister(81))
        end
        @test buy_weapon!(match, PLAYER, MISSILE).valid
    end

    @testset "processa a area e agrega acertos, afundamentos e moedas" begin
        match = missile_match()
        stock_missile!(match; second_hit=(2, 2))

        update = player_missile!(match, 2, 2)

        @test update.result.valid
        @test update.result.cells == [(2, 3), (3, 2), (3, 3)]
        @test update.result.hits == 3
        @test update.result.sunk == 1
        @test update.state.player_coins == 40
        @test update.state.player_inventory[MISSILE] == 0
        @test update.state.turn == PLAYER
        @test update.directive == AWAIT_PLAYER
    end


    @testset "a previa ancora no canto superior esquerdo e rejeita bordas" begin
        @test missile_preview(5, 4, 4).cells == [(4, 4), (4, 5), (5, 4), (5, 5)]
        @test missile_preview(5, 4, 4).valid
        @test !missile_preview(5, 5, 5).valid

        match = missile_match()
        stock_missile!(match)
        rejected = player_missile!(match, 5, 5)
        @test !rejected.result.valid
        @test rejected.result.rejection == OUT_OF_BOUNDS
        @test rejected.state.player_inventory[MISSILE] == 1
        @test rejected.state.turn == PLAYER
    end

    @testset "ignora recifes e casas processadas e exige uma casa nova" begin
        match = missile_match(reefs=Set([(1, 1)]))
        stock_missile!(match)
        @test player_attack!(match, 1, 2).result.outcome == ATTACK_MISS
        while combat_state(match).turn == COMPUTER
            computer_step!(match; rng=MersenneTwister(82))
        end

        fired = player_missile!(match, 1, 1)
        @test fired.result.valid
        @test fired.result.cells == [(2, 1), (2, 2)]
        @test fired.result.hits == 1
        @test fired.state.player_inventory[MISSILE] == 0
        @test fired.state.turn == PLAYER

        blocked = missile_match(reefs=Set([(1, 4), (1, 5), (2, 4), (2, 5)]))
        stock_missile!(blocked)
        rejected = player_missile!(blocked, 1, 4)
        @test !rejected.result.valid
        @test rejected.result.rejection == NO_ATTACKABLE_CELLS
        @test rejected.state.player_inventory[MISSILE] == 1
    end

    @testset "sem novo acerto consome a arma e encerra o turno" begin
        match = missile_match()
        stock_missile!(match)
        fired = player_missile!(match, 1, 4)
        @test fired.result.valid
        @test fired.result.hits == 0
        @test fired.state.player_inventory[MISSILE] == 0
        @test fired.state.turn == COMPUTER
        @test fired.directive == CONTINUE_COMPUTER_TURN
    end
end
