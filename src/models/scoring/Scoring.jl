"""Calcula os componentes auditaveis da pontuacao final."""
function calculate_score(hits::Int, surviving_ships::Int, intact_cells::Int,
                         duration_seconds::Int, won::Bool)
    all(>=(0), (hits, surviving_ships, intact_cells, duration_seconds)) ||
        throw(ArgumentError("As estatisticas da partida nao podem ser negativas."))
    hit_points = 100 * hits
    survivor_points = 300 * surviving_ships
    integrity_points = 50 * intact_cells
    time_points = max(0, 1000 - duration_seconds)
    victory_points = won ? 500 : 0
    total = hit_points + survivor_points + integrity_points + time_points + victory_points
    return ScoreBreakdown(hit_points, survivor_points, integrity_points,
                          time_points, victory_points, total)
end

function format_duration(seconds::Integer)
    seconds >= 0 || throw(ArgumentError("A duracao nao pode ser negativa."))
    minutes, remainder = divrem(seconds, 60)
    return lpad(minutes, 2, '0') * ":" * lpad(remainder, 2, '0')
end
