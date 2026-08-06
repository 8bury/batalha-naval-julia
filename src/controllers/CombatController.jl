export CombatController,
       CombatCellState,
       CombatState,
       combat_state,
       computer_step!,
       player_attack!,
       buy_weapon!,
       missile_preview,
       player_missile!,
       CombatUpdate,
       MissileUpdate,
       air_strike_preview,
       player_air_strike!,
       AirStrikeUpdate

struct CombatController{R<:AbstractRNG}
    match::CombatMatch
    rng::R
end

function CombatController(
    player::PositioningBoard,
    computer::PositioningBoard;
    rng=Random.default_rng(),
)
    return CombatController(create_combat_match(player, computer), rng)
end

combat_state(controller::CombatController) = combat_state(controller.match)
player_attack!(controller::CombatController, row::Int, column::Int) =
    player_attack!(controller.match, row, column)
computer_step!(controller::CombatController) = computer_step!(controller.match; rng=controller.rng)
buy_weapon!(controller::CombatController, weapon::WeaponType) = buy_weapon!(controller.match, PLAYER, weapon)
player_missile!(controller::CombatController, row::Int, column::Int) =
    player_missile!(controller.match, row, column)
player_air_strike!(controller::CombatController, axis::AirStrikeAxis, index::Int) =
    player_air_strike!(controller.match, axis, index)
