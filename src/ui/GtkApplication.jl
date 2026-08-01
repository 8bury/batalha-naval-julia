module GtkApplication

using Gtk4
using BatalhaNaval

export run_application

const MAPS = map_options()

function configure_container!(widget; spacing=16)
    widget.spacing = spacing
    widget.margin_top = 32
    widget.margin_bottom = 32
    widget.margin_start = 48
    widget.margin_end = 48
    return widget
end

function title_label(text)
    return GtkLabel(text; xalign=0)
end

function menu_button(label)
    button = GtkButton(label)
    button.hexpand = true
    return button
end

function fleet_text(option::MapOption)
    fleet = option.fleet
    patrol = fleet.patrols == 1 ? "Patrulha" : "Patrulhas"
    submarine = fleet.submarines == 1 ? "Submarino" : "Submarinos"
    cruiser = fleet.cruisers == 1 ? "Cruzador" : "Cruzadores"
    return "$(fleet.patrols) $patrol  •  $(fleet.submarines) $submarine  •  $(fleet.cruisers) $cruiser"
end

function information_page(window, title, body)
    page = configure_container!(GtkBox(:v))
    push!(page, title_label(title))
    push!(page, GtkLabel(body; wrap=true, xalign=0))

    back_button = menu_button("Voltar ao Menu")
    signal_connect(back_button, "clicked") do _
        window[] = main_menu(window)
    end
    push!(page, back_button)
    return page
end

function ready_page(window, configuration::MatchConfiguration)
    option = only(filter(candidate -> candidate.kind == configuration.map, MAPS))
    terrain = configuration.special_terrain ? "habilitados" : "desabilitados"
    summary = "Jogador: $(configuration.player_name)\n" *
              "Mapa: $(option.name) ($(option.dimension)×$(option.dimension))\n" *
              "Frota: $(fleet_text(option))\n" *
              "Terrenos especiais: $terrain"

    page = configure_container!(GtkBox(:v))
    push!(page, title_label("Configuração pronta"))
    push!(page, GtkLabel(summary; wrap=true, xalign=0))
    push!(page, GtkLabel("O posicionamento da frota será implementado na próxima etapa."; wrap=true, xalign=0))

    change_button = menu_button("Alterar Configuração")
    signal_connect(change_button, "clicked") do _
        window[] = configuration_page(window; initial_name=configuration.player_name)
    end
    push!(page, change_button)

    menu = menu_button("Menu Principal")
    signal_connect(menu, "clicked") do _
        window[] = main_menu(window)
    end
    push!(page, menu)
    return page
end

function configuration_page(window; initial_name="")
    page = configure_container!(GtkBox(:v))
    push!(page, title_label("Nova partida"))

    push!(page, GtkLabel("Nome do jogador (2 a 20 caracteres)"; xalign=0))
    name_entry = GtkEntry()
    name_entry.text = initial_name
    name_entry.placeholder_text = "Digite seu nome"
    push!(page, name_entry)

    push!(page, GtkLabel("Tamanho do mapa"; xalign=0))
    map_selector = GtkDropDown(["$(option.name) — $(option.dimension)×$(option.dimension)" for option in MAPS])
    push!(page, map_selector)

    fleet_label = GtkLabel("Frota: $(fleet_text(MAPS[1]))"; wrap=true, xalign=0)
    push!(page, fleet_label)
    signal_connect(map_selector, "notify::selected") do selector, _...
        selected_map = MAPS[Int(selector.selected) + 1]
        fleet_label.label = "Frota: $(fleet_text(selected_map))"
    end

    terrain_toggle = GtkCheckButton("Habilitar terrenos especiais")
    terrain_toggle.active = true
    push!(page, terrain_toggle)

    error_label = GtkLabel(""; wrap=true, xalign=0)
    push!(page, error_label)

    continue_button = menu_button("Continuar")
    signal_connect(continue_button, "clicked") do _
        validation = validate_player_name(name_entry.text)
        if !validation.valid
            error_label.label = validation.message
            return nothing
        end

        selected_map = MAPS[Int(map_selector.selected) + 1]
        configuration = create_match_configuration(
            validation.normalized,
            selected_map.kind;
            special_terrain=terrain_toggle.active,
        )
        window[] = ready_page(window, configuration)
        return nothing
    end
    push!(page, continue_button)

    back_button = menu_button("Cancelar")
    signal_connect(back_button, "clicked") do _
        window[] = main_menu(window)
    end
    push!(page, back_button)
    return page
end

function main_menu(window)
    page = configure_container!(GtkBox(:v); spacing=18)
    push!(page, title_label("Batalha Naval"))
    push!(page, GtkLabel("Escolha uma opção para continuar."; xalign=0))

    start_button = menu_button("Iniciar Jogo")
    signal_connect(start_button, "clicked") do _
        window[] = configuration_page(window)
    end
    push!(page, start_button)

    ranking_button = menu_button("Ranking")
    signal_connect(ranking_button, "clicked") do _
        window[] = information_page(
            window,
            "Ranking",
            "O ranking será disponibilizado em uma etapa posterior.",
        )
    end
    push!(page, ranking_button)

    instructions_button = menu_button("Instruções")
    signal_connect(instructions_button, "clicked") do _
        window[] = information_page(
            window,
            "Instruções",
            "Configure seu nome, escolha um mapa e decida se a partida terá terrenos especiais.",
        )
    end
    push!(page, instructions_button)

    exit_button = menu_button("Sair")
    signal_connect(exit_button, "clicked") do _
        destroy(window)
    end
    push!(page, exit_button)
    return page
end

function activate(app)
    window = GtkApplicationWindow(app, "Batalha Naval")
    window.default_width = 1280
    window.default_height = 800
    window.resizable = true
    window[] = main_menu(window)
    show(window)
    return nothing
end

function run_application()
    app = Gtk4.GtkApplication("br.edu.batalhanaval.app")
    Gtk4.signal_connect(activate, app, :activate)
    return Gtk4.run(app)
end

end
