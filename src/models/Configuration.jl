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
    PUDDLE => TerrainLimits(2, 2),
    LAKE => TerrainLimits(4, 4),
    OCEAN => TerrainLimits(6, 6),
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
    REEF => "Recife - nenhuma embarcação pode ocupar esta casa.",
    SHALLOW_WATER => "Águas Rasas - somente Patrulhas podem ocupar esta casa.",
)

const WEAPON_PRICES = Dict(MISSILE => 30, AIR_STRIKE => 50)
const WEAPON_QUOTAS = Dict(
    PUDDLE => Dict(MISSILE => 1, AIR_STRIKE => 1),
    LAKE => Dict(MISSILE => 2, AIR_STRIKE => 1),
    OCEAN => Dict(MISSILE => 3, AIR_STRIKE => 2),
)
const WEAPON_LABELS = Dict(MISSILE => "Míssil", AIR_STRIKE => "Ataque Aéreo")

weapons() = (MISSILE, AIR_STRIKE)
weapon_price(weapon::WeaponType) = WEAPON_PRICES[weapon]
weapon_quota(map::MapKind, weapon::WeaponType) = WEAPON_QUOTAS[map][weapon]
weapon_label(weapon::WeaponType) = WEAPON_LABELS[weapon]

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
