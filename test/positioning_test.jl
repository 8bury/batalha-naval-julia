@testset "posicionamento manual classico" begin
    @testset "cria tabuleiros com dimensoes e frotas do mapa" begin
        expected = [
            (PUDDLE, 5, FleetComposition(1, 1, 1)),
            (LAKE, 8, FleetComposition(2, 2, 1)),
            (OCEAN, 10, FleetComposition(3, 2, 2)),
        ]

        for (map, dimension, fleet) in expected
            board = create_positioning_board(map)

            @test board.dimension == dimension
            @test board.fleet == fleet
            @test isempty(positioned_ships(board))
            @test length(available_ships(board)) == sum((fleet.patrols, fleet.submarines, fleet.cruisers))
        end
    end

    @testset "diferencia preview valida de invalida" begin
        board = create_positioning_board(PUDDLE)

        valid = preview_placement(board, PATROL, 1, 1, HORIZONTAL)
        @test valid.valid
        @test valid.cells == [(1, 1)]

        vertical = preview_placement(board, CRUISER, 2, 4, VERTICAL)
        @test vertical.valid
        @test vertical.cells == [(2, 4), (3, 4), (4, 4)]

        @test place_ship!(board, PATROL, 1, 1, HORIZONTAL)
        @test !preview_placement(board, SUBMARINE, 1, 1, HORIZONTAL).valid
        @test !preview_placement(board, CRUISER, 4, 4, HORIZONTAL).valid
        @test !preview_placement(board, SUBMARINE, 1, 5, HORIZONTAL).valid
    end

    @testset "permite contato sem permitir sobreposicao" begin
        board = create_positioning_board(PUDDLE)
        @test place_ship!(board, PATROL, 1, 1, HORIZONTAL)

        @test preview_placement(board, SUBMARINE, 1, 2, HORIZONTAL).valid
        @test preview_placement(board, SUBMARINE, 2, 2, HORIZONTAL).valid
        @test place_ship!(board, SUBMARINE, 2, 2, HORIZONTAL)

        overlap = preview_placement(board, CRUISER, 1, 1, VERTICAL)
        @test !overlap.valid
        @test occursin("sobre", lowercase(overlap.message))
    end

    @testset "remove uma embarcacao pelo clique e limpa o tabuleiro" begin
        board = create_positioning_board(PUDDLE)
        @test place_ship!(board, PATROL, 1, 1, HORIZONTAL)
        @test place_ship!(board, SUBMARINE, 2, 2, HORIZONTAL)
        @test length(positioned_ships(board)) == 2

        @test remove_ship_at!(board, 2, 3)
        @test length(positioned_ships(board)) == 1
        @test length(available_ships(board)) == 2
        @test !remove_ship_at!(board, 5, 5)

        clear_board!(board)
        @test isempty(positioned_ships(board))
        @test length(available_ships(board)) == 3
        @test board.dimension == 5
        @test board.fleet == FleetComposition(1, 1, 1)
    end
end
