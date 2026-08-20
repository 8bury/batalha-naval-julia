mutable struct CombatAudio
    muted::Bool
    active_buffer::Union{Nothing, Vector{UInt8}}
    active_playback::Any
end

CombatAudio() = CombatAudio(false, nothing, nothing)

function wav_tone(frequency::Float64, duration_ms::Int; noisy=false)
    sample_rate = 16_000
    count = round(Int, sample_rate * duration_ms / 1_000)
    samples = Vector{Int16}(undef, count)
    seed = UInt32(0x6d2b79f5)
    for index in eachindex(samples)
        time = (index - 1) / sample_rate
        envelope = noisy ? exp(-12time) : min(1.0, index / 120) * exp(-5time)
        if noisy
            seed = seed ⊻ (seed << 13); seed = seed ⊻ (seed >> 17); seed = seed ⊻ (seed << 5)
            wave = (Float64(seed % UInt32(2001)) - 1000) / 1000
        else
            wave = sin(2pi * frequency * time) + 0.35sin(2pi * frequency * 0.5 * time)
        end
        samples[index] = round(Int16, clamp(wave * envelope * 13_000, -32_767, 32_767))
    end
    data_size = 2length(samples)
    io = IOBuffer()
    write(io, codeunits("RIFF"), UInt32(36 + data_size), codeunits("WAVEfmt "), UInt32(16),
          UInt16(1), UInt16(1), UInt32(sample_rate), UInt32(sample_rate * 2), UInt16(2), UInt16(16),
          codeunits("data"), UInt32(data_size), samples)
    return take!(io)
end

const WATER_WAV = wav_tone(520.0, 180)
const EXPLOSION_WAV = wav_tone(90.0, 240; noisy=true)

function linux_audio_command(; which=Sys.which)
    !isnothing(which("pw-play")) && return `pw-play -`
    !isnothing(which("aplay")) && return `aplay -q`
    !isnothing(which("ffplay")) && return `ffplay -nodisp -autoexit -loglevel quiet -i -`
    return nothing
end

function stop_audio!(audio::CombatAudio)
    if Sys.iswindows()
        ccall((:PlaySoundW, "winmm"), stdcall, Cint,
              (Ptr{Cvoid}, Ptr{Cvoid}, UInt32), C_NULL, C_NULL, 0)
    elseif !isnothing(audio.active_playback)
        try
            kill(audio.active_playback)
        catch
            # O processo pode ter encerrado naturalmente antes do próximo som.
        end
    end
    audio.active_buffer = nothing
    audio.active_playback = nothing
    return audio
end

function play_audio!(audio::CombatAudio, cue::SoundCue)
    (audio.muted || cue == NO_SOUND) && return false
    stop_audio!(audio)
    audio.active_buffer = cue == WATER_SOUND ? WATER_WAV : EXPLOSION_WAV
    buffer = audio.active_buffer
    if Sys.iswindows()
        flags = UInt32(0x0001 | 0x0002 | 0x0004) # async, no-default, memory
        GC.@preserve buffer begin
            ccall((:PlaySoundW, "winmm"), stdcall, Cint,
                  (Ptr{UInt8}, Ptr{Cvoid}, UInt32), pointer(buffer), C_NULL, flags)
        end
        return true
    end

    command = linux_audio_command()
    isnothing(command) && (audio.active_buffer = nothing; return false)
    audio.active_playback = run(pipeline(command; stdin=IOBuffer(buffer)); wait=false)
    return true
end

function set_muted!(audio::CombatAudio, muted::Bool)
    audio.muted = muted
    muted && stop_audio!(audio)
    return audio
end
