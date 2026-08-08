@testset "instruções e entrega" begin
    root = joinpath(@__DIR__, "..")
    information = read(joinpath(root, "src", "views", "pages", "InformationPage.jl"), String)
    battle = read(joinpath(root, "src", "views", "pages", "BattlePage.jl"), String)
    window = read(joinpath(root, "src", "views", "ApplicationWindow.jl"), String)
    ranking = read(joinpath(root, "src", "views", "pages", "RankingPage.jl"), String)
    readme = read(joinpath(root, "README.md"), String)

    for section in ("Objetivo", "Configuração e posicionamento", "Turnos e terrenos",
                    "Economia e loja", "Armas", "Pontuação e ranking", "Símbolos")
        @test occursin(section, information)
    end
    @test occursin("modal=false", information)
    @test occursin("Abandonar partida", battle)
    @test occursin("resultado não será classificado", read(joinpath(root, "src", "views", "pages", "MainMenuPage.jl"), String))
    @test occursin("GtkScrolledWindow", battle)
    @test occursin("GtkScrolledWindow", read(joinpath(root, "src", "views", "pages", "PositioningPage.jl"), String))
    @test occursin("1280, 800", window)
    @test occursin("width_request = 1000", window)
    @test occursin("height_request = 650", window)
    ranking_height = match(r"RANKING_MIN_CONTENT_HEIGHT\s*=\s*(\d+)", ranking)
    @test !isnothing(ranking_height)
    @test parse(Int, ranking_height.captures[1]) >= 120
    @test occursin("scroll.min_content_height = RANKING_MIN_CONTENT_HEIGHT", ranking)

    for launcher in ("run.ps1", "run.sh")
        script = read(joinpath(root, launcher), String)
        @test occursin("Pkg.instantiate()", script)
        @test occursin("--project=", script)
        @test occursin("--startup-file=no", script)
    end
    @test occursin("Dados locais", readme)
    @test occursin("Arch Linux: escopo da verificação", readme)
    @test isfile(joinpath(root, "docs", "manual-validation-windows.md"))
end
