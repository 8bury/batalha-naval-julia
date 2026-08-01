@testset "configuração da partida" begin
    @testset "normaliza e aceita nomes válidos" begin
        result = validate_player_name("  João da-Silva_2  ")

        @test result.valid
        @test result.normalized == "João da-Silva_2"
        @test isempty(result.message)
    end

    @testset "explica por que nomes inválidos não podem avançar" begin
        too_short = validate_player_name(" A ")
        invalid_character = validate_player_name("Ana@Maria")

        @test !too_short.valid
        @test too_short.message == "O nome deve ter entre 2 e 20 caracteres."
        @test !invalid_character.valid
        @test invalid_character.message == "Use apenas letras, números, espaços, hífen e sublinhado."
    end

    @testset "oferece os três mapas com suas frotas" begin
        options = map_options()

        @test [(option.name, option.dimension) for option in options] == [
            ("Poça", 5),
            ("Lago", 8),
            ("Oceano", 10),
        ]
        @test options[1].fleet == FleetComposition(1, 1, 1)
        @test options[2].fleet == FleetComposition(2, 2, 1)
        @test options[3].fleet == FleetComposition(3, 2, 2)
    end

    @testset "cria configuração com terrenos habilitados por padrão" begin
        configuration = create_match_configuration("  Lúcia 7 ", PUDDLE)

        @test configuration.player_name == "Lúcia 7"
        @test configuration.map == PUDDLE
        @test configuration.special_terrain
    end

    @testset "permite desabilitar terrenos especiais" begin
        configuration = create_match_configuration(
            "Lúcia 7",
            LAKE;
            special_terrain=false,
        )

        @test !configuration.special_terrain
    end

    @testset "protege a validação no valor de configuração público" begin
        @test_throws ArgumentError MatchConfiguration("A@", PUDDLE, true)
    end
end
