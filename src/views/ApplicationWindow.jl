const ACTIVE_MATCH_WINDOWS = WeakKeyDict{Any, Bool}()

function set_match_in_progress!(window, active::Bool)
    ACTIVE_MATCH_WINDOWS[window] = active
    return active
end

match_in_progress(window) = get(ACTIVE_MATCH_WINDOWS, window, false)

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

        confirm_exit(window; match_in_progress=match_in_progress(window)) do
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
