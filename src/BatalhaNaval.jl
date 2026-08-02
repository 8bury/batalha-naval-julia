module BatalhaNaval

using Random

export FleetComposition,
       LAKE,
       OCEAN,
       PUDDLE,
       MatchConfiguration,
       MapKind,
       MapOption,
       NameValidation,
       AutoPlacementResult,
       Orientation,
       HORIZONTAL,
       VERTICAL,
       ShipKind,
       ShipType,
       PATROL,
       SUBMARINE,
       CRUISER,
       TerrainKind,
       TerrainType,
       REEF,
       SHALLOW_WATER,
       TerrainLimits,
       TerrainLayout,
       PlacementPreview,
       PositioningBoard,
       ShipPlacement,
       all_ships_placed,
       auto_place_ships!,
       available_ships,
       battle_ready,
       clear_board!,
       create_match_boards,
       create_match_configuration,
       create_positioning_board,
       create_positioning_boards,
       create_terrain_layout,
       empty_terrain_layout,
       max_reefs,
       max_shallow_waters,
       map_option,
       map_options,
       place_ship!,
       placement_cells,
       positioned_ships,
       preview_placement,
       remove_ship!,
       remove_ship_at!,
       reef_cells,
       ship_at,
       ship_label,
       ship_length,
       ship_symbol,
       shallow_water_cells,
       terrain_at,
       terrain_cells,
       terrain_label,
       terrain_layout,
       terrain_limits,
       terrain_layout_supports_fleet,
       terrain_symbol,
       terrain_tooltip,
       validate_player_name

@enum MapKind begin
    PUDDLE
    LAKE
    OCEAN
end

@enum Orientation begin
    HORIZONTAL
    VERTICAL
end

@enum ShipType begin
    PATROL
    SUBMARINE
    CRUISER
end

const ShipKind = ShipType

@enum TerrainKind begin
    REEF
    SHALLOW_WATER
end

const TerrainType = TerrainKind

struct FleetComposition
    patrols::Int
    submarines::Int
    cruisers::Int
end

struct TerrainLimits
    max_reefs::Int
    max_shallow_waters::Int
end

struct TerrainLayout
    dimension::Int
    reefs::Set{Tuple{Int, Int}}
    shallow_waters::Set{Tuple{Int, Int}}

    function TerrainLayout(dimension::Int, reefs, shallow_waters)
        dimension > 0 || throw(ArgumentError("A dimensão do terreno deve ser positiva."))
        normalized_reefs = Set{Tuple{Int, Int}}(reefs)
        normalized_shallow_waters = Set{Tuple{Int, Int}}(shallow_waters)
        all_cells = vcat(collect(normalized_reefs), collect(normalized_shallow_waters))
        all(
            cell -> 1 <= cell[1] <= dimension && 1 <= cell[2] <= dimension,
            all_cells,
        ) || throw(ArgumentError("Terrenos especiais devem ficar dentro do mapa."))
        isempty(intersect(normalized_reefs, normalized_shallow_waters)) ||
            throw(ArgumentError("Recifes e águas rasas não podem ocupar a mesma casa."))
        return new(dimension, normalized_reefs, normalized_shallow_waters)
    end
end

function Base.:(==)(left::TerrainLayout, right::TerrainLayout)
    return left.dimension == right.dimension &&
           left.reefs == right.reefs &&
           left.shallow_waters == right.shallow_waters
end

struct MapOption
    kind::MapKind
    name::String
    dimension::Int
    fleet::FleetComposition
end

struct NameValidation
    valid::Bool
    normalized::String
    message::String
end

struct ShipPlacement
    id::Int
    ship_type::ShipType
    start_row::Int
    start_column::Int
    orientation::Orientation
end

struct PlacementPreview
    valid::Bool
    cells::Vector{Tuple{Int, Int}}
    message::String
end

struct AutoPlacementResult
    success::Bool
    message::String
    placed::Vector{ShipPlacement}
end

mutable struct PositioningBoard
    map::MapKind
    dimension::Int
    fleet::FleetComposition
    terrain::TerrainLayout
    placements::Vector{ShipPlacement}
    next_id::Int
end

PositioningBoard(
    map::MapKind,
    dimension::Int,
    fleet::FleetComposition,
    placements::Vector{ShipPlacement},
    next_id::Int,
) = PositioningBoard(
    map,
    dimension,
    fleet,
    empty_terrain_layout(dimension),
    placements,
    next_id,
)

