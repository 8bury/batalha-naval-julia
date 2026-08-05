using Random

function combat_board(; reefs=Set{Tuple{Int, Int}}(), ships)
    layout = TerrainLayout(5, reefs, Set{Tuple{Int, Int}}())
    return PositioningBoard(
        PUDDLE,
        5,
        FleetComposition(1, 1, 1),
        layout,
        ShipPlacement[ships...],
        length(ships) + 1,
    )
end

function observed_attacks(state::CombatState, owner::Participant)
    cells = owner == PLAYER ? state.player_cells : state.computer_cells
    return count(cell -> cell.public_state in (WATER, DAMAGED, SUNK), cells)
end

@testset "combate basico" begin
    @testset "um ataque valido processa uma coordenada desconhecida" begin
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
        match = create_combat_match(player, enemy)

        update = player_attack!(match, 2, 2)

        @test update.result.valid
        @test update.result.outcome == ATTACK_HIT
        @test update.state.computer_cells[2, 2].public_state == DAMAGED
        @test update.state.turn == PLAYER
        @test update.directive == AWAIT_PLAYER
    end

    @testset "tentativas invalidas e repetidas nao desperdicam a jogada" begin
        player = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        enemy = combat_board(
            reefs=Set([(1, 1)]),
            ships=[
                ShipPlacement(1, PATROL, 5, 5, HORIZONTAL),
                ShipPlacement(2, SUBMARINE, 2, 2, HORIZONTAL),
                ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
            ],
        )
        match = create_combat_match(player, enemy)

        reef = player_attack!(match, 1, 1)
        @test !reef.result.valid
        @test reef.result.rejection == REEF_TARGET
        @test reef.state.turn == PLAYER

        hit = player_attack!(match, 2, 2)
        repeated = player_attack!(match, 2, 2)
        @test hit.result.outcome == ATTACK_HIT
        @test !repeated.result.valid
        @test repeated.result.rejection == ALREADY_ATTACKED
        @test repeated.state.turn == PLAYER
        @test observed_attacks(repeated.state, COMPUTER) == 1
    end

    @testset "acertos encadeiam, erro troca o turno e navios afundam" begin
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
        match = create_combat_match(player, enemy)

        @test player_attack!(match, 2, 2).result.outcome == ATTACK_HIT
        sunk = player_attack!(match, 2, 3)
        @test sunk.result.outcome == ATTACK_SUNK
        @test sunk.state.computer_cells[2, 2].public_state == SUNK
        @test sunk.state.computer_cells[2, 3].public_state == SUNK
        @test sunk.state.turn == PLAYER

        miss = player_attack!(match, 1, 2)
        @test miss.result.outcome == ATTACK_MISS
        @test miss.state.computer_cells[1, 2].public_state == WATER
        @test miss.state.turn == COMPUTER
        @test miss.directive == CONTINUE_COMPUTER_TURN
    end

    @testset "a partida termina imediatamente com a frota destruida" begin
        player = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        enemy = deepcopy(player)
        match = create_combat_match(player, enemy)

        for cell in [(1, 1), (2, 1), (2, 2), (3, 1), (3, 2)]
            @test player_attack!(match, cell...).result.valid
        end
        final = player_attack!(match, 3, 3)

        @test final.result.outcome == ATTACK_SUNK
        @test final.state.winner == PLAYER
        @test final.directive == END_COMBAT
        rejected = player_attack!(match, 5, 5)
        @test rejected.result.rejection == MATCH_FINISHED
        @test rejected.directive == END_COMBAT
    end

    @testset "cada passo do computador aplica somente um ataque" begin
        player = combat_board(
            reefs=Set([(5, 5)]),
            ships=[
                ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
                ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
                ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
            ],
        )
        enemy = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        match = create_combat_match(player, enemy)
        @test player_attack!(match, 5, 4).directive == CONTINUE_COMPUTER_TURN

        before = combat_state(match)
        update = computer_step!(match; rng=MersenneTwister(4))

        @test update.result.valid
        @test observed_attacks(update.state, PLAYER) == observed_attacks(before, PLAYER) + 1
        @test update.state.player_cells[5, 5].public_state == PUBLIC_REEF
        @test update.directive in (AWAIT_PLAYER, CONTINUE_COMPUTER_TURN, END_COMBAT)
    end
end
