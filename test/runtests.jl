using Test
using BatalhaNaval
import BatalhaNaval: FleetComposition,
                       PositioningBoard,
                       ShipPlacement,
                       TerrainLayout,
                       all_ships_placed,
                       auto_place_ships!,
                       available_ships,
                       battle_ready,
                       buy_weapon!,
                       clear_board!,
                       combat_state,
                       computer_step!,
                       create_combat_match,
                       create_match_boards,
                       create_positioning_board,
                       create_terrain_layout,
                       map_option,
                       max_reefs,
                       max_shallow_waters,
                       place_ship!,
                       placement_cells,
                       player_attack!,
                       player_air_strike!,
                       STRIKE_ROW,
                       STRIKE_COLUMN,
                       missile_preview,
                       player_missile!,
                       positioned_ships,
                       preview_placement,
                       reef_cells,
                       remove_ship_at!,
                       shallow_water_cells,
                       ship_at,
                       terrain_at,
                       terrain_cells,
                       terrain_label,
                       terrain_layout_supports_fleet,
                       terrain_limits

@testset "domínio independente da interface" begin
    loaded_package_names = (package.name for package in keys(Base.loaded_modules))
    @test "Gtk4" ∉ loaded_package_names
end

include("configuration_test.jl")
include("positioning_test.jl")
include("automatic_positioning_test.jl")
include("special_terrain_test.jl")
include("combat_test.jl")
include("combat_information_test.jl")
include("combat_feedback_test.jl")
include("combat_audio_test.jl")
include("economy_test.jl")
include("missile_test.jl")
include("air_strike_test.jl")
include("computer_strategy_test.jl")
include("computer_weapons_test.jl")
include("controller_test.jl")
include("computer_turn_step_test.jl")
include("match_completion_test.jl")
include("sqlite_ranking_test.jl")
include("theme_css_test.jl")
include("font_rendering_test.jl")
