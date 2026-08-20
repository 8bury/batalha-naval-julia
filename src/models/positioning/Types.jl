struct ShipPlacement
    id::Int
    ship_type::ShipType
    start_row::Int
    start_column::Int
    orientation::Orientation
end

struct PlacementPreview
    valid::Bool
    cells::Vector{Tuple{Int, Int}}
    message::String
end

struct AutoPlacementResult
    success::Bool
    message::String
    placed::Vector{ShipPlacement}
end

mutable struct PositioningBoard
    map::MapKind
    dimension::Int
    fleet::FleetComposition
    terrain::TerrainLayout
    placements::Vector{ShipPlacement}
    next_id::Int
end

PositioningBoard(
    map::MapKind,
    dimension::Int,
    fleet::FleetComposition,
    placements::Vector{ShipPlacement},
    next_id::Int,
) = PositioningBoard(
    map,
    dimension,
    fleet,
    empty_terrain_layout(dimension),
    placements,
    next_id,
)
