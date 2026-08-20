include(joinpath(@__DIR__, "..", "src", "views", "CombatAudio.jl"))

@testset "áudio de combate em memória" begin
    @test WATER_WAV[1:4] == collect(codeunits("RIFF"))
    @test EXPLOSION_WAV[1:4] == collect(codeunits("RIFF"))
    @test WATER_WAV != EXPLOSION_WAV
    fake_which(name) = name == "pw-play" ? "/usr/bin/pw-play" : nothing
    @test linux_audio_command(; which=fake_which) == `pw-play -`
    @test isnothing(linux_audio_command(; which=name -> nothing))

    audio = CombatAudio()
    set_muted!(audio, true)
    @test !play_audio!(audio, WATER_SOUND)
    @test !play_audio!(audio, EXPLOSION_SOUND)
    @test isnothing(audio.active_buffer)
    set_muted!(audio, false)
    @test !audio.muted
    @test isnothing(audio.active_playback)
end
