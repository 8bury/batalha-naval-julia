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

@enum TerrainKind begin
    REEF
    SHALLOW_WATER
end

@enum Participant begin
    PLAYER
    COMPUTER
end

@enum WeaponType begin
    MISSILE
    AIR_STRIKE
end

@enum AirStrikeAxis begin
    STRIKE_ROW
    STRIKE_COLUMN
end

@enum PurchaseRejection begin
    SHOP_CLOSED
    INSUFFICIENT_FUNDS
    QUOTA_EXHAUSTED
end

@enum AttackOutcome begin
    ATTACK_INVALID
    ATTACK_MISS
    ATTACK_HIT
    ATTACK_SUNK
end

@enum AttackRejection begin
    MATCH_FINISHED
    WRONG_TURN
    OUT_OF_BOUNDS
    REEF_TARGET
    ALREADY_ATTACKED
    WEAPON_UNAVAILABLE
    NO_ATTACKABLE_CELLS
end

@enum CombatDirective begin
    AWAIT_PLAYER
    CONTINUE_COMPUTER_TURN
    END_COMBAT
end

@enum PublicCellState begin
    UNKNOWN
    WATER
    DAMAGED
    SUNK
    PUBLIC_REEF
end

@enum FleetShipState begin
    FLEET_HIDDEN
    FLEET_INTACT
    FLEET_DAMAGED
    FLEET_SUNK
end

struct FleetShipStatus
    ship_type::ShipType
    state::FleetShipState
    cells::Vector{Tuple{Int, Int}}
end

struct CombatEvent
    actor::Participant
    weapon::Union{Nothing, WeaponType}
    target::String
    outcome::AttackOutcome
    hits::Int
    sunk_ships::Vector{ShipType}
    message::String
end

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

struct AttackResult
    valid::Bool
    outcome::AttackOutcome
    row::Int
    column::Int
    rejection::Union{Nothing, AttackRejection}
end

mutable struct ComputerStrategy
    pending_hits::Set{Tuple{Int, Int}}
end

ComputerStrategy() = ComputerStrategy(Set{Tuple{Int, Int}}())

mutable struct CombatMatch
    player_board::PositioningBoard
    computer_board::PositioningBoard
    player_attacks::Set{Tuple{Int, Int}}
    computer_attacks::Set{Tuple{Int, Int}}
    turn::Participant
    winner::Union{Nothing, Participant}
    computer_strategy::ComputerStrategy
    coins::Dict{Participant, Int}
    inventories::Dict{Participant, Dict{WeaponType, Int}}
    purchased::Dict{Participant, Dict{WeaponType, Int}}
    shop_available::Dict{Participant, Bool}
    history::Vector{CombatEvent}
end

struct ShopItemState
    weapon::WeaponType
    price::Int
    remaining_quota::Int
    inventory_count::Int
end

struct PurchaseResult
    valid::Bool
    weapon::WeaponType
    rejection::Union{Nothing, PurchaseRejection}
end

struct CombatCellState
    public_state::PublicCellState
    terrain::Union{Nothing, TerrainKind}
    own_ship_type::Union{Nothing, ShipType}
    revealed_ship_type::Union{Nothing, ShipType}
end

struct CombatState
    dimension::Int
    player_cells::Matrix{CombatCellState}
    computer_cells::Matrix{CombatCellState}
    turn::Participant
    winner::Union{Nothing, Participant}
    player_coins::Int
    computer_coins::Int
    player_inventory::Dict{WeaponType, Int}
    computer_inventory::Dict{WeaponType, Int}
    shop_available::Bool
    shop_items::Vector{ShopItemState}
    player_fleet::Vector{FleetShipStatus}
    computer_fleet::Vector{FleetShipStatus}
    recent_events::Vector{CombatEvent}
    history::Vector{CombatEvent}
end

struct CombatUpdate
    result::AttackResult
    state::CombatState
    directive::CombatDirective
end

struct MissilePreview
    valid::Bool
    cells::Vector{Tuple{Int, Int}}
end

struct MissileResult
    valid::Bool
    row::Int
    column::Int
    cells::Vector{Tuple{Int, Int}}
    hits::Int
    sunk::Int
    rejection::Union{Nothing, AttackRejection}
end

struct MissileUpdate
    result::MissileResult
    state::CombatState
    directive::CombatDirective
end

struct AirStrikeResult
    valid::Bool
    axis::AirStrikeAxis
    index::Int
    cells::Vector{Tuple{Int, Int}}
    hits::Int
    sunk::Int
    rejection::Union{Nothing, AttackRejection}
end

struct AirStrikeUpdate
    result::AirStrikeResult
    state::CombatState
    directive::CombatDirective
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
