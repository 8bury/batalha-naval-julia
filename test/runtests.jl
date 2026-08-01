using Test
using BatalhaNaval

@testset "domínio independente da interface" begin
    loaded_package_names = (package.name for package in keys(Base.loaded_modules))
    @test "Gtk4" ∉ loaded_package_names
end

include("configuration_test.jl")
