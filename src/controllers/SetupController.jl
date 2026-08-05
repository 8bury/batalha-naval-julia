export SetupController,
       SetupState,
       setup_state,
       start_positioning!,
       submit_player_name!

struct SetupState
    player_name::String
end

mutable struct SetupController
    player_name::String
end

SetupController(; initial_name::AbstractString="") = SetupController(String(initial_name))
setup_state(controller::SetupController) = SetupState(controller.player_name)

function submit_player_name!(controller::SetupController, raw_name::AbstractString)
    validation = validate_player_name(raw_name)
    validation.valid && (controller.player_name = validation.normalized)
    return validation
end

function start_positioning!(
    controller::SetupController,
    map::MapKind;
    special_terrain::Bool=true,
    rng=Random.default_rng(),
)
    configuration = create_match_configuration(
        controller.player_name,
        map;
        special_terrain,
    )
    return PositioningController(configuration; rng)
end
