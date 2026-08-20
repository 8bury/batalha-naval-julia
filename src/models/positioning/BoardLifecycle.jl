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
