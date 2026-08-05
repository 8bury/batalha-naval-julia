@testset "renderização de fontes no Windows" begin
    launcher_path = joinpath(@__DIR__, "..", "bin", "batalha-naval.jl")
    application_path = joinpath(@__DIR__, "..", "src", "views", "GtkApplication.jl")
    launcher = read(launcher_path, String)
    application = read(application_path, String)

    backend_position = findfirst("ENV[\"PANGOCAIRO_BACKEND\"] = \"fc\"", launcher)
    gtk_position = findfirst("GtkApplication.jl", launcher)

    @test !isnothing(backend_position)
    @test !isnothing(gtk_position)
    if !isnothing(backend_position) && !isnothing(gtk_position)
        @test first(backend_position) < first(gtk_position)
    end
    @test !occursin("FontRendering_MANUAL", application)
end
