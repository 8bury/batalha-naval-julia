module GtkApplication

using Gtk4
using BatalhaNaval

export run_application

const MAPS = map_options()
const THEME_CSS = read(joinpath(@__DIR__, "theme.css"), String)

function styled!(widget, classes...)
    foreach(css_class -> add_css_class(widget, css_class), classes)
    return widget
end

function install_theme!(window)
    provider = GtkCssProvider(THEME_CSS)
    push!(Gtk4.display(window), provider)
    return provider
end

function configure_container!(widget; spacing=16)
    widget.spacing = spacing
    widget.width_request = 660
    widget.halign = Gtk4.Align_CENTER
    widget.valign = Gtk4.Align_CENTER
    widget.vexpand = true
    widget.margin_top = 36
    widget.margin_bottom = 36
    widget.margin_start = 28
    widget.margin_end = 28
    return styled!(widget, "surface")
end

function title_label(text)
    return styled!(GtkLabel(text; xalign=0), "screen-title")
end

function subtitle_label(text)
    return styled!(GtkLabel(text; wrap=true, xalign=0), "subtitle")
end

function field_label(text)
    return styled!(GtkLabel(text; xalign=0), "field-label")
end

function menu_button(label; style="secondary-action")
    button = GtkButton(label)
    button.hexpand = true
    return styled!(button, style)
end

function navigation_button(window, label, destination)
    button = menu_button(label)
    signal_connect(button, "clicked") do _
        window[] = destination()
    end
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
    push!(page, styled!(GtkLabel("CENTRAL DE COMANDO"; xalign=0), "brand-mark"))
    push!(page, title_label(title))
    push!(page, styled!(GtkLabel(body; wrap=true, xalign=0), "info-card"))

    push!(page, navigation_button(window, "Voltar ao Menu", () -> main_menu(window)))
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
    push!(page, styled!(GtkLabel("NOVA MISSÃO"; xalign=0), "brand-mark"))
    push!(page, title_label("Configuração pronta"))
    push!(page, styled!(GtkLabel(summary; wrap=true, xalign=0), "info-card"))
    push!(
        page,
        styled!(
            GtkLabel("O posicionamento da frota será implementado na próxima etapa."; wrap=true, xalign=0),
            "muted-card",
        ),
    )

    push!(
        page,
        navigation_button(
            window,
            "Alterar Configuração",
            () -> configuration_page(window, configuration.player_name),
        ),
    )
    push!(page, navigation_button(window, "Menu Principal", () -> main_menu(window)))
    return page
end

function name_page(window; initial_name="")
    page = configure_container!(GtkBox(:v))
    push!(page, styled!(GtkLabel("IDENTIFICAÇÃO"; xalign=0), "brand-mark"))
    push!(page, title_label("Identificação do jogador"))
    push!(page, subtitle_label("Informe como seu nome aparecerá no ranking da frota."))

    push!(page, field_label("NOME DO JOGADOR  •  2 A 20 CARACTERES"))
    name_entry = GtkEntry()
    name_entry.text = initial_name
    name_entry.placeholder_text = "Digite seu nome"
    push!(page, name_entry)

    error_label = styled!(GtkLabel(""; wrap=true, xalign=0), "error-text")
    push!(page, error_label)

    continue_button = menu_button("Continuar"; style="primary-action")
    signal_connect(continue_button, "clicked") do _
        validation = validate_player_name(name_entry.text)
        if !validation.valid
            error_label.label = validation.message
            return nothing
        end

        window[] = configuration_page(window, validation.normalized)
        return nothing
    end
    push!(page, continue_button)
    push!(page, navigation_button(window, "Cancelar", () -> main_menu(window)))
    return page
end

