"""Cria o estado de posicionamento, com terrenos opcionais e validáveis."""
function create_positioning_board(
    map::MapKind;
    special_terrain::Bool=false,
    terrain_layout=nothing,
    rng=Random.default_rng(),
)
    option = map_option(map)
    layout = resolve_terrain_layout(
        map,
        option.fleet;
        special_terrain,
        terrain_layout,
        rng,
    )
    PositioningBoard(map, option.dimension, option.fleet, layout, ShipPlacement[], 1)
end

create_positioning_board(option::MapOption; kwargs...) = create_positioning_board(option.kind; kwargs...)
create_positioning_board(configuration::MatchConfiguration; rng=Random.default_rng()) =
    create_positioning_board(configuration.map; special_terrain=configuration.special_terrain, rng)

function create_positioning_board(
    configuration::MatchConfiguration,
    layout::TerrainLayout;
    rng=Random.default_rng(),
)
    return create_positioning_board(
        configuration.map;
        special_terrain=configuration.special_terrain,
        terrain_layout=layout,
        rng,
    )
end

function create_match_boards(
    configuration::MatchConfiguration;
    rng=Random.default_rng(),
    terrain_layout=nothing,
)
    layout = !isnothing(terrain_layout) ? terrain_layout :
        configuration.special_terrain ?
        create_terrain_layout(configuration.map; rng) :
        empty_terrain_layout(configuration.map)
    player_board = create_positioning_board(configuration, layout; rng)
    computer_board = create_positioning_board(configuration, layout; rng)
    result = auto_place_ships!(computer_board; rng)
    result.success || throw(ArgumentError(result.message))
    return (player_board, computer_board)
end

terrain_layout(board::PositioningBoard) = board.terrain
reef_cells(board::PositioningBoard) = reef_cells(board.terrain)
shallow_water_cells(board::PositioningBoard) = shallow_water_cells(board.terrain)
terrain_cells(board::PositioningBoard) = terrain_cells(board.terrain)
terrain_cells(board::PositioningBoard, kind::TerrainKind) = terrain_cells(board.terrain, kind)
terrain_at(board::PositioningBoard, row::Int, column::Int) = terrain_at(board.terrain, row, column)
