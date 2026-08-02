using Test
using BatalhaNaval

@testset "domínio independente da interface" begin
    loaded_package_names = (package.name for package in keys(Base.loaded_modules))
    @test "Gtk4" ∉ loaded_package_names
end

include("configuration_test.jl")
include("positioning_test.jl")
include("automatic_positioning_test.jl")
include("special_terrain_test.jl")
include("combat_test.jl")
include("computer_strategy_test.jl")
include("theme_css_test.jl")
include("font_rendering_test.jl")
