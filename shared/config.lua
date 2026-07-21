Config = {}

Config.Debug = true

Config.StartKey = 0x80F28E95 -- L

Config.EmotesEvent = "rsg-animations:server:Open" -- If blank Emote Button is hidden.
Config.EmotesButton = "RSG-Anim"

Config.MenuScale = {
    Default = 1.0,
    Min = 0.5,
    Max = 2,
    Step = 0.05,
}

-- The L-key utility menu is intentionally separate from object poses.
Config.MainMenuButtons = {
    {
        label = "Gun Twirl",
        description = "Open the gun twirl controls.",
        action = "guntwirl",
    },
    {
        label = Config.EmotesButton,
        description = "Open the configured animation menu.",
        action = "event_anim",
    },
}
