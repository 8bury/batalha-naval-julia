struct ScoreBreakdown
    hit_points::Int
    survivor_points::Int
    integrity_points::Int
    time_points::Int
    victory_points::Int
    total::Int
end

struct MatchSummary
    won::Bool
    duration_seconds::Int
    hits::Int
    surviving_ships::Int
    intact_cells::Int
    remaining_coins::Int
    score::ScoreBreakdown
end

abstract type AbstractResultRepository end

struct MatchResult
    id::Int
    player_name::String
    map::MapKind
    score::Int
    duration_seconds::Int
    won::Bool
    completed_at::String
    special_terrain::Bool
    hits::Int
    surviving_ships::Int
    intact_cells::Int
end
