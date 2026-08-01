module BatalhaNaval

export FleetComposition,
       LAKE,
       OCEAN,
       PUDDLE,
       MatchConfiguration,
       MapKind,
       MapOption,
       NameValidation,
       create_match_configuration,
       map_options,
       validate_player_name

@enum MapKind begin
    PUDDLE
    LAKE
    OCEAN
end

struct FleetComposition
    patrols::Int
    submarines::Int
    cruisers::Int
end

struct MapOption
    kind::MapKind
    name::String
    dimension::Int
    fleet::FleetComposition
end

struct NameValidation
    valid::Bool
    normalized::String
    message::String
end

struct MatchConfiguration
    player_name::String
    map::MapKind
    special_terrain::Bool
end

const MAP_OPTIONS = (
    MapOption(PUDDLE, "Poça", 5, FleetComposition(1, 1, 1)),
    MapOption(LAKE, "Lago", 8, FleetComposition(2, 2, 1)),
    MapOption(OCEAN, "Oceano", 10, FleetComposition(3, 2, 2)),
)

"""Return the supported maps in the order shown by the application."""
map_options() = collect(MAP_OPTIONS)

"""Normalize and validate a player name without depending on the UI toolkit."""
function validate_player_name(raw_name::AbstractString)
    normalized = strip(raw_name)
    character_count = length(normalized)

    if !(2 <= character_count <= 20)
        return NameValidation(
            false,
            normalized,
            "O nome deve ter entre 2 e 20 caracteres.",
        )
    end

    if !occursin(r"^[\p{L}\p{N} _-]+$", normalized)
        return NameValidation(
            false,
            normalized,
            "Use apenas letras, números, espaços, hífen e sublinhado.",
        )
    end

    return NameValidation(true, normalized, "")
end

"""Build the domain value consumed by the next stage of a new match."""
function create_match_configuration(
    raw_name::AbstractString,
    map::MapKind;
    special_terrain::Bool=true,
)
    validation = validate_player_name(raw_name)
    validation.valid || throw(ArgumentError(validation.message))
    return MatchConfiguration(validation.normalized, map, special_terrain)
end

end
