export PositioningController,
       PositioningState,
       PositioningUpdate,
       auto_position!,
       clear_positioning!,
       confirm_position!,
       handle_positioning_cell!,
       positioning_state,
       select_ship!,
       start_combat,
       toggle_orientation!

struct PositioningCellState
    ship_type::Union{Nothing, ShipType}
    terrain::Union{Nothing, TerrainKind}
    previewed::Bool
    preview_valid::Union{Nothing, Bool}
    preview_message::String
end

struct PositioningState
    player_name::String
    dimension::Int
    cells::Matrix{PositioningCellState}
    available_ships::Vector{ShipType}
    selected_ship::Union{Nothing, ShipType}
    orientation::Orientation
    can_confirm::Bool
    can_start_combat::Bool
end

struct PositioningUpdate
    message::String
    valid::Union{Nothing, Bool}
    state::PositioningState
end

mutable struct PositioningController
    configuration::MatchConfiguration
    player_board::PositioningBoard
    computer_board::PositioningBoard
    selected_ship::Union{Nothing, ShipType}
    orientation::Orientation
    preview::Union{Nothing, PlacementPreview}
    preview_start::Union{Nothing, Tuple{Int, Int}}
end

function PositioningController(configuration::MatchConfiguration; rng=Random.default_rng())
    player, computer = create_match_boards(configuration; rng)
    return PositioningController(
        configuration,
        player,
        computer,
        nothing,
        HORIZONTAL,
        nothing,
        nothing,
    )
end

can_start_combat(controller::PositioningController) =
    battle_ready(controller.player_board, controller.computer_board)

function positioning_state(controller::PositioningController)
    board = controller.player_board
    preview = controller.preview
    preview_cells = isnothing(preview) ? Set{Tuple{Int, Int}}() : Set(preview.cells)
    cells = Matrix{PositioningCellState}(undef, board.dimension, board.dimension)
    for row in 1:board.dimension, column in 1:board.dimension
        placement = ship_at(board, row, column)
        is_previewed = (row, column) in preview_cells
        cells[row, column] = PositioningCellState(
            isnothing(placement) ? nothing : placement.ship_type,
            terrain_at(board, row, column),
            is_previewed,
            is_previewed ? preview.valid : nothing,
            is_previewed ? preview.message : "",
        )
    end
    return PositioningState(
        controller.configuration.player_name,
        board.dimension,
        cells,
        available_ships(board),
        controller.selected_ship,
        controller.orientation,
        !isnothing(preview) && preview.valid,
        can_start_combat(controller),
    )
end

positioning_update(
    controller::PositioningController,
    message::AbstractString,
    valid::Union{Nothing, Bool},
) = PositioningUpdate(String(message), valid, positioning_state(controller))

function start_combat(controller::PositioningController)
    can_start_combat(controller) || throw(ArgumentError("As frotas ainda não estão prontas."))
    return CombatController(controller.player_board, controller.computer_board)
end

function reset_selection!(controller::PositioningController)
    controller.selected_ship = nothing
    controller.preview = nothing
    controller.preview_start = nothing
    return controller
end

function select_ship!(controller::PositioningController, ship_type::ShipType)
    controller.selected_ship = ship_type
    controller.preview = nothing
    controller.preview_start = nothing
    return positioning_update(
        controller,
        "$(ship_label(ship_type)) selecionado. Clique na casa inicial.",
        nothing,
    )
end

function preview_position!(controller::PositioningController, row::Int, column::Int)
    if isnothing(controller.selected_ship)
        return positioning_update(
            controller,
            "Escolha uma embarcação antes de selecionar a casa inicial.",
            nothing,
        )
    end

    controller.preview_start = (row, column)
    controller.preview = preview_placement(
        controller.player_board,
        controller.selected_ship,
        row,
        column,
        controller.orientation,
    )
    return positioning_update(controller, controller.preview.message, controller.preview.valid)
end

function handle_positioning_cell!(controller::PositioningController, row::Int, column::Int)
    if !isnothing(ship_at(controller.player_board, row, column))
        remove_ship_at!(controller.player_board, row, column)
        reset_selection!(controller)
        return positioning_update(
            controller,
            "Embarcação removida e devolvida à lista.",
            nothing,
        )
    end
    return preview_position!(controller, row, column)
end

function toggle_orientation!(controller::PositioningController)
    controller.orientation = controller.orientation == HORIZONTAL ? VERTICAL : HORIZONTAL
    if !isnothing(controller.preview_start)
        row, column = controller.preview_start
        return preview_position!(controller, row, column)
    end
    return positioning_update(controller, "", nothing)
end

function confirm_position!(controller::PositioningController)
    ship_type = controller.selected_ship
    start = controller.preview_start
    preview = controller.preview
    if isnothing(ship_type) || isnothing(start) || isnothing(preview) || !preview.valid
        return positioning_update(
            controller,
            "Selecione uma posição válida antes de confirmar.",
            false,
        )
    end

    row, column = start
    place_ship!(controller.player_board, ship_type, row, column, controller.orientation)
    controller.selected_ship = ship_type in available_ships(controller.player_board) ? ship_type : nothing
    controller.preview = nothing
    controller.preview_start = nothing
    return positioning_update(
        controller,
        "$(ship_label(ship_type)) posicionado. Escolha a próxima embarcação.",
        true,
    )
end

function auto_position!(controller::PositioningController; rng=Random.default_rng())
    result = auto_place_ships!(controller.player_board; rng)
    reset_selection!(controller)
    return positioning_update(controller, result.message, result.success)
end

function clear_positioning!(controller::PositioningController)
    clear_board!(controller.player_board)
    reset_selection!(controller)
    return positioning_update(
        controller,
        "Tabuleiro limpo. A configuração do mapa foi preservada.",
        nothing,
    )
end
