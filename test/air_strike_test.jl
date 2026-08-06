@testset "ataque aereo em linha ou coluna" begin
    @testset "preco e cotas por mapa" begin
        @test weapon_price(AIR_STRIKE) == 50
        @test weapon_quota(PUDDLE, AIR_STRIKE) == 1
        @test weapon_quota(LAKE, AIR_STRIKE) == 1
        @test weapon_quota(OCEAN, AIR_STRIKE) == 2
    end

    function air_strike_match(; reefs=Set{Tuple{Int, Int}}())
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

    function stock_air_strike!(match)
        for cell in ((2, 2), (2, 3), (3, 1), (3, 2))
            @test player_attack!(match, cell...).result.valid
        end
        @test combat_state(match).player_coins == 50
        @test player_attack!(match, 4, 5).result.outcome == ATTACK_MISS
        while combat_state(match).turn == COMPUTER
            computer_step!(match; rng=MersenneTwister(91))
        end
        @test buy_weapon!(match, PLAYER, AIR_STRIKE).valid
    end

    @testset "processa linha e agrega acertos, afundamentos e moedas" begin
        match = air_strike_match(reefs=Set([(3, 4)]))
        stock_air_strike!(match)

        update = player_air_strike!(match, STRIKE_ROW, 3)

        @test update.result.valid
        @test update.result.cells == [(3, 3), (3, 5)]
        @test update.result.hits == 1
        @test update.result.sunk == 1
        @test update.state.player_coins == 20
        @test update.state.player_inventory[AIR_STRIKE] == 0
        @test update.state.turn == PLAYER
        @test update.directive == AWAIT_PLAYER
    end

    @testset "processa coluna e encerra o turno sem novo acerto" begin
        match = air_strike_match()
        stock_air_strike!(match)

        update = player_air_strike!(match, STRIKE_COLUMN, 4)

        @test update.result.valid
        @test update.result.cells == [(1, 4), (2, 4), (3, 4), (4, 4), (5, 4)]
        @test update.result.hits == 0
        @test update.state.turn == COMPUTER
        @test update.directive == CONTINUE_COMPUTER_TURN
    end

    @testset "exige ao menos uma casa inedita e atacavel" begin
        match = air_strike_match(reefs=Set([(1, 4), (2, 4), (3, 4), (4, 4)]))
        stock_air_strike!(match)
        @test player_attack!(match, 5, 4).result.outcome == ATTACK_MISS
        while combat_state(match).turn == COMPUTER
            computer_step!(match; rng=MersenneTwister(92))
        end

        rejected = player_air_strike!(match, STRIKE_COLUMN, 4)

        @test !rejected.result.valid
        @test rejected.result.rejection == NO_ATTACKABLE_CELLS
        @test rejected.state.player_inventory[AIR_STRIKE] == 1
        @test rejected.state.turn == PLAYER
    end

    @testset "rejeita disparo sem unidade no inventario" begin
        match = air_strike_match()
        rejected = player_air_strike!(match, STRIKE_ROW, 1)

        @test !rejected.result.valid
        @test rejected.result.rejection == WEAPON_UNAVAILABLE
        @test rejected.state.player_inventory[AIR_STRIKE] == 0
        @test rejected.state.turn == PLAYER
    end
end
