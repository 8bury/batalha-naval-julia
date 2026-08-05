ENV["PANGOCAIRO_BACKEND"] = "fc"

using BatalhaNaval

include(joinpath(@__DIR__, "..", "src", "views", "GtkApplication.jl"))

GtkApplication.run_application()
