module BatalhaNaval

using Random

# Fachada pública do Model. O domínio permanece independente de Gtk e do
# fluxo de telas, enquanto a interface existente do pacote é preservada.
include("models/GameModel.jl")
include("controllers/Application.jl")

end
