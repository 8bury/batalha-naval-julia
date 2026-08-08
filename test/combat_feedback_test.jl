function feedback_board()
    return combat_board(ships=[
        ShipPlacement(1, PATROL, 1, 1, HORIZONTAL),
        ShipPlacement(2, SUBMARINE, 2, 1, HORIZONTAL),
        ShipPlacement(3, CRUISER, 3, 1, HORIZONTAL),
    ])
end

@testset "feedback usa eventos reais de ambos os participantes" begin
    player_basic = create_combat_match(feedback_board(), feedback_board())
    miss = player_attack!(player_basic, 5, 5).state.history[end]
    @test miss.actor == PLAYER
    @test combat_feedback(miss) == CombatFeedback(WATER_SOUND, false)

    computer_basic = create_combat_match(feedback_board(), feedback_board())
    computer_basic.turn = COMPUTER
    hit = BatalhaNaval.resolve_attack!(computer_basic, COMPUTER, 3, 1)
    hit_event = combat_state(computer_basic).history[end]
    @test hit.outcome == ATTACK_HIT
    @test hit_event.actor == COMPUTER
    @test isempty(hit_event.sunk_ships)
    @test combat_feedback(hit_event) == CombatFeedback(EXPLOSION_SOUND, false)
    @test combat_completion_delay_ms(hit_event) == 0

    player_special = create_combat_match(feedback_board(), feedback_board())
    union!(player_special.player_attacks, ((2, 2), (3, 2), (3, 3)))
    player_special.inventories[PLAYER][AIR_STRIKE] = 1
    player_update = player_air_strike!(player_special, STRIKE_COLUMN, 1)
    multi_sunk = player_update.state.history[end]
    @test multi_sunk.actor == PLAYER
    @test multi_sunk.weapon == AIR_STRIKE
    @test Set(multi_sunk.sunk_ships) == Set((PATROL, SUBMARINE, CRUISER))
    @test combat_feedback(multi_sunk) == CombatFeedback(EXPLOSION_SOUND, true)
    @test 300 <= combat_completion_delay_ms(multi_sunk) <= 350

    computer_special = create_combat_match(feedback_board(), feedback_board())
    computer_special.turn = COMPUTER
    union!(computer_special.computer_attacks, ((2, 2),))
    computer_special.inventories[COMPUTER][AIR_STRIKE] = 1
    computer_update = BatalhaNaval.resolve_air_strike!(computer_special, COMPUTER, STRIKE_COLUMN, 1)
    no_cruiser = combat_state(computer_special).history[end]
    @test computer_update.valid
    @test no_cruiser.actor == COMPUTER
    @test no_cruiser.weapon == AIR_STRIKE
    @test Set(no_cruiser.sunk_ships) == Set((PATROL, SUBMARINE))
    @test CRUISER ∉ no_cruiser.sunk_ships
    @test combat_feedback(no_cruiser) == CombatFeedback(EXPLOSION_SOUND, false)
end

@testset "entrega de feedback é deduplicada" begin
    match = create_combat_match(feedback_board(), feedback_board())
    player_attack!(match, 5, 5)
    first_delivery = pending_feedback_events(combat_state(match).history, 0)
    @test length(first_delivery.events) == 1
    repeated = pending_feedback_events(combat_state(match).history, first_delivery.delivered)
    @test isempty(repeated.events)
    @test repeated.delivered == first_delivery.delivered
end
