ENV["PANGOCAIRO_BACKEND"] = "fc"
if Sys.islinux()
    config_home = get(ENV, "XDG_CONFIG_HOME", joinpath(homedir(), ".config"))
    user_gtk_css = joinpath(config_home, "gtk-4.0", "gtk.css")
    if isfile(user_gtk_css) && occursin("libadwaita", read(user_gtk_css, String))
        isolated_config_home = mktempdir(prefix="batalha-naval-gtk-")
        ENV["XDG_CONFIG_HOME"] = isolated_config_home
        atexit(() -> rm(isolated_config_home; recursive=true, force=true))
    end
    ENV["GTK_THEME"] = "Adwaita"
end

using BatalhaNaval

include(joinpath(@__DIR__, "..", "src", "views", "GtkApplication.jl"))

GtkApplication.run_application()
