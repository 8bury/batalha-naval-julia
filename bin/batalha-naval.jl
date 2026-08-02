ENV["PANGOCAIRO_BACKEND"] = "fc"

using BatalhaNaval

include(joinpath(@__DIR__, "..", "src", "ui", "GtkApplication.jl"))

GtkApplication.run_application()