struct MatchConfiguration
    player_name::String
    map::MapKind
    special_terrain::Bool

    function MatchConfiguration(
        raw_name::AbstractString,
        map::MapKind,
        special_terrain::Bool,
    )
        validation = validate_player_name(raw_name)
        validation.valid || throw(ArgumentError(validation.message))
        return new(validation.normalized, map, special_terrain)
    end
end

const MAP_OPTIONS = (
    MapOption(PUDDLE, "Poça", 5, FleetComposition(1, 1, 1)),
    MapOption(LAKE, "Lago", 8, FleetComposition(2, 2, 1)),
    MapOption(OCEAN, "Oceano", 10, FleetComposition(3, 2, 2)),
)

const SHIP_LENGTHS = Dict(
    PATROL => 1,
    SUBMARINE => 2,
    CRUISER => 3,
)

const SHIP_LABELS = Dict(
    PATROL => "Patrulha",
    SUBMARINE => "Submarino",
    CRUISER => "Cruzador",
)

const SHIP_SYMBOLS = Dict(
    PATROL => "P",
    SUBMARINE => "S",
    CRUISER => "C",
)

const TERRAIN_LIMITS = Dict(
    PUDDLE => TerrainLimits(1, 1),
    LAKE => TerrainLimits(3, 3),
    OCEAN => TerrainLimits(5, 5),
)

const TERRAIN_LABELS = Dict(
    REEF => "Recife",
    SHALLOW_WATER => "Águas Rasas",
)

const TERRAIN_SYMBOLS = Dict(
    REEF => "◆",
    SHALLOW_WATER => "≈",
)

const TERRAIN_TOOLTIPS = Dict(
    REEF => "Recife — nenhuma embarcação pode ocupar esta casa.",
    SHALLOW_WATER => "Águas Rasas — somente Patrulhas podem ocupar esta casa.",
)

"""Retorna os mapas disponíveis na ordem exibida pelo aplicativo."""
map_options() = collect(MAP_OPTIONS)

"""Retorna o comprimento fixo de uma embarcação clássica."""
ship_length(ship_type::ShipType) = SHIP_LENGTHS[ship_type]

"""Retorna o nome da embarcação para a interface em português."""
ship_label(ship_type::ShipType) = SHIP_LABELS[ship_type]
ship_symbol(ship_type::ShipType) = SHIP_SYMBOLS[ship_type]

max_reefs(map::MapKind) = TERRAIN_LIMITS[map].max_reefs
max_shallow_waters(map::MapKind) = TERRAIN_LIMITS[map].max_shallow_waters
terrain_limits(map::MapKind) = TERRAIN_LIMITS[map]
terrain_limits(option::MapOption) = terrain_limits(option.kind)
max_reefs(option::MapOption) = max_reefs(option.kind)
max_shallow_waters(option::MapOption) = max_shallow_waters(option.kind)
terrain_label(kind::TerrainKind) = TERRAIN_LABELS[kind]
terrain_symbol(kind::TerrainKind) = TERRAIN_SYMBOLS[kind]
terrain_tooltip(kind::TerrainKind) = TERRAIN_TOOLTIPS[kind]

function fleet_count(fleet::FleetComposition, ship_type::ShipType)
    ship_type == PATROL && return fleet.patrols
    ship_type == SUBMARINE && return fleet.submarines
    return fleet.cruisers
end

function map_option(map::MapKind)
    return only(filter(option -> option.kind == map, MAP_OPTIONS))
end

empty_terrain_layout(map::MapKind) = TerrainLayout(map_option(map).dimension, Set{Tuple{Int, Int}}(), Set{Tuple{Int, Int}}())
empty_terrain_layout(dimension::Int) = TerrainLayout(dimension, Set{Tuple{Int, Int}}(), Set{Tuple{Int, Int}}())

reef_cells(layout::TerrainLayout) = copy(layout.reefs)
shallow_water_cells(layout::TerrainLayout) = copy(layout.shallow_waters)
terrain_cells(layout::TerrainLayout) = union(layout.reefs, layout.shallow_waters)
terrain_cells(layout::TerrainLayout, kind::TerrainKind) = kind == REEF ? reef_cells(layout) : shallow_water_cells(layout)
terrain_at(layout::TerrainLayout, row::Int, column::Int) =
    (row, column) in layout.reefs ? REEF :
    (row, column) in layout.shallow_waters ? SHALLOW_WATER : nothing

