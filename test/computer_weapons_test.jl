using Random

@testset "armas especiais da IA" begin
    function computer_weapons_match(; player_ships=[
        ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
        ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
        ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
    ])
        player = combat_board(ships=player_ships)
        computer = combat_board(ships=[
            ShipPlacement(1, PATROL, 5, 5, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 4, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        match = create_combat_match(player, computer)
        @test player_attack!(match, 1, 1).directive == CONTINUE_COMPUTER_TURN
        return match
    end

    @testset "prioriza ataque aereo, compra e usa imediatamente" begin
        match = computer_weapons_match()
        match.coins[COMPUTER] = 50

        update = computer_step!(match; rng=MersenneTwister(10))

        @test update isa AirStrikeUpdate
        @test update.result.valid
        @test update.state.computer_coins == 10 * (update.result.hits + update.result.sunk)
        @test update.state.computer_inventory[AIR_STRIKE] == 0
        event = update.state.history[end]
        @test event.actor == COMPUTER
        @test event.weapon == AIR_STRIKE
        @test occursin("Computador - Ataque Aéreo:", event.message)
        @test all(ship -> occursin(ship_label(ship), event.message) == (ship in event.sunk_ships), (PATROL, SUBMARINE, CRUISER))
    end

    @testset "usa missil quando ataque aereo nao esta disponivel" begin
        match = computer_weapons_match()
        match.coins[COMPUTER] = 50
        match.purchased[COMPUTER][AIR_STRIKE] = weapon_quota(PUDDLE, AIR_STRIKE)

        update = computer_step!(match; rng=MersenneTwister(11))

        @test update isa MissileUpdate
        @test update.result.valid
        @test update.state.computer_coins == 20 + 10 * (update.result.hits + update.result.sunk)
        @test update.state.computer_inventory[MISSILE] == 0
        event = update.state.history[end]
        @test event.actor == COMPUTER
        @test event.weapon == MISSILE
        @test occursin("Computador - Míssil:", event.message)
        @test all(ship -> occursin(ship_label(ship), event.message) == (ship in event.sunk_ships), (PATROL, SUBMARINE, CRUISER))
    end

    @testset "sem arma utilizavel executa o ataque basico" begin
        match = computer_weapons_match()
        match.coins[COMPUTER] = 29

        update = computer_step!(match; rng=MersenneTwister(12))

        @test update isa CombatUpdate
        @test update.result.valid
        @test update.state.computer_coins in (29, 39, 49)
    end

    @testset "escolha depende apenas do conhecimento publico" begin
        first = computer_weapons_match()
        second = computer_weapons_match(player_ships=[
            ShipPlacement(1, PATROL, 5, 5, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 4, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 1, 2, HORIZONTAL),
        ])
        first.coins[COMPUTER] = 50
        second.coins[COMPUTER] = 50

        first_update = computer_step!(first; rng=MersenneTwister(13))
        second_update = computer_step!(second; rng=MersenneTwister(13))

        @test first_update isa AirStrikeUpdate
        @test second_update isa AirStrikeUpdate
        @test (first_update.result.axis, first_update.result.index) ==
              (second_update.result.axis, second_update.result.index)
    end
end
