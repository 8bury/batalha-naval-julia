using Random

function public_knowledge(dimension=5; states=Pair{Tuple{Int, Int}, PublicCellState}[])
    knowledge = fill(UNKNOWN, dimension, dimension)
    for (cell, state) in states
        knowledge[cell...] = state
    end
    return knowledge
end

@testset "IA de caca e perseguicao" begin
    @testset "caca escolhe uma casa desconhecida com aleatoriedade controlada" begin
        knowledge = public_knowledge(states=[
            (1, 1) => WATER,
            (2, 2) => PUBLIC_REEF,
            (3, 3) => SUNK,
        ])

        first_choice = choose_attack(ComputerStrategy(), knowledge; rng=MersenneTwister(17))
        repeated_choice = choose_attack(ComputerStrategy(), knowledge; rng=MersenneTwister(17))

        @test first_choice == repeated_choice
        @test knowledge[first_choice...] == UNKNOWN
    end

    @testset "um acerto prioriza vizinhos ortogonais desconhecidos" begin
        knowledge = public_knowledge(states=[
            (3, 3) => DAMAGED,
            (2, 3) => WATER,
            (3, 2) => WATER,
            (4, 3) => WATER,
        ])
        strategy = ComputerStrategy()
        record_attack!(strategy, (3, 3), ATTACK_HIT, knowledge)

        @test choose_attack(strategy, knowledge; rng=MersenneTwister(1)) == (3, 4)
    end

    @testset "acertos alinhados continuam na direcao conhecida" begin
        knowledge = public_knowledge(states=[
            (3, 2) => DAMAGED,
            (3, 3) => DAMAGED,
            (3, 1) => WATER,
        ])
        strategy = ComputerStrategy()
        record_attack!(strategy, (3, 2), ATTACK_HIT, knowledge)
        record_attack!(strategy, (3, 3), ATTACK_HIT, knowledge)

        @test choose_attack(strategy, knowledge; rng=MersenneTwister(1)) == (3, 4)
    end

    @testset "afundamento encerra a perseguicao correspondente" begin
        strategy = ComputerStrategy()
        damaged = public_knowledge(states=[(2, 2) => DAMAGED, (2, 3) => DAMAGED])
        record_attack!(strategy, (2, 2), ATTACK_HIT, damaged)
        record_attack!(strategy, (2, 3), ATTACK_HIT, damaged)

        sunk = public_knowledge(states=[(2, 2) => SUNK, (2, 3) => SUNK])
        record_attack!(strategy, (2, 3), ATTACK_SUNK, sunk)

        @test isempty(strategy.pending_hits)
        @test sunk[choose_attack(strategy, sunk; rng=MersenneTwister(9))...] == UNKNOWN
    end

    @testset "cada chamada aplica somente um ataque usando a visao publica" begin
        player = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        enemy = combat_board(ships=[
            ShipPlacement(1, PATROL, 5, 5, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 4, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        match = create_combat_match(player, enemy)
        match.turn = COMPUTER

        result = computer_attack!(match, ComputerStrategy(); rng=MersenneTwister(4))

        @test result.valid
        @test length(match.computer_attacks) == 1
    end

    @testset "frotas ocultas diferentes nao alteram a decisao" begin
        first_player = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        second_player = combat_board(ships=[
            ShipPlacement(1, PATROL, 5, 5, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 4, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 1, 2, HORIZONTAL),
        ])
        enemy = combat_board(ships=[
            ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
            ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
            ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
        ])
        first_match = create_combat_match(first_player, enemy)
        second_match = create_combat_match(second_player, deepcopy(enemy))
        first_match.turn = COMPUTER
        second_match.turn = COMPUTER

        first = computer_attack!(first_match, ComputerStrategy(); rng=MersenneTwister(23))
        second = computer_attack!(second_match, ComputerStrategy(); rng=MersenneTwister(23))

        @test (first.row, first.column) == (second.row, second.column)
    end
end
