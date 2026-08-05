@testset "economia, loja e inventario" begin
    function economy_match()
        player = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        enemy = combat_board(ships=[
            ShipPlacement(1, PATROL, 5, 5, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 2, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        return create_combat_match(player, enemy)
    end

    function lake_economy_match()
        fleet = map_option(LAKE).fleet
        layout = TerrainLayout(8, Set{Tuple{Int, Int}}(), Set{Tuple{Int, Int}}())
        player_ships = [
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, PATROL, 1, 3, HORIZONTAL),
            ShipPlacement(3, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(4, SUBMARINE, 3, 1, HORIZONTAL),
            ShipPlacement(5, CRUISER, 4, 1, HORIZONTAL),
        ]
        enemy_ships = [
            ShipPlacement(1, PATROL, 8, 8, HORIZONTAL),
            ShipPlacement(2, PATROL, 8, 7, HORIZONTAL),
            ShipPlacement(3, SUBMARINE, 2, 2, HORIZONTAL),
            ShipPlacement(4, SUBMARINE, 4, 4, HORIZONTAL),
            ShipPlacement(5, CRUISER, 6, 1, HORIZONTAL),
        ]
        player = PositioningBoard(LAKE, 8, fleet, layout, player_ships, 6)
        enemy = PositioningBoard(LAKE, 8, fleet, layout, enemy_ships, 6)
        return create_combat_match(player, enemy)
    end

    @testset "acertos e afundamentos recompensam o participante" begin
        match = economy_match()
        @test combat_state(match).player_coins == 0
        @test combat_state(match).computer_coins == 0

        hit = player_attack!(match, 2, 2)
        @test hit.state.player_coins == 10

        sunk = player_attack!(match, 2, 3)
        @test sunk.result.outcome == ATTACK_SUNK
        @test sunk.state.player_coins == 30
        @test sunk.state.computer_coins == 0
    end

    @testset "a loja valida saldo, acumula inventario e respeita a cota" begin
        match = economy_match()
        initial = combat_state(match)
        denied = buy_weapon!(match, PLAYER, MISSILE)
        @test !denied.valid
        @test denied.rejection == INSUFFICIENT_FUNDS
        @test combat_state(match).player_coins == initial.player_coins
        @test combat_state(match).shop_items == initial.shop_items

        # Sete recompensas observáveis: cinco casas atingidas e dois navios afundados.
        for cell in ((5, 5), (2, 2), (2, 3), (3, 1), (3, 2))
            player_attack!(match, cell...)
        end
        @test combat_state(match).player_coins == 70
        player_attack!(match, 1, 2) # erro: encerra a sequência do jogador
        while combat_state(match).turn == COMPUTER
            computer_step!(match; rng=MersenneTwister(21))
        end

        before = combat_state(match)
        @test before.shop_available
        @test only(filter(item -> item.weapon == MISSILE, before.shop_items)).remaining_quota == 1
        bought = buy_weapon!(match, PLAYER, MISSILE)
        @test bought.valid
        after = combat_state(match)
        @test after.player_coins == 40
        @test after.player_inventory[MISSILE] == 1
        @test after.shop_available

        exhausted = buy_weapon!(match, PLAYER, MISSILE)
        @test !exhausted.valid
        @test exhausted.rejection == QUOTA_EXHAUSTED
        @test combat_state(match).player_inventory[MISSILE] == 1
        @test combat_state(match).player_coins == after.player_coins
        @test combat_state(match).shop_items == after.shop_items
    end

    @testset "a loja fecha no primeiro ataque e reabre no proximo turno" begin
        match = economy_match()
        @test combat_state(match).shop_available
        player_attack!(match, 2, 2)
        @test !combat_state(match).shop_available
        @test buy_weapon!(match, PLAYER, MISSILE).rejection == SHOP_CLOSED

        player_attack!(match, 1, 2)
        while combat_state(match).turn == COMPUTER
            computer_step!(match; rng=MersenneTwister(31))
        end
        @test combat_state(match).shop_available
    end


    @testset "o computador recebe as mesmas recompensas" begin
        player = combat_board(ships=[
            ShipPlacement(1, PATROL, 5, 5, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        enemy = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        match = create_combat_match(player, enemy)
        player_attack!(match, 5, 5) # água no tabuleiro inimigo
        update = computer_step!(match; rng=MersenneTwister(99))
        @test update.result.outcome == ATTACK_SUNK
        @test update.state.computer_coins == 20
        @test update.state.player_coins == 0
    end

    @testset "varias compras persistem entre turnos" begin
        match = lake_economy_match()
        for cell in ((8, 8), (8, 7), (2, 2), (2, 3), (6, 1))
            player_attack!(match, cell...)
        end
        @test combat_state(match).player_coins == 80
        player_attack!(match, 1, 8)
        while combat_state(match).turn == COMPUTER
            computer_step!(match; rng=MersenneTwister(45))
        end

        @test buy_weapon!(match, PLAYER, MISSILE).valid
        @test buy_weapon!(match, PLAYER, AIR_STRIKE).valid
        purchased = combat_state(match)
        @test purchased.player_coins == 0
        @test purchased.player_inventory[MISSILE] == 1
        @test purchased.player_inventory[AIR_STRIKE] == 1

        player_attack!(match, 1, 7)
        while combat_state(match).turn == COMPUTER
            computer_step!(match; rng=MersenneTwister(46))
        end
        later = combat_state(match)
        @test later.player_inventory == purchased.player_inventory
        @test later.shop_available
    end
end
