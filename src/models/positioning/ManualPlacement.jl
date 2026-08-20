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
