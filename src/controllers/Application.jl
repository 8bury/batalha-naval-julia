module Application

using ..BatalhaNaval
using Random
using UUIDs
using Dates
import ..BatalhaNaval: CombatMatch,
                        PlacementPreview,
                        PositioningBoard,
                        auto_place_ships!,
                        available_ships,
                        battle_ready,
                        buy_weapon!,
                        missile_preview,
                        player_missile!,
                        clear_board!,
                        combat_state,
                        computer_step!,
                        create_combat_match,
                        create_match_boards,
                        place_ship!,
                        placement_cells,
                        player_attack!,
                        preview_placement,
                        remove_ship_at!,
                        ship_at,
                        ship_sunk,
                        save_result!,
                        top_results,
                        terrain_at

struct NullResultRepository <: AbstractResultRepository end
save_result!(::NullResultRepository, args...; kwargs...) = nothing
top_results(::NullResultRepository, ::MapKind; limit=10) = MatchResult[]

include("PositioningController.jl")
include("SetupController.jl")
include("CombatController.jl")

end
