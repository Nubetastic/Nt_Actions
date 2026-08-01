ConfigGroups = {}

-- Each pose is { scenario name, unique display name, gender }.
-- Gender may be "male", "female", or "" (compatible with both).
-- Adding a group publishes every compatible pose with one shared object offset.
ConfigGroups.ScenarioOrder = {
    "Ground",
    "Seat Chair",
    "Seat Bench",
    "Sit at Table",
    "Piano",
    "Camp Fire",
    "Sleep Bed Pillow",
    "Lean",
    "Bar",
}

ConfigGroups.Scenario = {
    ["Ground"] = {
        objectOffset = false,
        truncate = { "WORLD_HUMAN_SIT_GROUND_", "WORLD_HUMAN_", "GENERIC_" },
        Poses = {
            {"GENERIC_SIT_GROUND_SCENARIO", "Sit Ground Generic", ""},
            {"WORLD_HUMAN_SIT_GROUND", "Sit Ground", ""},
            {"WORLD_HUMAN_SIT_GROUND_READING", "Sit Ground Reading", ""},
            {"WORLD_HUMAN_SIT_GROUND_SKETCHING", "Sit Ground Sketching", "Female"},
            {"WORLD_HUMAN_SIT_GROUND_WHITTLE", "Sit Ground Whittle", ""},
        },
    },

    ["Seat Chair"] = {
        objectOffset = true,
        truncate = { "PROP_HUMAN_SEAT_CHAIR_", "PROP_HUMAN_SEAT_" },
        Poses = {
            {"PROP_HUMAN_SEAT_CHAIR", "Sit Chair", ""},
            {"PROP_HUMAN_SEAT_CHAIR_BANJO", "Sit Chair Banjo", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_BANJO_DOWNBEAT", "Sit Chair Banjo Downbeat", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_BANJO_UPBEAT", "Sit Chair Banjo Upbeat", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_GUITAR", "Sit Chair Guitar", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_DRINKING_MOONSHINE", "Sit Chair Drinking Moonshine", ""},
            {"PROP_HUMAN_SEAT_CHAIR_CIGAR", "Sit Chair Cigar", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_SMOKING", "Sit Chair Smoking", ""},
            {"PROP_HUMAN_SEAT_CHAIR_SMOKE_ROLL", "Sit Chair Smoke Roll", ""},
            {"PROP_HUMAN_SEAT_CHAIR_FAN", "Sit Chair Fan", "female"},
            {"PROP_HUMAN_SEAT_CHAIR_KNIFE_BADASS", "Sit Chair Knife", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_KNITTING", "Sit Chair Knitting", "female"},
            {"PROP_HUMAN_SEAT_CHAIR_SEWING", "Sit Chair Sewing", "female"},
            {"PROP_HUMAN_SEAT_CHAIR_SKETCHING", "Sit Chair Sketching", ""},
            {"PROP_HUMAN_SEAT_CHAIR_WHITTLE", "Sit Chair Whittle", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_FISHING_ROD", "Sit Chair Fishing Rod", "male"},
            {"SC_PROP_CAMP_DUTCH_SEAT_CHAIR_READING", "Sit Chair Reading", "male"},
        },
    },

    ["Seat Bench"] = {
        objectOffset = true,
        truncate = { "PROP_HUMAN_SEAT_BENCH_", "PROP_HUMAN_SEAT_" },
        Poses = {
            {"PROP_HUMAN_SEAT_BENCH", "Sit Bench", ""},
            {"PROP_HUMAN_SEAT_BENCH_PORCH", "Sit Bench Porch", "male"},
            {"PROP_HUMAN_SEAT_BENCH_TIRED", "Sit Bench Tired", "male"},
            {"PROP_HUMAN_SEAT_BENCH_CONCERTINA", "Sit Bench Concertina", "male"},
            {"PROP_HUMAN_SEAT_BENCH_CONCERTINA_DOWNBEAT", "Sit Bench Concertina Downbeat", "male"},
            {"PROP_HUMAN_SEAT_BENCH_CONCERTINA_UPBEAT", "Sit Bench Concertina Upbeat", "male"},
            {"PROP_HUMAN_SEAT_BENCH_FIDDLE", "Sit Bench Fiddle", "female"},
            {"PROP_HUMAN_SEAT_BENCH_FIDDLE_DOWNBEAT", "Sit Bench Fiddle Downbeat", "female"},
            {"PROP_HUMAN_SEAT_BENCH_FIDDLE_UPBEAT", "Sit Bench Fiddle Upbeat", "female"},
            {"PROP_HUMAN_SEAT_BENCH_HARMONICA", "Sit Bench Harmonica", "male"},
            {"PROP_HUMAN_SEAT_BENCH_HARMONICA_DOWNBEAT", "Sit Bench Harmonica Downbeat", "male"},
            {"PROP_HUMAN_SEAT_BENCH_HARMONICA_UPBEAT", "Sit Bench Harmonica Upbeat", "male"},
            {"PROP_HUMAN_SEAT_BENCH_JAW_HARP", "Sit Bench Jaw Harp", "male"},
            {"PROP_HUMAN_SEAT_BENCH_JAW_HARP_DOWNBEAT", "Sit Bench Jaw Harp Downbeat", "male"},
            {"PROP_HUMAN_SEAT_BENCH_JAW_HARP_UPBEAT", "Sit Bench Jaw Harp Upbeat", "male"},
            {"PROP_HUMAN_SEAT_BENCH_MANDOLIN", "Sit Bench Mandolin", "male"},
            {"PROP_HUMAN_SEAT_BENCH_MANDOLIN_DOWNBEAT", "Sit Bench Mandolin Downbeat", "male"},
            {"PROP_HUMAN_SEAT_BENCH_MANDOLIN_UPBEAT", "Sit Bench Mandolin Upbeat", "male"},
        },
    },

    ["Sit at Table"] = {
        objectOffset = true,
        truncate = { "PROP_HUMAN_SEAT_CHAIR_TABLE_" },
        Poses = {
            {"PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING", "Sit Table Drinking", ""},
            {"PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING_MOONSHINE", "Sit Table Drinking Moonshine", ""},
            {"PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING_WHISKEY_MOONSHINE", "Sit Table Drinking Whiskey", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_TABLE_FAN_WHORE", "Sit Table Fan", "female"},
            {"PROP_HUMAN_PASSED_OUT_TABLE", "Sit Table Passed Out", "male"},
        },
    },

    ["Piano"] = {
        objectOffset = true,
        truncate = { "PROP_HUMAN_PIANO_", "PROP_HUMAN_" },
        Poses = {
            {"PROP_HUMAN_PIANO", "Play Piano", "male"},
            {"PROP_HUMAN_PIANO_RIVERBOAT", "Play Piano Riverboat", "male"},
            {"PROP_HUMAN_PIANO_SKETCHY", "Play Piano Sketchy", "male"},
            {"PROP_HUMAN_PIANO_UPPERCLASS", "Play Piano Upper Class", "male"},
            {"PROP_HUMAN_ABIGAIL_PIANO", "Piano", "female"},
        },
    },

    ["Camp Fire"] = {
        objectOffset = true,
        truncate = { "PROP_CAMP_FIRE_" },
        Poses = {
            {"PROP_CAMP_FIRE_SEATED", "Camp Fire Seated", ""},
            {"PROP_CAMP_FIRE_SEAT_BENCH", "Camp Fire Seat Bench", ""},
            {"PROP_CAMP_FIRE_SEAT_CHAIR", "Camp Fire Seat Chair", ""},
            {"PROP_CAMP_FIRE_SEAT_LOG_LEAN", "Camp Fire Lean on Log", ""},
        },
    },

    ["Sleep Bed Pillow"] = {
        objectOffset = true,
        truncate = { "PROP_HUMAN_SLEEP_BED_PILLOW_", "PROP_HUMAN_SLEEP_" },
        Poses = {
            {"PROP_HUMAN_SLEEP_BED_PILLOW", "Sleep Bed Pillow", ""},
            {"PROP_HUMAN_SLEEP_BED_PILLOW_HIGH", "Sleep Bed Pillow High", "male"},
            {"PROP_HUMAN_SLEEP_BED_PILLOW_LEFT", "Sleep Bed Pillow Left", ""},
            {"PROP_HUMAN_SLEEP_BED_PILLOW_RIGHT", "Sleep Bed Pillow Right", ""},
        },
    },
    ["Lean"] = {
        objectOffset = false,
        truncate = {"WORLD_HUMAN_LEAN" },
        Poses = {
            {"WORLD_HUMAN_LEAN_BACK_WALL", "Lean Wall",""},
            {"WORLD_HUMAN_LEAN_BACK_WALL_SMOKING", "Lean Wall Smoking", ""},
            {"WORLD_HUMAN_LEAN_BACK_WHITTLE", "Lean Back Whittle", ""},
            {"WORLD_HUMAN_LEAN_POST_LEFT", "Lean Post Left", ""},
            {"WORLD_HUMAN_LEAN_POST_RIGHT", "Lean Post Right", ""},
            {"WORLD_HUMAN_LEAN_RAILING_NO_PROPS", "Lean Railing", ""},
            {"WORLD_HUMAN_LEAN_RAILING_DRINKING", "Lean Railing Drinking", "male"},
            {"WORLD_HUMAN_LEAN_RAILING_SMOKING", "Lean Railing Smoking", ""},
            {"WORLD_HUMAN_LEAN_WALL_DRINKING", "Lean Wall Drinking", ""},
            {"WORLD_HUMAN_LEAN_WALL_LEFT", "Lean Wall Left", ""},
            {"WORLD_HUMAN_LEAN_WALL_RIGHT", "Lean Wall Right", ""},
        }
    },
    ["Bar"] = {
        objectOffset = false,
        truncate = {"WORLD_HUMAN_", "SC_WORLD_HUMAN_" },
        Poses = {
            {"WORLD_HUMAN_DRUNK_BAR_SLUMPED", "Bar Slumped","male"},
            {"SC_WORLD_HUMAN_STAND_BAR", "Stand","male"}, -- female hands glitch through bar
            {"WORLD_HUMAN_BARCUSTOMER", "Barcustomer", ""},
            {"WORLD_HUMAN_DRINKING", "Drinking", ""},
            {"WORLD_HUMAN_DRINKING_DRUNK", "Drinking Drunk", "male"},
            {"WORLD_HUMAN_DRINKING_MOONSHINE", "Moonshine", ""},
        }
    },
}
-- Global lookup used to keep every saved preset pose list in this config's order.
-- Pose numbers follow ScenarioOrder, then each group's Poses array from top to bottom.
masterOrder = {}
masterGroupOrder = {}
local nextPoseOrder = 1
for groupIndex, groupName in ipairs(ConfigGroups.ScenarioOrder or {}) do
    masterGroupOrder[groupName] = groupIndex
    local group = ConfigGroups.Scenario[groupName]
    for _, pose in ipairs(group and group.Poses or {}) do
        local scenarioName = pose[1]
        if type(scenarioName) == 'string' and masterOrder[scenarioName] == nil then
            masterOrder[scenarioName] = nextPoseOrder
            nextPoseOrder = nextPoseOrder + 1
        end
    end
end
