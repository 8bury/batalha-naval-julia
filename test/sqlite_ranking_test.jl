using Dates

@testset "persistencia SQLite e ranking por mapa" begin
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

        player, computer = create_match_boards(config)
        auto_place_ships!(player)
        controller = CombatController(player, computer; configuration=config,
                                      repository, completion_key="controller", clock=() -> 10.0)
        @test !save_completed_result!(controller)
        @test length(top_results(repository, PUDDLE; limit=30)) == 13
        enemy_cells = collect(Iterators.flatten(placement_cells.(computer.placements)))
        final_cell = pop!(enemy_cells)
        union!(controller.match.player_attacks, enemy_cells)
        @test player_attack!(controller, final_cell...).state.winner == PLAYER
        @test controller.result_saved
        @test !save_completed_result!(controller)
        @test length(top_results(repository, PUDDLE; limit=30)) == 14
        close(repository)
    end
end
