module BatalhaNaval

export FleetComposition,
       LAKE,
       OCEAN,
       PUDDLE,
       MatchConfiguration,
       MapKind,
       MapOption,
       NameValidation,
       Orientation,
       HORIZONTAL,
       VERTICAL,
       ShipKind,
       ShipType,
       PATROL,
       SUBMARINE,
       CRUISER,
       PlacementPreview,
       PositioningBoard,
       ShipPlacement,
       all_ships_placed,
       available_ships,
       clear_board!,
       create_match_configuration,
       create_positioning_board,
       map_option,
       map_options,
       place_ship!,
       placement_cells,
       positioned_ships,
       preview_placement,
       remove_ship!,
       remove_ship_at!,
       ship_at,
       ship_label,
       ship_length,
       ship_symbol,
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

struct FleetComposition
    patrols::Int
    submarines::Int
    cruisers::Int
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

mutable struct PositioningBoard
    map::MapKind
    dimension::Int
    fleet::FleetComposition
    placements::Vector{ShipPlacement}
    next_id::Int
end

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

"""Retorna os mapas disponíveis na ordem exibida pelo aplicativo."""
map_options() = collect(MAP_OPTIONS)

"""Retorna o comprimento fixo de uma embarcação clássica."""
ship_length(ship_type::ShipType) = SHIP_LENGTHS[ship_type]

"""Retorna o nome da embarcação para a interface em português."""
ship_label(ship_type::ShipType) = SHIP_LABELS[ship_type]
ship_symbol(ship_type::ShipType) = SHIP_SYMBOLS[ship_type]

function fleet_count(fleet::FleetComposition, ship_type::ShipType)
    ship_type == PATROL && return fleet.patrols
    ship_type == SUBMARINE && return fleet.submarines
    return fleet.cruisers
end

function map_option(map::MapKind)
    return only(filter(option -> option.kind == map, MAP_OPTIONS))
end

"""Cria o estado vazio de posicionamento para um mapa clássico."""
create_positioning_board(map::MapKind) = begin
    option = map_option(map)
    PositioningBoard(map, option.dimension, option.fleet, ShipPlacement[], 1)
end

create_positioning_board(option::MapOption) = create_positioning_board(option.kind)
create_positioning_board(configuration::MatchConfiguration) = create_positioning_board(configuration.map)

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
