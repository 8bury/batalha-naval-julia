module Application

using ..BatalhaNaval
using Random
import ..BatalhaNaval: CombatMatch,
                        PlacementPreview,
                        PositioningBoard,
                        auto_place_ships!,
                        available_ships,
                        battle_ready,
                        clear_board!,
                        combat_state,
                        computer_step!,
                        create_combat_match,
                        create_match_boards,
                        place_ship!,
                        player_attack!,
                        preview_placement,
                        remove_ship_at!,
                        ship_at,
                        terrain_at

include("PositioningController.jl")
include("SetupController.jl")
include("CombatController.jl")

end
