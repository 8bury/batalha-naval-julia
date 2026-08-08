include(joinpath(@__DIR__, "..", "src", "views", "CombatAudio.jl"))

@testset "áudio de combate em memória" begin
    @test WATER_WAV[1:4] == collect(codeunits("RIFF"))
    @test EXPLOSION_WAV[1:4] == collect(codeunits("RIFF"))
    @test WATER_WAV != EXPLOSION_WAV

    audio = CombatAudio()
    set_muted!(audio, true)
    @test !play_audio!(audio, WATER_SOUND)
    @test isnothing(audio.active_buffer)
    set_muted!(audio, false)
    @test !audio.muted
end
