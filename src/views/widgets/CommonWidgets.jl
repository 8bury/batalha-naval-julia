const MAPS = map_options()
const THEME_CSS = read(joinpath(@__DIR__, "..", "theme.css"), String)

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

function navigation_button(window, label, destination; style="secondary-action", expand=true)
    button = menu_button(label; style)
    button.hexpand = expand
    if !expand
        button.halign = Gtk4.Align_START
    end
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
    return "$(fleet.patrols) $patrol, $(fleet.submarines) $submarine, $(fleet.cruisers) $cruiser"
end

function reset_board_cell_style!(button)
    foreach(
        css_class -> remove_css_class(button, css_class),
        (
            "cell-empty",
            "cell-occupied",
            "cell-preview-valid",
            "cell-preview-invalid",
            "cell-reef",
            "cell-shallow-water",
            "combat-water",
            "combat-damaged",
            "combat-sunk",
        ),
    )
    return button
end
