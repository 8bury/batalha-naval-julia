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

        result = attack!(match, PLAYER, 2, 2)

        @test result.valid
        @test result.outcome == ATTACK_HIT
        @test public_cell(match, COMPUTER, 2, 2) == DAMAGED
        @test match.turn == PLAYER
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

        @test !attack!(match, PLAYER, 1, 1).valid
        @test match.turn == PLAYER
        @test attack!(match, PLAYER, 2, 2).outcome == ATTACK_HIT
        @test !attack!(match, PLAYER, 2, 2).valid
        @test match.turn == PLAYER
        @test length(match.player_attacks) == 1
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

        @test attack!(match, PLAYER, 2, 2).outcome == ATTACK_HIT
        @test attack!(match, PLAYER, 2, 3).outcome == ATTACK_SUNK
        @test public_cell(match, COMPUTER, 2, 2) == SUNK
        @test public_cell(match, COMPUTER, 2, 3) == SUNK
        @test match.turn == PLAYER
        @test attack!(match, PLAYER, 1, 2).outcome == ATTACK_MISS
        @test public_cell(match, COMPUTER, 1, 2) == WATER
        @test match.turn == COMPUTER
    end

    @testset "a partida termina imediatamente com a frota destruida" begin
        player = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        enemy = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        match = create_combat_match(player, enemy)

        for cell in [(1, 1), (2, 1), (2, 2), (3, 1), (3, 2)]
            @test attack!(match, PLAYER, cell...).valid
        end
        final = attack!(match, PLAYER, 3, 3)

        @test final.outcome == ATTACK_SUNK
        @test match.winner == PLAYER
        @test !attack!(match, PLAYER, 5, 5).valid
    end

    @testset "o computador ataca ate errar sem escolher recife ou repeticao" begin
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
        @test attack!(match, PLAYER, 5, 4).outcome == ATTACK_MISS

        results = computer_turn!(match; rng=MersenneTwister(4))

        @test !isempty(results)
        @test all(result -> result.valid, results)
        @test length(match.computer_attacks) == length(results)
        @test !((5, 5) in match.computer_attacks)
        @test !isnothing(match.winner) || last(results).outcome == ATTACK_MISS
    end
end
