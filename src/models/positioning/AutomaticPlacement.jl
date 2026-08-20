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
