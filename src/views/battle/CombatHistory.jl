function show_combat_history(window, events)
    dialog = GtkWindow(; modal=true, title="Histórico completo")
    Gtk4.transient_for(dialog, window)
    content = configure_container!(GtkBox(:v); spacing=10)
    content.width_request = 520
    content.height_request = 480
    push!(content, title_label("Histórico completo"))
    list = GtkBox(:v)
    list.spacing = 6
    for event in reverse(events)
        push!(list, GtkLabel(event.message; wrap=true, xalign=0))
    end
    isempty(events) && push!(list, GtkLabel("Nenhum ataque registrado."; xalign=0))
    scroll = GtkScrolledWindow()
    scroll[] = list
    scroll.vexpand = true
    push!(content, scroll)
    close_button = styled!(GtkButton("Fechar"), "secondary-action")
    signal_connect(close_button, "clicked") do _
        close_dialog(dialog)
    end
    push!(content, close_button)
    dialog[] = content
    show(dialog)
    return dialog
end
