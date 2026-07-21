ConfigGroups = {}

-- Each group is a flat list of poses. Adding one group to an object publishes
-- every compatible pose in that group and gives them one shared object offset.
ConfigGroups.ScenarioOrder = {
    "Ground",
    "Seat Chair",
    "Seat Bench",
    "Sit at Table",
    "Piano",
    "Camp Fire",
    "Sleep Bed Pillow",
}

ConfigGroups.Scenario = {
    ["Ground"] = {
        truncate = { "WORLD_HUMAN_SIT_GROUND_", "WORLD_HUMAN_", "GENERIC_" },
        Poses = {
            {"GENERIC_SIT_GROUND_SCENARIO", "Sit Ground"},
            {"WORLD_HUMAN_SIT_GROUND", "Sit Ground"},
            {"WORLD_HUMAN_SIT_GROUND_READING", "Reading"},
            {"WORLD_HUMAN_SIT_GROUND_SKETCHING", "Sketching"},
            {"WORLD_HUMAN_SIT_GROUND_SLEEPING_MALE_A", "male"},
            {"WORLD_HUMAN_SIT_GROUND_TIRED_MALE_A", "male"},
            {"WORLD_HUMAN_SIT_GROUND_WHITTLE", "Whittle"},
        },
    },

    ["Seat Chair"] = {
        truncate = { "PROP_HUMAN_SEAT_CHAIR_", "PROP_HUMAN_SEAT_" },
        Poses = {
            {"PROP_HUMAN_SEAT_CHAIR", "Sit"},
            {"PROP_HUMAN_SEAT_CHAIR_BANJO", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_BANJO_DOWNBEAT", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_BANJO_UPBEAT", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_GUITAR", "male"},
            {"PROP_HUMAN_SEAT_CHAIR_DRINKING_MOONSHINE", "Drinking Moonshine"},
            {"PROP_HUMAN_SEAT_CHAIR_CIGAR", "Cigar"},
            {"PROP_HUMAN_SEAT_CHAIR_SMOKING", "Smoking"},
            {"PROP_HUMAN_SEAT_CHAIR_SMOKE_ROLL", "Smoke Roll"},
            {"PROP_HUMAN_SEAT_CHAIR_FAN", "female"},
            {"PROP_HUMAN_SEAT_CHAIR_KNIFE_BADASS", "Knife"},
            {"PROP_HUMAN_SEAT_CHAIR_KNITTING", "female"},
            {"PROP_HUMAN_SEAT_CHAIR_READING", "Reading"},
            {"PROP_HUMAN_SEAT_CHAIR_READ_NEWSPAPER", "Read Newspaper"},
            {"PROP_HUMAN_SEAT_CHAIR_SEWING", "female"},
            {"PROP_HUMAN_SEAT_CHAIR_SHARPEN_AXE", "Sharpen Axe"},
            {"PROP_HUMAN_SEAT_CHAIR_SKETCHING", "Sketching"},
            {"PROP_HUMAN_SEAT_CHAIR_WHITTLE", "Whittle"},
            {"PROP_HUMAN_SEAT_CHAIR_FISHING_ROD", "Fishing Rod"},
        },
    },

    ["Seat Bench"] = {
        truncate = { "PROP_HUMAN_SEAT_BENCH_", "PROP_HUMAN_SEAT_" },
        Poses = {
            {"PROP_HUMAN_SEAT_BENCH", "Sit"},
            {"PROP_HUMAN_SEAT_BENCH_PORCH", "Porch"},
            {"PROP_HUMAN_SEAT_BENCH_TIRED", "Tired"},
            {"PROP_HUMAN_SEAT_BENCH_CONCERTINA", "male"},
            {"PROP_HUMAN_SEAT_BENCH_CONCERTINA_DOWNBEAT", "male"},
            {"PROP_HUMAN_SEAT_BENCH_CONCERTINA_UPBEAT", "male"},
            {"PROP_HUMAN_SEAT_BENCH_FIDDLE", "female"},
            {"PROP_HUMAN_SEAT_BENCH_FIDDLE_DOWNBEAT", "female"},
            {"PROP_HUMAN_SEAT_BENCH_FIDDLE_UPBEAT", "female"},
            {"PROP_HUMAN_SEAT_BENCH_HARMONICA", "male"},
            {"PROP_HUMAN_SEAT_BENCH_HARMONICA_DOWNBEAT", "male"},
            {"PROP_HUMAN_SEAT_BENCH_HARMONICA_UPBEAT", "male"},
            {"PROP_HUMAN_SEAT_BENCH_JAW_HARP", "male"},
            {"PROP_HUMAN_SEAT_BENCH_JAW_HARP_DOWNBEAT", "male"},
            {"PROP_HUMAN_SEAT_BENCH_JAW_HARP_UPBEAT", "male"},
            {"PROP_HUMAN_SEAT_BENCH_MANDOLIN", "female"},
            {"PROP_HUMAN_SEAT_BENCH_MANDOLIN_DOWNBEAT", "female"},
            {"PROP_HUMAN_SEAT_BENCH_MANDOLIN_UPBEAT", "female"},
            {"PROP_HUMAN_SEAT_BENCH_PORCH_DRINKING_MOONSHINE", "Drinking Moonshine"},
        },
    },

    ["Sit at Table"] = {
        truncate = { "PROP_HUMAN_SEAT_CHAIR_TABLE_" },
        Poses = {
            {"PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING", "Drinking"},
            {"PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING_MOONSHINE", "Drinking Moonshine"},
            {"PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING_WHISKEY_MOONSHINE", "Drinking Whiskey"},
            {"PROP_HUMAN_SEAT_CHAIR_TABLE_FAN_WHORE", "female"},
            {"PROP_HUMAN_PASSED_OUT_TABLE", ""},
        },
    },

    ["Piano"] = {
        truncate = { "PROP_HUMAN_PIANO_", "PROP_HUMAN_" },
        Poses = {
            {"PROP_HUMAN_PIANO", "Play Piano"},
            {"PROP_HUMAN_PIANO_RIVERBOAT", "Riverboat"},
            {"PROP_HUMAN_PIANO_SKETCHY", "Sketchy"},
            {"PROP_HUMAN_PIANO_UPPERCLASS", "Upper Class"},
        },
    },

    ["Camp Fire"] = {
        truncate = { "PROP_CAMP_FIRE_" },
        Poses = {
            {"PROP_CAMP_FIRE_SEATED", "Seated"},
            {"PROP_CAMP_FIRE_SEAT_BENCH", "Seat Bench"},
            {"PROP_CAMP_FIRE_SEAT_CHAIR", "Seat Chair"},
            {"PROP_CAMP_FIRE_SEAT_LOG_LEAN", "Lean on Log"},
        },
    },

    ["Sleep Bed Pillow"] = {
        truncate = { "PROP_HUMAN_SLEEP_BED_PILLOW_", "PROP_HUMAN_SLEEP_" },
        Poses = {
            {"PROP_HUMAN_SLEEP_BED_PILLOW", "Sleep"},
            {"PROP_HUMAN_SLEEP_BED_PILLOW_HIGH", "High"},
            {"PROP_HUMAN_SLEEP_BED_PILLOW_LEFT", "Left"},
            {"PROP_HUMAN_SLEEP_BED_PILLOW_RIGHT", "Right"},
        },
    },
}
