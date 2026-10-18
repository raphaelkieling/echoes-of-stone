-- Set `file` to an audio path to replace a generated sound with an asset.
return {
    move = {
        file = nil,
        volume = 0.38,
        synthesis = {
            duration = 0.095,
            startFrequency = 205,
            endFrequency = 118,
            decay = 23,
            harmonic = 0.28,
            noise = 0.06,
        },
    },
    invalidMovement = {
        file = nil,
        volume = 0.42,
        synthesis = {
            duration = 0.16,
            startFrequency = 112,
            endFrequency = 68,
            decay = 15,
            harmonic = 0.42,
            noise = 0.11,
        },
    },
    undo = {
        file = nil,
        volume = 0.3,
        synthesis = {
            style = "rewind",
            duration = 0.18,
            startFrequency = 920,
            endFrequency = 340,
            decay = 17,
            harmonic = 0.16,
            noise = 0.36,
            flutter = 34,
        },
    },
    target = {
        file = nil,
        volume = 0.32,
        synthesis = {
            style = "plateClick",
            duration = 0.11,
            startFrequency = 1480,
            endFrequency = 830,
            decay = 34,
            harmonic = 0.24,
            noise = 0.16,
            clickDecay = 210,
        },
    },
    uiClick = {
        file = nil,
        volume = 0.28,
        synthesis = {
            duration = 0.045,
            startFrequency = 980,
            endFrequency = 690,
            decay = 65,
            harmonic = 0.12,
            noise = 0.015,
        },
    },
}
