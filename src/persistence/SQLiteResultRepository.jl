using DBInterface
using SQLite
using Dates

export SQLiteResultRepository, default_results_path, save_result!, top_results

struct SQLiteResultRepository <: AbstractResultRepository
    db::SQLite.DB
end

Base.close(repository::SQLiteResultRepository) = SQLite.close(repository.db)

function default_results_path()
    base = get(ENV, "BATALHA_NAVAL_DATA_DIR", joinpath(homedir(), ".batalha-naval"))
    return joinpath(base, "ranking.sqlite3")
end

function SQLiteResultRepository(path::AbstractString=default_results_path())
    mkpath(dirname(abspath(path)))
    repository = SQLiteResultRepository(SQLite.DB(path))
    DBInterface.execute(repository.db, """
        CREATE TABLE IF NOT EXISTS match_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            completion_key TEXT NOT NULL UNIQUE,
            player_name TEXT NOT NULL,
            map TEXT NOT NULL,
            score INTEGER NOT NULL,
            duration_seconds INTEGER NOT NULL,
            won INTEGER NOT NULL,
            completed_at TEXT NOT NULL,
            special_terrain INTEGER NOT NULL,
            hits INTEGER NOT NULL,
            surviving_ships INTEGER NOT NULL,
            intact_cells INTEGER NOT NULL
        )
    """)
    return repository
end

function save_result!(repository::SQLiteResultRepository, completion_key::AbstractString,
                      configuration::MatchConfiguration, summary::MatchSummary;
                      completed_at=Dates.now())
    stamp = Dates.format(completed_at, dateformat"yyyy-mm-ddTHH:MM:SS.sss")
    DBInterface.execute(repository.db, """
        INSERT OR IGNORE INTO match_results
        (completion_key, player_name, map, score, duration_seconds, won, completed_at,
         special_terrain, hits, surviving_ships, intact_cells)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (String(completion_key), configuration.player_name, string(configuration.map),
          summary.score.total, summary.duration_seconds, summary.won ? 1 : 0, stamp,
          configuration.special_terrain ? 1 : 0, summary.hits,
          summary.surviving_ships, summary.intact_cells))
    return nothing
end

function top_results(repository::SQLiteResultRepository, map::MapKind; limit::Int=10)
    limit >= 0 || throw(ArgumentError("O limite nao pode ser negativo."))
    rows = DBInterface.execute(repository.db, """
        SELECT id, player_name, map, score, duration_seconds, won, completed_at,
               special_terrain, hits, surviving_ships, intact_cells
        FROM match_results WHERE map = ?
        ORDER BY score DESC, duration_seconds ASC, completed_at ASC, id ASC LIMIT ?
    """, (string(map), limit))
    return [MatchResult(Int(row.id), String(row.player_name), map, Int(row.score),
             Int(row.duration_seconds), Bool(row.won), String(row.completed_at),
             Bool(row.special_terrain), Int(row.hits), Int(row.surviving_ships),
             Int(row.intact_cells)) for row in rows]
end
