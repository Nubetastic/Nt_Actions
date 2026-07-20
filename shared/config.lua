Config = {}

Config.StartKey = 0x80F28E95 -- L

Config.EmotesEvent = "rsg-animations:server:Open" -- If blank Emote Button is hidden.
Config.EmotesButton = "RSG-Anim"

Config.MenuScale = {
    Default = 1.0,
    Min = 0.5,
    Max = 2,
    Step = 0.05,
}

-- Main menu buttons are displayed in this order.
Config.MainMenuButtons = {
    {
        label = "Nearest Task",
        description = "Player does the closest available task that exists in the world.",
        action = "nearest",
    },
    {
        label = "On Point",
        description = "Choose a nearby world scenario and use its existing scenario point.",
        action = "on_point",
    },
    {
        label = "Do Action",
        description = "Choose a nearby world scenario and perform it at the scenario point position.",
        action = "do_action",
    },
    {
        label = "Object Target",
        description = "Target an object, choose a scenario, and fine tune the position.",
        action = "object_target",
    },
    {
        label = "GunTwirl",
        description = "Open the gun twirl controls.",
        action = "guntwirl",
    },
    {
        label = Config.EmotesButton,
        description = "Open the configured animation menu.",
        action = "event_anim",
    },
}
