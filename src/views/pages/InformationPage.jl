function information_page(window, title, body)
    page = configure_container!(GtkBox(:v))
    push!(page, title_label(title))
    push!(page, subtitle_label(body))
    push!(
        page,
        navigation_button(
            window,
            "Voltar ao Menu",
            () -> main_menu(window);
            style="quiet-action",
            expand=false,
        ),
    )
    return page
end

