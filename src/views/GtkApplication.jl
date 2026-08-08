module GtkApplication

using Gtk4
using BatalhaNaval
using BatalhaNaval.Application

export run_application

const RESULTS_REPOSITORY = Ref{Union{Nothing, SQLiteResultRepository}}(nothing)
results_repository() = isnothing(RESULTS_REPOSITORY[]) ?
    (RESULTS_REPOSITORY[] = SQLiteResultRepository()) : RESULTS_REPOSITORY[]


# Composition root da View Gtk. Os arquivos compartilham este módulo e
# permanecem internos; a interface externa continua sendo run_application.
include("widgets/CommonWidgets.jl")
include("widgets/BoardGrid.jl")
include("pages/InformationPage.jl")
include("pages/RankingPage.jl")
include("pages/BattlePage.jl")
include("pages/PositioningPage.jl")
include("pages/SetupPages.jl")
include("pages/MainMenuPage.jl")
include("ApplicationWindow.jl")

end
