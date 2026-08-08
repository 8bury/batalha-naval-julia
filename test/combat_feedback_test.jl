@testset "feedback audiovisual do combate" begin
    miss = CombatEvent(PLAYER, nothing, "A1", ATTACK_MISS, 0, ShipType[], "Jogador — A1: água.")
    hit = CombatEvent(COMPUTER, nothing, "B2", ATTACK_HIT, 1, ShipType[], "Computador — B2: acerto.")
    cruiser = CombatEvent(PLAYER, MISSILE, "", ATTACK_SUNK, 3, [CRUISER], "Jogador — Míssil: afundou Cruzador.")
    submarine = CombatEvent(COMPUTER, AIR_STRIKE, "", ATTACK_SUNK, 2, [SUBMARINE], "Computador — Ataque Aéreo: afundou Submarino.")

    @test combat_feedback(miss) == CombatFeedback(WATER_SOUND, false)
    @test combat_feedback(hit) == CombatFeedback(EXPLOSION_SOUND, false)
    @test combat_feedback(cruiser) == CombatFeedback(EXPLOSION_SOUND, true)
    @test combat_feedback(submarine) == CombatFeedback(EXPLOSION_SOUND, false)
end
