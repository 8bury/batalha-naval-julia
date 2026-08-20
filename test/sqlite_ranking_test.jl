using Dates

@testset "persistencia SQLite e ranking por mapa" begin
    withenv("BATALHA_NAVAL_DATA_DIR" => nothing) do
        expected = normpath(joinpath(@__DIR__, "..", "data", "ranking.sqlite3"))
        @test default_results_path() == expected
    end

    mktempdir() do directory
        database = joinpath(directory, "dados", "ranking.sqlite3")
        repository = SQLiteResultRepository(database)
        @test isfile(database)

        function result(score, duration; won=true, hits=3)
            breakdown = ScoreBreakdown(0, 0, 0, 0, 0, score)
            MatchSummary(won, duration, hits, 2, 4, 0, breakdown)
        end

        config = MatchConfiguration("Ana", PUDDLE, true)
        base = DateTime(2026, 1, 1, 12)
        save_result!(repository, "same", config, result(900, 40); completed_at=base)
        save_result!(repository, "same", config, result(9999, 1); completed_at=base)
        @test length(top_results(repository, PUDDLE)) == 1
        @test top_results(repository, PUDDLE)[1].score == 900

        for index in 1:12
            score = index <= 4 ? 1000 : 1000 + index
            duration = index <= 4 ? (index == 1 ? 30 : 20) : 60
            stamp = base + Second(index == 2 ? 2 : index)
            save_result!(repository, "p$index", config, result(score, duration; won=isodd(index));
                         completed_at=stamp)
        end
        lake = MatchConfiguration("Bia", LAKE, false)
        save_result!(repository, "lake", lake, result(5000, 10); completed_at=base)

        puddle = top_results(repository, PUDDLE)
        @test length(puddle) == 10
        @test all(entry -> entry.map == PUDDLE, puddle)
        @test isempty(top_results(repository, OCEAN))
        @test only(top_results(repository, LAKE)).player_name == "Bia"
        @test issorted([(entry.score, -entry.duration_seconds) for entry in puddle]; rev=true)
        tied = filter(entry -> entry.score == 1000, top_results(repository, PUDDLE; limit=20))
        @test [entry.duration_seconds for entry in tied] == [20, 20, 20, 30]
        @test tied[1].completed_at < tied[2].completed_at < tied[3].completed_at

        player = create_positioning_board(PUDDLE)
        computer = create_positioning_board(PUDDLE)
        for board in (player, computer)
            place_ship!(board, CRUISER, 1, 1, HORIZONTAL)
            place_ship!(board, SUBMARINE, 2, 1, HORIZONTAL)
            place_ship!(board, PATROL, 3, 1, HORIZONTAL)
        end
        controller = CombatController(player, computer; configuration=config,
                                      repository, completion_key="controller", clock=() -> 10.0)
        @test !save_completed_result!(controller)
        @test length(top_results(repository, PUDDLE; limit=30)) == 13
        update = nothing
        for cell in placement_cells(computer)
            update = player_attack!(controller, cell...)
        end
        @test update.state.winner == PLAYER
        @test !save_completed_result!(controller)
        @test length(top_results(repository, PUDDLE; limit=30)) == 14

        defeat_config = MatchConfiguration("Carlos", OCEAN, false)
        defeated_player, victorious_computer = create_match_boards(defeat_config)
        auto_place_ships!(defeated_player)
        finished_at = DateTime(2026, 2, 3, 4, 5, 6, 789)
        clock_value = [2.0]
        defeat = CombatController(defeated_player, victorious_computer;
            configuration=defeat_config, repository, completion_key="defeat",
            clock=() -> clock_value[], completed_at=() -> finished_at)
        occupied = Set(placement_cells(victorious_computer))
        misses = [(row, column) for row in 1:10 for column in 1:10
                  if (row, column) ∉ occupied]
        update = player_attack!(defeat, popfirst!(misses)...)
        clock_value[] = 12.0
        while isnothing(update.state.winner)
            update = computer_step!(defeat)
            if isnothing(update.state.winner) && update.state.turn == PLAYER
                update = player_attack!(defeat, popfirst!(misses)...)
            end
        end
        @test update.state.winner == COMPUTER
        @test !save_completed_result!(defeat)

        persisted = only(top_results(repository, OCEAN; limit=20))
        @test persisted.player_name == "Carlos"
        @test persisted.map == OCEAN
        @test persisted.score == 990
        @test persisted.duration_seconds == 10
        @test !persisted.won
        @test persisted.completed_at == "2026-02-03T04:05:06.789"
        @test !persisted.special_terrain
        @test persisted.hits == 0
        @test persisted.surviving_ships == 0
        @test persisted.intact_cells == 0
        close(repository)
    end
end
