@enum MapKind begin
    PUDDLE
    LAKE
    OCEAN
end

@enum Orientation begin
    HORIZONTAL
    VERTICAL
end

@enum ShipType begin
    PATROL
    SUBMARINE
    CRUISER
end

@enum TerrainKind begin
    REEF
    SHALLOW_WATER
end

struct FleetComposition
    patrols::Int
    submarines::Int
    cruisers::Int
end

struct TerrainLimits
    max_reefs::Int
    max_shallow_waters::Int
end

struct TerrainLayout
    dimension::Int
    reefs::Set{Tuple{Int, Int}}
    shallow_waters::Set{Tuple{Int, Int}}

    function TerrainLayout(dimension::Int, reefs, shallow_waters)
        dimension > 0 || throw(ArgumentError("A dimensão do terreno deve ser positiva."))
        normalized_reefs = Set{Tuple{Int, Int}}(reefs)
        normalized_shallow_waters = Set{Tuple{Int, Int}}(shallow_waters)
        all_cells = vcat(collect(normalized_reefs), collect(normalized_shallow_waters))
        all(
            cell -> 1 <= cell[1] <= dimension && 1 <= cell[2] <= dimension,
            all_cells,
        ) || throw(ArgumentError("Terrenos especiais devem ficar dentro do mapa."))
        isempty(intersect(normalized_reefs, normalized_shallow_waters)) ||
            throw(ArgumentError("Recifes e águas rasas não podem ocupar a mesma casa."))
        return new(dimension, normalized_reefs, normalized_shallow_waters)
    end
end

function Base.:(==)(left::TerrainLayout, right::TerrainLayout)
    return left.dimension == right.dimension &&
           left.reefs == right.reefs &&
           left.shallow_waters == right.shallow_waters
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

    function MatchConfiguration(
        raw_name::AbstractString,
        map::MapKind,
        special_terrain::Bool,
    )
        validation = validate_player_name(raw_name)
        validation.valid || throw(ArgumentError(validation.message))
        return new(validation.normalized, map, special_terrain)
    end
end
