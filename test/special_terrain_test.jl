using Random

@testset "terrenos especiais" begin
    @testset "limites seguem o balanceamento de cada mapa" begin
        @test (max_reefs(PUDDLE), max_shallow_waters(PUDDLE)) == (2, 2)
        @test (max_reefs(LAKE), max_shallow_waters(LAKE)) == (4, 4)
        @test (max_reefs(OCEAN), max_shallow_waters(OCEAN)) == (6, 6)
    end

    @testset "sorteia quantidades independentes dentro dos limites" begin
        layout = create_terrain_layout(PUDDLE; rng=MersenneTwister(11))

        @test length(reef_cells(layout)) <= max_reefs(PUDDLE)
        @test length(shallow_water_cells(layout)) <= max_shallow_waters(PUDDLE)
        @test terrain_limits(PUDDLE).max_reefs == max_reefs(PUDDLE)
        @test isempty(intersect(reef_cells(layout), shallow_water_cells(layout)))
        @test all(cell -> terrain_at(layout, cell...) == REEF, reef_cells(layout))
        @test all(
            cell -> terrain_at(layout, cell...) == SHALLOW_WATER,
            shallow_water_cells(layout),
        )
    end

    @testset "todo layout sorteado comporta a frota e respeita o mapa" begin
        for map in (PUDDLE, LAKE, OCEAN)
            for seed in 1:12
                layout = create_terrain_layout(map; rng=MersenneTwister(seed))
                @test terrain_layout_supports_fleet(layout, map_option(map).fleet)
                @test all(
                    cell -> 1 <= cell[1] <= map_option(map).dimension &&
                            1 <= cell[2] <= map_option(map).dimension,
                    terrain_cells(layout),
                )
            end
        end
    end

    @testset "layout compartilhado e terrenos desabilitados" begin
        configuration = create_match_configuration("Ana", LAKE; special_terrain=true)
        player_board, computer_board = create_match_boards(
            configuration;
            rng=MersenneTwister(22),
        )

        @test player_board.terrain == computer_board.terrain
        @test terrain_cells(player_board) == terrain_cells(computer_board)
        @test create_match_boards(configuration; rng=MersenneTwister(22))[1].terrain ==
              player_board.terrain

        classic = create_match_configuration("Ana", LAKE; special_terrain=false)
        classic_player, classic_computer = create_match_boards(classic; rng=MersenneTwister(22))
        @test isempty(terrain_cells(classic_player))
        @test isempty(terrain_cells(classic_computer))
    end

    @testset "recifes bloqueiam navios e aguas rasas aceitam apenas patrulhas" begin
        layout = TerrainLayout(
            5,
            Set([(1, 1)]),
            Set([(2, 2)]),
        )
        board = create_positioning_board(PUDDLE; terrain_layout=layout)

        @test !preview_placement(board, PATROL, 1, 1, HORIZONTAL).valid
        @test !preview_placement(board, SUBMARINE, 2, 2, HORIZONTAL).valid
        @test preview_placement(board, PATROL, 2, 2, HORIZONTAL).valid
        @test !preview_placement(board, PATROL, 1, 1, HORIZONTAL).valid
        @test occursin("recife", lowercase(preview_placement(board, PATROL, 1, 1, HORIZONTAL).message))
    end

    @testset "configuracoes inviaveis sao rejeitadas antes de serem usadas" begin
        impossible = TerrainLayout(
            5,
            Set([(row, column) for row in 1:4 for column in 1:5]),
            Set([(5, column) for column in 1:5]),
        )

        @test !terrain_layout_supports_fleet(impossible, FleetComposition(1, 1, 1))
        @test_throws ArgumentError create_positioning_board(
            PUDDLE;
            terrain_layout=impossible,
        )
    end

    @testset "simbolos e dicas identificam os terrenos" begin
        @test terrain_symbol(REEF) != terrain_symbol(SHALLOW_WATER)
        @test terrain_label(REEF) == "Recife"
        @test terrain_label(SHALLOW_WATER) == "Águas Rasas"
        @test occursin("recife", lowercase(terrain_tooltip(REEF)))
        @test occursin("rasas", lowercase(terrain_tooltip(SHALLOW_WATER)))
    end
end
