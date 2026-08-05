struct BoardGrid
    widget::GtkGrid
    buttons::Matrix{Any}
end

"""Constrói um tabuleiro Gtk completo, com cabeçalhos e botões indexados por linha/coluna."""
function create_board_grid(dimension::Int)
    grid = GtkGrid()
    grid.row_spacing = 3
    grid.column_spacing = 3
    grid.halign = Gtk4.Align_CENTER
    grid.valign = Gtk4.Align_CENTER
    grid[1, 1] = styled!(GtkLabel(""), "board-header")

    for column in 1:dimension
        grid[column + 1, 1] = styled!(
            GtkLabel(string(Char(Int('A') + column - 1))),
            "board-header",
        )
    end

    buttons = Matrix{Any}(undef, dimension, dimension)
    for row in 1:dimension
        grid[1, row + 1] = styled!(GtkLabel(string(row)), "board-header")
        for column in 1:dimension
            button = styled!(GtkButton("·"), "board-cell", "cell-empty")
            button.width_request = 42
            button.height_request = 42
            button.tooltip_text = "$(Char(Int('A') + column - 1))$row"
            buttons[row, column] = button
            grid[column + 1, row + 1] = button
        end
    end
    return BoardGrid(grid, buttons)
end
