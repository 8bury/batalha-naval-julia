using Random
using BatalhaNaval.Application

@testset "controllers sem Gtk" begin
    loaded_package_names = (package.name for package in keys(Base.loaded_modules))
    @test "Gtk4" ∉ loaded_package_names
    @test BatalhaNaval.player_air_strike! === BatalhaNaval.Application.player_air_strike!

    setup = SetupController()
    @test !submit_player_name!(setup, "x").valid
    @test submit_player_name!(setup, "  Teste  ").valid
    @test setup_state(setup).player_name == "Teste"
    positioning = start_positioning!(
        setup,
        PUDDLE;
        special_terrain=false,
        rng=MersenneTwister(10),
    )

    selected = select_ship!(positioning, PATROL)
    @test occursin("Patrulha selecionado", selected.message)
    previewed = handle_positioning_cell!(positioning, 1, 1)
    @test previewed.valid == true
    confirmed = confirm_position!(positioning)
    @test confirmed.valid == true
    @test count(cell -> !isnothing(cell.ship_type), confirmed.state.cells) == 1
    @test confirmed.state.selected_ship != PATROL

    cleared = clear_positioning!(positioning)
    @test isnothing(cleared.valid)
    @test count(cell -> !isnothing(cell.ship_type), cleared.state.cells) == 0

    automatic = auto_position!(positioning; rng=MersenneTwister(11))
    @test automatic.valid == true
    @test automatic.state.can_start_combat

    combat = start_combat(positioning)
    update = player_attack!(combat, 1, 1)
    @test update.result.valid
    @test count(cell -> cell.public_state != UNKNOWN, update.state.computer_cells) == 1

    flow = start_positioning!(
        setup,
        PUDDLE;
        special_terrain=false,
        rng=MersenneTwister(12),
    )
    invalid_confirmation = confirm_position!(flow)
    @test invalid_confirmation.valid == false
    @test count(cell -> !isnothing(cell.ship_type), invalid_confirmation.state.cells) == 0

    select_ship!(flow, SUBMARINE)
    horizontal = handle_positioning_cell!(flow, 1, 1)
    @test horizontal.state.can_confirm
    @test horizontal.state.cells[1, 2].previewed

    vertical = toggle_orientation!(flow)
    @test vertical.state.orientation == VERTICAL
    @test vertical.state.cells[2, 1].previewed
    @test !vertical.state.cells[1, 2].previewed

    placed = confirm_position!(flow)
    @test count(cell -> cell.ship_type == SUBMARINE, placed.state.cells) == 2
    removed = handle_positioning_cell!(flow, 2, 1)
    @test count(cell -> !isnothing(cell.ship_type), removed.state.cells) == 0
    @test count(==(SUBMARINE), removed.state.available_ships) == 1
end