function sample_cells(rng, dimension::Int, amount::Int, excluded::Set{Tuple{Int, Int}})
    candidates = [
        (row, column) for row in 1:dimension for column in 1:dimension
        if !((row, column) in excluded)
    ]
    amount <= length(candidates) || throw(ArgumentError("Não há casas suficientes para sortear o terreno."))
    return Set(shuffle(rng, candidates)[1:amount])
end

function terrain_placement_allowed(
    layout::TerrainLayout,
    ship_type::ShipType,
    cells::Vector{Tuple{Int, Int}},
    occupied::Set{Tuple{Int, Int}}=Set{Tuple{Int, Int}}(),
)
    all(
        cell -> 1 <= cell[1] <= layout.dimension && 1 <= cell[2] <= layout.dimension,
        cells,
    ) || return false
    all(cell -> !(cell in layout.reefs), cells) || return false
    ship_type != PATROL && any(cell -> cell in layout.shallow_waters, cells) && return false
    return all(cell -> !(cell in occupied), cells)
end

function fleet_ship_types(fleet::FleetComposition)
    return vcat(
        fill(CRUISER, fleet.cruisers),
        fill(SUBMARINE, fleet.submarines),
        fill(PATROL, fleet.patrols),
    )
end

function terrain_layout_supports_fleet(layout::TerrainLayout, fleet::FleetComposition)
    ship_types = fleet_ship_types(fleet)
    failed_states = Set{Tuple{Int, Tuple{Vararg{Tuple{Int, Int}}}}}()

    function search(index::Int, occupied::Set{Tuple{Int, Int}})
        index > length(ship_types) && return true
        failed_state_key = (index, Tuple(sort(collect(occupied))))
        failed_state_key in failed_states && return false
        ship_type = ship_types[index]
        for row in 1:layout.dimension
            for column in 1:layout.dimension
                for orientation in (HORIZONTAL, VERTICAL)
                    cells = placement_cells(ship_type, row, column, orientation)
                    if terrain_placement_allowed(layout, ship_type, cells, occupied)
                        union!(occupied, cells)
                        search(index + 1, occupied) && return true
                        setdiff!(occupied, cells)
                    end
                end
            end
        end
        push!(failed_states, failed_state_key)
        return false
    end

    return search(1, Set{Tuple{Int, Int}}())
end

function create_terrain_layout(
    map::MapKind;
    rng=Random.default_rng(),
    max_attempts::Int=10_000,
)
    option = map_option(map)
    for _ in 1:max_attempts
        reefs = sample_cells(rng, option.dimension, rand(rng, 0:max_reefs(map)), Set{Tuple{Int, Int}}())
        shallow_waters = sample_cells(rng, option.dimension, rand(rng, 0:max_shallow_waters(map)), reefs)
        layout = TerrainLayout(option.dimension, reefs, shallow_waters)
        terrain_layout_supports_fleet(layout, option.fleet) && return layout
    end
    throw(ArgumentError("Não foi possível sortear um desenho de terrenos que comporte a frota."))
end

create_terrain_layout(option::MapOption; kwargs...) =
    create_terrain_layout(option.kind; kwargs...)

function resolve_terrain_layout(
    map::MapKind,
    fleet::FleetComposition;
    special_terrain::Bool=false,
    terrain_layout=nothing,
    rng=Random.default_rng(),
)
    layout = if !isnothing(terrain_layout)
        terrain_layout isa TerrainLayout || throw(ArgumentError("O desenho de terreno é inválido."))
        terrain_layout
    elseif special_terrain
        create_terrain_layout(map; rng)
    else
        empty_terrain_layout(map)
    end
    layout.dimension == map_option(map).dimension ||
        throw(ArgumentError("O desenho de terreno não corresponde ao tamanho do mapa."))
    length(layout.reefs) <= max_reefs(map) ||
        throw(ArgumentError("O desenho excede o máximo de recifes deste mapa."))
    length(layout.shallow_waters) <= max_shallow_waters(map) ||
        throw(ArgumentError("O desenho excede o máximo de águas rasas deste mapa."))
    terrain_layout_supports_fleet(layout, fleet) ||
        throw(ArgumentError("O desenho de terreno não comporta toda a frota."))
    return layout
