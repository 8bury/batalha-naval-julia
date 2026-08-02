@testset "tema da interface" begin
    theme_path = joinpath(@__DIR__, "..", "src", "ui", "theme.css")
    css = read(theme_path, String)

    @test isnothing(match(r"(?m)^button\s*\{", css))
    @test occursin("button.secondary-action", css)
    @test occursin("button.quiet-action", css)
    @test occursin("button.cell-reef", css)
    @test occursin("button.cell-shallow-water", css)
    @test occursin("background: #07141d", css)
    @test occursin("background: #5b95b0", css)
    @test !occursin("#c3a15d", css)
end
