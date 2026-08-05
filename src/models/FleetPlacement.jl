"""Expande uma posição inicial e uma orientação em células 1-indexadas."""
function placement_cells(
    ship_type::ShipType,
    start_row::Int,
    start_column::Int,
    orientation::Orientation,
)
    row_step, column_step = orientation == HORIZONTAL ? (0, 1) : (1, 0)
    return [
        (
            start_row + (index - 1) * row_step,
            start_column + (index - 1) * column_step,
        ) for index in 1:ship_length(ship_type)
    ]
end

placement_cells(placement::ShipPlacement) = placement_cells(
    placement.ship_type,
    placement.start_row,
    placement.start_column,
    placement.orientation,
)

@enum PlacementIssue begin
    PLACEMENT_OUT_OF_BOUNDS
    PLACEMENT_ON_REEF
    SHIP_NOT_ALLOWED_IN_SHALLOW_WATER
    PLACEMENT_OVERLAP
end

function placement_issue(
    layout::TerrainLayout,
    ship_type::ShipType,
    cells::Vector{Tuple{Int, Int}},
    occupied::Set{Tuple{Int, Int}},
)
    all(
        cell -> 1 <= cell[1] <= layout.dimension && 1 <= cell[2] <= layout.dimension,
        cells,
    ) || return PLACEMENT_OUT_OF_BOUNDS
    any(cell -> cell in layout.reefs, cells) && return PLACEMENT_ON_REEF
    ship_type != PATROL &&
        any(cell -> cell in layout.shallow_waters, cells) &&
        return SHIP_NOT_ALLOWED_IN_SHALLOW_WATER
    any(cell -> cell in occupied, cells) && return PLACEMENT_OVERLAP
    return nothing
end

function placement_candidates(
    layout::TerrainLayout,
    ship_type::ShipType,
    occupied::Set{Tuple{Int, Int}},
)
    candidates = ShipPlacement[]
    for row in 1:layout.dimension
        for column in 1:layout.dimension
            for orientation in (HORIZONTAL, VERTICAL)
                candidate = ShipPlacement(0, ship_type, row, column, orientation)
                isnothing(
                    placement_issue(
                        layout,
                        ship_type,
                        placement_cells(candidate),
                        occupied,
                    ),
                ) && push!(candidates, candidate)
            end
        end
    end
    return candidates
end

"""Encontra uma frota válida usando a mesma regra do posicionamento manual."""
function find_fleet_placements(
    layout::TerrainLayout,
    ship_types::Vector{ShipType};
    occupied=Set{Tuple{Int, Int}}(),
    rng=nothing,
)
    occupied_cells = Set{Tuple{Int, Int}}(occupied)
    planned = ShipPlacement[]
    failed_states = Set{Tuple{Int, Tuple{Vararg{Tuple{Int, Int}}}}}()

    function search(index::Int)
        index > length(ship_types) && return true
        failed_state_key = (index, Tuple(sort(collect(occupied_cells))))
        failed_state_key in failed_states && return false

        candidates = placement_candidates(layout, ship_types[index], occupied_cells)
        !isnothing(rng) && shuffle!(rng, candidates)
        for candidate in candidates
            cells = placement_cells(candidate)
            union!(occupied_cells, cells)
            push!(planned, candidate)
            search(index + 1) && return true
            pop!(planned)
            setdiff!(occupied_cells, cells)
        end

        push!(failed_states, failed_state_key)
        return false
    end

    return search(1) ? copy(planned) : nothing
end

function fleet_ship_types(fleet::FleetComposition)
    return vcat(
        fill(CRUISER, fleet.cruisers),
        fill(SUBMARINE, fleet.submarines),
        fill(PATROL, fleet.patrols),
    )
end

terrain_layout_supports_fleet(layout::TerrainLayout, fleet::FleetComposition) =
    !isnothing(find_fleet_placements(layout, fleet_ship_types(fleet)))
