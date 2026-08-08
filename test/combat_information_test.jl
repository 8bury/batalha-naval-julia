@testset "informação pública e histórico" begin
    player = combat_board(ships=[
        ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
        ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
        ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
    ])
    enemy = combat_board(ships=[
        ShipPlacement(1, PATROL, 5, 5, HORIZONTAL),
        ShipPlacement(2, SUBMARINE, 2, 2, HORIZONTAL),
        ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
    ])
    match = create_combat_match(player, enemy)

    hit = player_attack!(match, 2, 2).state
    @test hit.computer_cells[2, 2].revealed_ship_type === nothing
    @test hit.computer_fleet[2].state == FLEET_HIDDEN
    @test isempty(hit.computer_fleet[2].cells)
    @test hit.history[1].message == "Jogador — B2: acerto."
    @test !occursin("Submarino", hit.history[1].message)

    sunk = player_attack!(match, 2, 3).state
    @test sunk.computer_cells[2, 2].revealed_ship_type == SUBMARINE
    @test sunk.computer_cells[2, 3].revealed_ship_type == SUBMARINE
    @test sunk.computer_fleet[2].ship_type == SUBMARINE
    @test sunk.computer_fleet[2].state == FLEET_SUNK
    @test sunk.computer_fleet[2].cells == [(2, 2), (2, 3)]
    @test occursin("Submarino", sunk.history[end].message)

    @test sunk.player_fleet[1].state == FLEET_INTACT
    @test all(status -> status.state != FLEET_DAMAGED, sunk.computer_fleet)

    for cell in ((1, 2), (1, 3), (1, 4), (1, 5))
        if combat_state(match).turn == COMPUTER
            match.turn = PLAYER
        end
        player_attack!(match, cell...)
    end
    state = combat_state(match)
    @test length(state.history) == 6
    @test length(state.recent_events) == 5
    @test state.recent_events[1] == state.history[end]
    @test state.recent_events[end] == state.history[2]
end


@testset "histórico registra o computador" begin
    player = combat_board(ships=[
        ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
        ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
        ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
    ])
    match = create_combat_match(player, deepcopy(player))
    match.turn = COMPUTER
    computer = computer_step!(match; rng=MersenneTwister(202)).state.history[end]
    @test computer.actor == COMPUTER
    @test startswith(computer.message, "Computador — ")
end