end

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

create_positioning_boards(configuration::MatchConfiguration; kwargs...) =
    create_match_boards(configuration; kwargs...)

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

"""Expande uma posição inicial e uma orientação em células 1-indexadas."""
function placement_cells(
    ship_type::ShipType,
    start_row::Int,
    start_column::Int,
    orientation::Orientation,
)
    row_step, column_step = orientation == HORIZONTAL ? (0, 1) : (1, 0)
    return [
        (
            start_row + (index - 1) * row_step,
            start_column + (index - 1) * column_step,
        ) for index in 1:ship_length(ship_type)
    ]
end

placement_cells(placement::ShipPlacement) = placement_cells(
    placement.ship_type,
    placement.start_row,
    placement.start_column,
    placement.orientation,
)

"""Retorna as células ocupadas por uma embarcação posicionada."""
placement_cells(board::PositioningBoard) = reduce(
    vcat,
    (placement_cells(placement) for placement in board.placements),
    init=Tuple{Int, Int}[],
)

function invalid_preview(cells, message)
    return PlacementPreview(false, cells, message)
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

    if !all(
        cell -> 1 <= cell[1] <= board.dimension && 1 <= cell[2] <= board.dimension,
        cells,
    )
        return invalid_preview(cells, "A posição sai dos limites do tabuleiro.")
    end

    if any(cell -> cell in board.terrain.reefs, cells)
        return invalid_preview(cells, "A posição passa por um recife e não pode receber embarcações.")
    end

    if ship_type != PATROL && any(cell -> cell in board.terrain.shallow_waters, cells)
        return invalid_preview(cells, "Apenas Patrulhas podem ocupar casas de águas rasas.")
    end

    occupied = Set(placement_cells(board))
    if any(cell -> cell in occupied, cells)
        return invalid_preview(cells, "A posição sobrepõe uma embarcação existente.")
    end

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

function auto_placement_candidates(
    board::PositioningBoard,
    ship_type::ShipType,
    occupied::Set{Tuple{Int, Int}},
    rng,
)
    candidates = ShipPlacement[]
    for row in 1:board.dimension
        for column in 1:board.dimension
            for orientation in (HORIZONTAL, VERTICAL)
                cells = placement_cells(ship_type, row, column, orientation)
                if terrain_placement_allowed(board.terrain, ship_type, cells, occupied)
                    push!(
                        candidates,
                        ShipPlacement(0, ship_type, row, column, orientation),
                    )
                end
            end
        end
    end
    return shuffle(rng, candidates)
end

function find_auto_placements(
    board::PositioningBoard,
    ship_types::Vector{ShipType},
    rng,
)
    occupied = Set(placement_cells(board))
    planned = ShipPlacement[]

    function search(index::Int)
        index > length(ship_types) && return true
        ship_type = ship_types[index]
        for candidate in auto_placement_candidates(board, ship_type, occupied, rng)
            cells = placement_cells(candidate)
            union!(occupied, cells)
            push!(planned, candidate)
            if search(index + 1)
                return true
            end
            pop!(planned)
            setdiff!(occupied, cells)
        end
        return false
    end

    return search(1) ? copy(planned) : nothing
end

"""Completa uma frota sem substituir nenhuma embarcação já posicionada."""
function auto_place_ships!(board::PositioningBoard; rng=Random.default_rng())
    ship_types = sort(available_ships(board); by=ship_length, rev=true)
    planned = find_auto_placements(board, ship_types, rng)
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

"""Normaliza e valida o nome do jogador sem depender da interface gráfica."""
function validate_player_name(raw_name::AbstractString)
    normalized = strip(raw_name)
    character_count = length(normalized)

    if !(2 <= character_count <= 20)
        return NameValidation(
            false,
            normalized,
            "O nome deve ter entre 2 e 20 caracteres.",
        )
    end

    if !occursin(r"^[\p{L}\p{N} _-]+$", normalized)
        return NameValidation(
            false,
            normalized,
            "Use apenas letras, números, espaços, hífen e sublinhado.",
        )
    end

    return NameValidation(true, normalized, "")
end

"""Cria a configuração de domínio consumida pela próxima etapa da partida."""
function create_match_configuration(
    raw_name::AbstractString,
    map::MapKind;
    special_terrain::Bool=true,
)
    return MatchConfiguration(raw_name, map, special_terrain)
end

end