function configuration_page(window, player_name)
    page = configure_container!(GtkBox(:v))
    push!(page, styled!(GtkLabel("PREPARAÇÃO DA MISSÃO"; xalign=0), "brand-mark"))
    push!(page, title_label("Nova partida"))
    push!(page, styled!(GtkLabel("Comandante  •  $player_name"; xalign=0), "player-badge"))

    push!(page, field_label("TEATRO DE OPERAÇÕES"))
    map_selector = GtkDropDown(["$(option.name) — $(option.dimension)×$(option.dimension)" for option in MAPS])
    push!(page, map_selector)

    fleet_label = styled!(GtkLabel("Frota: $(fleet_text(MAPS[1]))"; wrap=true, xalign=0), "info-card")
    push!(page, fleet_label)
    signal_connect(map_selector, "notify::selected") do selector, _...
        selected_map = MAPS[Int(selector.selected) + 1]
        fleet_label.label = "Frota: $(fleet_text(selected_map))"
    end

    terrain_toggle = GtkCheckButton("Habilitar terrenos especiais")
    terrain_toggle.active = true
    push!(page, terrain_toggle)

    continue_button = menu_button("Confirmar Configuração"; style="primary-action")
    signal_connect(continue_button, "clicked") do _
        selected_map = MAPS[Int(map_selector.selected) + 1]
        configuration = create_match_configuration(
            player_name,
            selected_map.kind;
            special_terrain=terrain_toggle.active,
        )
        window[] = ready_page(window, configuration)
        return nothing
    end
    push!(page, continue_button)
    push!(
        page,
        navigation_button(
            window,
            "Alterar Nome",
            () -> name_page(window; initial_name=player_name),
        ),
    )
    push!(page, navigation_button(window, "Cancelar", () -> main_menu(window)))
    return page
end

function close_dialog(dialog)
    Gtk4.transient_for(dialog, nothing)
    destroy(dialog)
    return nothing
end

function confirm_exit(on_confirm::Function, window)
    dialog = GtkWindow(; modal=true, title="Confirmar saída")
    Gtk4.transient_for(dialog, window)

    content = configure_container!(GtkBox(:v); spacing=12)
    content.width_request = 440
    push!(content, styled!(GtkLabel("ENCERRAR OPERAÇÃO"; xalign=0), "brand-mark"))
    push!(content, title_label("Confirmar saída"))
    push!(content, subtitle_label("Deseja realmente sair do Batalha Naval?"))
    actions = GtkBox(:h)
    actions.spacing = 12
    push!(content, actions)

    cancel_button = GtkButton("Cancelar"; hexpand=true)
    signal_connect(cancel_button, "clicked") do _
        close_dialog(dialog)
    end
    push!(actions, cancel_button)

    exit_button = styled!(GtkButton("Sair"; hexpand=true), "danger-action")
    signal_connect(exit_button, "clicked") do _
        close_dialog(dialog)
        on_confirm()
    end
    push!(actions, exit_button)

    dialog[] = content
    show(dialog)
    return dialog
end

function main_menu(window)
    page = configure_container!(GtkBox(:v); spacing=16)
    push!(page, styled!(GtkLabel("COMANDO NAVAL"; xalign=0), "brand-mark"))
    push!(page, title_label("Batalha Naval"))
    push!(page, subtitle_label("Estratégia, precisão e domínio dos mares."))

    start_button = menu_button("Iniciar Nova Batalha"; style="primary-action")
    signal_connect(start_button, "clicked") do _
        window[] = name_page(window)
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

    exit_button = menu_button("Sair"; style="danger-action")
    signal_connect(exit_button, "clicked") do _
        close(window)
    end
    push!(page, exit_button)
    return page
end

function create_window(on_closed::Function=() -> nothing)
    window = GtkWindow("Batalha Naval", 1280, 800)
    window.resizable = true
    window.width_request = 1000
    window.height_request = 650
    install_theme!(window)
    window[] = main_menu(window)

    close_confirmed = Ref(false)
    signal_connect(window, :close_request) do _
        if close_confirmed[]
            on_closed()
            return false
        end

        confirm_exit(window) do
            close_confirmed[] = true
            close(window)
        end
        return true
    end

    show(window)
    return window
end

function run_application()
    if isinteractive()
        return create_window()
    end

    closed = Condition()
    window = create_window(() -> notify(closed))
    Gtk4.GLib.start_main_loop(true)
    try
        wait(closed)
    finally
        Gtk4.GLib.stop_main_loop(true)
    end
    return window
end

end
