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

"""Retorna as embarcações ainda não posicionadas, repetindo tipos conforme a frota."""
function available_ships(board::PositioningBoard)
    available = ShipType[]
    for ship_type in (PATROL, SUBMARINE, CRUISER)
        remaining = fleet_count(board.fleet, ship_type) - count(
            placement -> placement.ship_type == ship_type,
            board.placements,
        )
        append!(available, fill(ship_type, remaining))
    end
    return available
end

"""Retorna as células ocupadas por uma embarcação posicionada."""
placement_cells(board::PositioningBoard) = reduce(
    vcat,
    (placement_cells(placement) for placement in board.placements),
    init=Tuple{Int, Int}[],
)

function invalid_preview(cells, message)
    return PlacementPreview(false, cells, message)
end

function placement_issue_message(issue::PlacementIssue)
    issue == PLACEMENT_OUT_OF_BOUNDS && return "A posição sai dos limites do tabuleiro."
    issue == PLACEMENT_ON_REEF &&
        return "A posição passa por um recife e não pode receber embarcações."
    issue == SHIP_NOT_ALLOWED_IN_SHALLOW_WATER &&
        return "Apenas Patrulhas podem ocupar casas de águas rasas."
    issue == PLACEMENT_OVERLAP &&
        return "A posição sobrepõe uma embarcação existente."
    throw(ArgumentError("Restrição de posicionamento sem mensagem: $issue"))
end

"""Valida uma posição sem alterar o tabuleiro."""
function preview_placement(
    board::PositioningBoard,
    ship_type::ShipType,
    start_row::Int,
    start_column::Int,
    orientation::Orientation,
)
    cells = placement_cells(ship_type, start_row, start_column, orientation)
    if !(ship_type in available_ships(board))
        return invalid_preview(cells, "Todas as embarcações deste tipo já foram posicionadas.")
    end

    occupied = Set(placement_cells(board))
    issue = placement_issue(board.terrain, ship_type, cells, occupied)
    !isnothing(issue) && return invalid_preview(cells, placement_issue_message(issue))

    return PlacementPreview(true, cells, "Posição válida.")
end

function preview_placement(
    board::PositioningBoard,
    ship_type::ShipType,
    start_row::Int,
    start_column::Int;
    orientation::Orientation=HORIZONTAL,
)
    return preview_placement(board, ship_type, start_row, start_column, orientation)
end

"""Adiciona uma embarcação quando o preview é válido."""
function place_ship!(
    board::PositioningBoard,
    ship_type::ShipType,
    start_row::Int,
    start_column::Int,
    orientation::Orientation,
)
    preview = preview_placement(board, ship_type, start_row, start_column, orientation)
    preview.valid || return false

    push!(
        board.placements,
        ShipPlacement(
            board.next_id,
            ship_type,
            start_row,
            start_column,
            orientation,
        ),
    )
    board.next_id += 1
    return true
end

function place_ship!(
    board::PositioningBoard,
    ship_type::ShipType,
    start_row::Int,
    start_column::Int;
    orientation::Orientation=HORIZONTAL,
)
    return place_ship!(board, ship_type, start_row, start_column, orientation)
end

"""Retorna a embarcação que ocupa uma célula ou `nothing`."""
function ship_at(board::PositioningBoard, row::Int, column::Int)
    for placement in board.placements
        (row, column) in placement_cells(placement) && return placement
    end
    return nothing
end

"""Retorna uma cópia das posições atuais para consumidores da interface."""
positioned_ships(board::PositioningBoard) = copy(board.placements)

"""Indica se toda a frota prevista para o mapa já foi posicionada."""
all_ships_placed(board::PositioningBoard) = isempty(available_ships(board))

"""Completa uma frota sem substituir nenhuma embarcação já posicionada."""
function auto_place_ships!(board::PositioningBoard; rng=Random.default_rng())
    ship_types = sort(available_ships(board); by=ship_length, rev=true)
    planned = find_fleet_placements(
        board.terrain,
        ship_types;
        occupied=Set(placement_cells(board)),
        rng,
    )
    if isnothing(planned)
        return AutoPlacementResult(
            false,
            "Não foi possível completar a frota preservando as posições manuais. " *
            "Corrija a configuração e tente novamente.",
            ShipPlacement[],
        )
    end

    placed = ShipPlacement[]
    for candidate in planned
        placement = ShipPlacement(
            board.next_id,
            candidate.ship_type,
            candidate.start_row,
            candidate.start_column,
            candidate.orientation,
        )
        push!(board.placements, placement)
        push!(placed, placement)
        board.next_id += 1
    end
    return AutoPlacementResult(true, "Frota completada automaticamente.", placed)
end

"""Indica se jogador e computador já podem iniciar a batalha."""
battle_ready(player_board::PositioningBoard, computer_board::PositioningBoard) =
    all_ships_placed(player_board) && all_ships_placed(computer_board)

"""Remove uma embarcação pelo identificador público da posição."""
function remove_ship!(board::PositioningBoard, id::Int)
    index = findfirst(placement -> placement.id == id, board.placements)
    isnothing(index) && return false
    deleteat!(board.placements, index)
    return true
end

"""Remove a embarcação clicada em uma célula do tabuleiro."""
function remove_ship_at!(board::PositioningBoard, row::Int, column::Int)
    placement = ship_at(board, row, column)
    isnothing(placement) && return false
    return remove_ship!(board, placement.id)
end

"""Remove todas as embarcações sem reconstruir a dimensão ou a frota."""
function clear_board!(board::PositioningBoard)
    empty!(board.placements)
    board.next_id = 1
    return board
end
