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
