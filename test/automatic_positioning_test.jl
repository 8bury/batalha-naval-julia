using Random

@testset "preenchimento automatico das frotas" begin
    @testset "completa somente os navios restantes e preserva escolhas manuais" begin
        board = create_positioning_board(PUDDLE)
        @test place_ship!(board, PATROL, 1, 1, HORIZONTAL)
        manual_ship = only(positioned_ships(board))

        result = auto_place_ships!(board; rng=MersenneTwister(7))

        @test result.success
        @test occursin("frota", lowercase(result.message))
        @test occursin("automatic", lowercase(result.message))
        @test length(result.placed) == 2
        @test all_ships_placed(board)
        @test only(filter(ship -> ship.id == manual_ship.id, positioned_ships(board))) == manual_ship
        @test length(positioned_ships(board)) == 3
        @test length(unique(placement_cells(board))) == 6
    end

    @testset "falha sem alterar as escolhas quando a frota restante ficou impossível" begin
        layout = TerrainLayout(
            5,
            Set([(row, column) for row in 1:4 for column in 1:5]),
            Set{Tuple{Int, Int}}(),
        )
        board = PositioningBoard(
            PUDDLE,
            5,
            FleetComposition(1, 1, 1),
            layout,
            ShipPlacement[ShipPlacement(1, CRUISER, 5, 1, HORIZONTAL)],
            2,
        )
        before = positioned_ships(board)

        result = auto_place_ships!(board; rng=MersenneTwister(9))

        @test !result.success
        @test occursin("preservando", lowercase(result.message))
        @test occursin("corrija", lowercase(result.message))
        @test positioned_ships(board) == before
        @test !all_ships_placed(board)
    end

    @testset "prepara a frota do computador sob as mesmas regras" begin
        configuration = create_match_configuration("Ana", LAKE; special_terrain=true)
        player_board, computer_board = create_match_boards(
            configuration;
            rng=MersenneTwister(22),
        )

        @test !all_ships_placed(player_board)
        @test all_ships_placed(computer_board)
        @test !battle_ready(player_board, computer_board)
        @test all(
            placement -> all(
                cell -> begin
                    terrain = terrain_at(computer_board, cell...)
                    terrain != REEF &&
                    (isnothing(terrain) || placement.ship_type == PATROL)
                end,
                placement_cells(placement),
            ),
            positioned_ships(computer_board),
        )
    end

    @testset "uma batalha exige as duas frotas completas" begin
        player_board = create_positioning_board(PUDDLE)
        computer_board = create_positioning_board(PUDDLE)

        @test !battle_ready(player_board, computer_board)
        @test auto_place_ships!(player_board; rng=MersenneTwister(1)).success
        @test !battle_ready(player_board, computer_board)
        @test auto_place_ships!(computer_board; rng=MersenneTwister(2)).success
        @test battle_ready(player_board, computer_board)
    end
end
