ConfigGroups = {}

ConfigGroups.Scenario = {
    ["Sitting"] = {
        truncate = {
            "PROP_HUMAN_SEAT_",
            "PROP_HUMAN_SEAT_",
            "PROP_CAMP_FIRE_",
        },
        Scenarios = {
            ["Sitting"] = {
                {"PROP_HUMAN_SEAT_CHAIR", ""},
                {"PROP_HUMAN_SEAT_BENCH", ""},
                {"PROP_HUMAN_SEAT_BENCH_PORCH", ""},
                {"PROP_HUMAN_SEAT_BENCH_TIRED", ""},
            },
            ["Instruments"] = {
                {"PROP_HUMAN_SEAT_CHAIR_BANJO", "male"},
                {"PROP_HUMAN_SEAT_CHAIR_BANJO_DOWNBEAT", "male"},
                {"PROP_HUMAN_SEAT_CHAIR_BANJO_UPBEAT", "male"},
                {"PROP_HUMAN_SEAT_CHAIR_GUITAR", "male"},
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
            },
            ["Drinking / Smoking"] = {
                {"PROP_HUMAN_SEAT_CHAIR_CIGAR", ""},
                {"PROP_HUMAN_SEAT_CHAIR_DRINKING_MOONSHINE", ""},
                {"PROP_HUMAN_SEAT_CHAIR_SMOKING", ""},
                {"PROP_HUMAN_SEAT_BENCH_PORCH_DRINKING_MOONSHINE", ""},
            },
            ["Other Activities"] = {
                {"PROP_HUMAN_SEAT_CHAIR_FAN", "female"},
                {"PROP_HUMAN_SEAT_CHAIR_KNIFE_BADASS", ""},
                {"PROP_HUMAN_SEAT_CHAIR_KNITTING", "female"},
                {"PROP_HUMAN_SEAT_CHAIR_READING", ""},
                {"PROP_HUMAN_SEAT_CHAIR_READ_NEWSPAPER", ""},
                {"PROP_HUMAN_SEAT_CHAIR_SEWING", "female"},
                {"PROP_HUMAN_SEAT_CHAIR_SHARPEN_AXE", ""},
                {"PROP_HUMAN_SEAT_CHAIR_SKETCHING", ""},
                {"PROP_HUMAN_SEAT_CHAIR_WHITTLE", ""},
                {"PROP_HUMAN_SEAT_CHAIR_FISHING_ROD", ""},
            },
        },
    },

    ["Piano"] = {
        truncate = {
            "PROP_HUMAN_PIANO_",
            "PROP_HUMAN_",
        },
        Scenarios = {
            ["Piano"] = {
                {"PROP_HUMAN_PIANO", ""},
                {"PROP_HUMAN_PIANO_RIVERBOAT", ""},
                {"PROP_HUMAN_PIANO_SKETCHY", ""},
                {"PROP_HUMAN_PIANO_UPPERCLASS", ""},
            },
        },
    },

    ["Sit at Table"] = {
        truncate = {
            "PROP_HUMAN_SEAT_CHAIR_TABLE_",
        },
        Scenarios = {
            ["Dining"] = {
                {"PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING", ""},
                {"PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING_MOONSHINE", ""},
                {"PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING_WHISKEY_MOONSHINE", ""},
                {"PROP_HUMAN_SEAT_CHAIR_TABLE_FAN_WHORE", "female"},
            },
        },
    },

    ["Camp Fire"] = {
        truncate = {
            "PROP_CAMP_FIRE_SEATED_",
            "PROP_CAMP_FIRE_",
        },
        Scenarios = {
            ["Sitting"] = {
                {"PROP_CAMP_FIRE_SEATED", ""},
                {"PROP_CAMP_FIRE_SEATED_FEMALE_A", "female"},
                {"PROP_CAMP_FIRE_SEATED_FEMALE_B", "female"},
                {"PROP_CAMP_FIRE_SEATED_FEMALE_C", "female"},
                {"PROP_CAMP_FIRE_SEATED_FEMALE_D", "female"},
                {"PROP_CAMP_FIRE_SEATED_FEMALE_E", "female"},
                {"PROP_CAMP_FIRE_SEATED_FEMALE_F", "female"},
                {"PROP_CAMP_FIRE_SEATED_MALE_A", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_B", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_C", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_D", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_E", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_F", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_G", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_H", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_I", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_J", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_K", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_L", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_M", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_N", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_O", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_P", "male"},
                {"PROP_CAMP_FIRE_SEATED_MALE_Q", "male"},
                {"PROP_CAMP_FIRE_SEAT_BENCH", ""},
                {"PROP_CAMP_FIRE_SEAT_BENCH_FEMALE_A", "female"},
                {"PROP_CAMP_FIRE_SEAT_BENCH_MALE_A", "male"},
                {"PROP_CAMP_FIRE_SEAT_BENCH_MALE_B", "male"},
                {"PROP_CAMP_FIRE_SEAT_BENCH_MALE_C", "male"},
            },
            ["Drinking"] = {
                {"PROP_CAMP_FIRE_SEATED_DRINKING_BEER_MALE_A", "male"},
                {"PROP_CAMP_FIRE_SEATED_DRINKING_BEER_MALE_B", "male"},
                {"PROP_CAMP_FIRE_SEATED_DRINKING_BEER_MALE_C", "male"},
                {"PROP_CAMP_FIRE_SEATED_DRINKING_WHISKEY_MALE_C", "male"},
                {"PROP_CAMP_FIRE_SEATED_DRINKING_WHISKEY_MALE_D", "male"},
                {"PROP_CAMP_FIRE_SEATED_DRINKING_WHISKEY_MALE_E", "male"},
                {"PROP_CAMP_FIRE_SEAT_CHAIR", ""},
                {"PROP_CAMP_FIRE_SEAT_CHAIR_FEMALE_A", "female"},
                {"PROP_CAMP_FIRE_SEAT_CHAIR_MALE_A", "male"},
                {"PROP_CAMP_FIRE_SEAT_CHAIR_MALE_B", "male"},
                {"PROP_CAMP_FIRE_SEAT_CHAIR_MALE_C", "male"},
                {"PROP_CAMP_FIRE_SEAT_LOG_LEAN", ""},
                {"PROP_CAMP_FIRE_SEAT_LOG_LEAN_FEMALE_A", "female"},
                {"PROP_CAMP_FIRE_SEAT_LOG_LEAN_MALE_A", "male"},
            },
            ["Work"] = {
                {"PROP_CAMP_FIRE_SEATED_TEND_FIRE", ""},
                {"PROP_CAMP_FIRE_SEATED_TEND_FIRE_MALE_A", "male"},
            },
        },
    },


    ["PROP_CAMP_SEAT_CHAIR_STEW"] = {
        truncate = {
            "PROP_CAMP_SEAT_CHAIR_STEW_",
            "PROP_CAMP_SEAT_CHAIR_",
        },
        Scenarios = {
            ["Eating"] = {
                {"PROP_CAMP_SEAT_CHAIR_STEW_EATING_FEMALE_A", "female"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_EATING_FEMALE_B", "female"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_EATING_LAZY_FEMALE_A", "female"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_EATING_LAZY_FEMALE_B", "female"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_EATING_LAZY_MALE_A", "male"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_EATING_LAZY_MALE_B", "male"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_EATING_MALE_A", "male"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_EATING_MALE_B", "male"},
            },
            ["Resting"] = {
                {"PROP_CAMP_SEAT_CHAIR_STEW", ""},
                {"PROP_CAMP_SEAT_CHAIR_STEW_FALLBACK", ""},
                {"PROP_CAMP_SEAT_CHAIR_STEW_LAZY", ""},
                {"PROP_CAMP_SEAT_CHAIR_STEW_RESTING_FEMALE_A", "female"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_RESTING_FEMALE_B", "female"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_RESTING_LAZY_FEMALE_A", "female"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_RESTING_LAZY_FEMALE_B", "female"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_RESTING_LAZY_MALE_A", "male"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_RESTING_LAZY_MALE_B", "male"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_RESTING_MALE_A", "male"},
                {"PROP_CAMP_SEAT_CHAIR_STEW_RESTING_MALE_B", "male"},
            },
        },
    },

    ["PROP_CAMP_SEAT_CHAIR_TABLE_STEW"] = {
        truncate = {
            "PROP_CAMP_SEAT_CHAIR_TABLE_STEW_",
            "PROP_CAMP_SEAT_CHAIR_TABLE_",
        },
        Scenarios = {
            ["Eating"] = {
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_EATING_FEMALE_A", "female"},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_EATING_FEMALE_B", "female"},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_EATING_LAZY_MALE_A", "male"},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_EATING_LAZY_MALE_B", "male"},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_EATING_MALE_A", "male"},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_EATING_MALE_B", "male"},
            },
            ["Resting"] = {
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW", ""},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_BEECHERS", ""},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_FALLBACK", ""},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_LAZY", ""},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_RESTING_FEMALE_A", "female"},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_RESTING_FEMALE_B", "female"},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_RESTING_LAZY_MALE_A", "male"},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_RESTING_LAZY_MALE_B", "male"},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_RESTING_MALE_A", "male"},
                {"PROP_CAMP_SEAT_CHAIR_TABLE_STEW_RESTING_MALE_B", "male"},
            },
        },
    },

    ["PROP_HUMAN_PUMP_WATER"] = {
        truncate = {
            "PROP_HUMAN_PUMP_WATER_",
            "PROP_HUMAN_PUMP_",
        },
        Scenarios = {
            ["Pumping"] = {
                {"PROP_HUMAN_PUMP_WATER", ""},
                {"PROP_HUMAN_PUMP_WATER_FEMALE_B", "female"},
                {"PROP_HUMAN_PUMP_WATER_MALE_A", "male"},
            },
            ["With Bucket"] = {
                {"PROP_HUMAN_PUMP_WATER_BUCKET", ""},
                {"PROP_HUMAN_PUMP_WATER_BUCKET_FEMALE_B", "female"},
                {"PROP_HUMAN_PUMP_WATER_BUCKET_MALE_A", "male"},
            },
        },
    },

    ["PROP_HUMAN_GRINDSTONE"] = {
        truncate = {
            "PROP_HUMAN_GRINDSTONE_",
            "PROP_HUMAN_",
        },
        Scenarios = {
            ["Grinding"] = {
                {"PROP_HUMAN_GRINDSTONE", ""},
                {"PROP_HUMAN_GRINDSTONE_MALE_A", "male"},
            },
        },
    },

    ["PROP_HUMAN_FOODPREP_STEW"] = {
        truncate = {
            "PROP_HUMAN_FOODPREP_STEW_",
            "PROP_HUMAN_FOODPREP_",
        },
        Scenarios = {
            ["Base"] = {
                {"PROP_HUMAN_FOODPREP_STEW", ""},
                {"PROP_HUMAN_FOODPREP_STEW_ALWAYS", ""},
            },
            ["Preparing"] = {
                {"PROP_HUMAN_FOODPREP_STEW_ADD_MEAT_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_ADD_MEAT_MALE_B", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_CHOP_CARROT_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_CHOP_CARROT_MALE_B", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_CHOP_POTATO_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_CHOP_POTATO_MALE_B", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_GRAB_CARROT_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_GRAB_CARROT_MALE_B", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_GRAB_POTATO_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_GRAB_POTATO_MALE_B", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_SCOOP_CARROT_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_SCOOP_CARROT_MALE_B", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_SCOOP_POTATO_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_SCOOP_POTATO_MALE_B", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_SEASONING_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_SEASONING_MALE_B", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_VEGDROP_CARROT_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_VEGDROP_CARROT_MALE_B", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_VEGDROP_POTATO_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_VEGDROP_POTATO_MALE_B", "male"},
            },
            ["Resting"] = {
                {"PROP_HUMAN_FOODPREP_STEW_QUICKREST_PRE_CARROT_CHOP_MALE_D", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_QUICKREST_PRE_POTATO_CHOP_MALE_D", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_QUICKREST_PRE_VEG_GRAB_CARROT_MALE_D", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_QUICKREST_PRE_VEG_GRAB_POTATO_MALE_D", "male"},
                {"PROP_HUMAN_FOODPREP_STEW_RESTING_FEMALE_A", "female"},
                {"PROP_HUMAN_FOODPREP_STEW_RESTING_MALE_D", "male"},
            },
            ["Carrying"] = {
                {"PROP_HUMAN_FOODPREP_STEW_CARRY_CAULDRON_MALE_D", "male"},
            },
        },
    },

    ["PROP_HUMAN_CAULDRON_SERVE_STEW"] = {
        truncate = {
            "PROP_HUMAN_CAULDRON_SERVE_STEW_",
            "PROP_HUMAN_CAULDRON_SERVE_",
        },
        Scenarios = {
            ["Serving"] = {
                {"PROP_HUMAN_CAULDRON_SERVE_STEW", ""},
                {"PROP_HUMAN_CAULDRON_SERVE_STEW_FEMALE_A", "female"},
                {"PROP_HUMAN_CAULDRON_SERVE_STEW_MALE_B", "male"},
                {"PROP_HUMAN_CAULDRON_SERVE_STEW_PLAYER", ""},
            },
            ["Always"] = {
                {"PROP_HUMAN_CAULDRON_SERVE_STEW_ALWAYS", ""},
                {"PROP_HUMAN_CAULDRON_SERVE_STEW_ALWAYS_FEMALE_A", "female"},
                {"PROP_HUMAN_CAULDRON_SERVE_STEW_ALWAYS_MALE_B", "male"},
            },
            ["No Pot"] = {
                {"PROP_HUMAN_CAULDRON_SERVE_STEW_NO_POT", ""},
                {"PROP_HUMAN_CAULDRON_SERVE_STEW_NO_POT_FEMALE_A", "female"},
                {"PROP_HUMAN_CAULDRON_SERVE_STEW_NO_POT_MALE_B", "male"},
            },
        },
    },

    ["PROP_HUMAN_WOOD_CHOP"] = {
        truncate = {
            "PROP_HUMAN_WOOD_CHOP_",
            "PROP_HUMAN_WOOD_",
        },
        Scenarios = {
            ["Chopping"] = {
                {"PROP_HUMAN_WOOD_CHOP", ""},
                {"PROP_HUMAN_WOOD_CHOP_CHOP_FRONT", ""},
                {"PROP_HUMAN_WOOD_CHOP_CHOP_FRONT_LAST", ""},
                {"PROP_HUMAN_WOOD_CHOP_PRE_CHOP_01_02", ""},
                {"PROP_HUMAN_WOOD_CHOP_PRE_CHOP_03_04", ""},
                {"PROP_HUMAN_WOOD_CHOP_PRE_CHOP_05_06", ""},
                {"PROP_HUMAN_WOOD_CHOP_PRE_CHOP_07_08", ""},
                {"PROP_HUMAN_WOOD_CHOP_PRE_CHOP_09_08", ""},
                {"PROP_HUMAN_WOOD_CHOP_PRE_CHOP_11_12", ""},
                {"PROP_HUMAN_WOOD_CHOP_POST_CHOP_01_02", ""},
                {"PROP_HUMAN_WOOD_CHOP_POST_CHOP_03_04", ""},
                {"PROP_HUMAN_WOOD_CHOP_POST_CHOP_05_06", ""},
                {"PROP_HUMAN_WOOD_CHOP_POST_CHOP_07_08", ""},
                {"PROP_HUMAN_WOOD_CHOP_POST_CHOP_09_08", ""},
                {"PROP_HUMAN_WOOD_CHOP_POST_CHOP_11_12", ""},
                {"PROP_HUMAN_WOOD_CHOP_POST_CHOP_11_12_PLAYER", ""},
                {"PROP_HUMAN_WOOD_CHOP_POST_CHOP_TO_WOODROP", ""},
            },
            ["With Axe"] = {
                {"PROP_HUMAN_WOOD_CHOP_AND_SHARPEN_AXE", ""},
                {"PROP_HUMAN_WOOD_CHOP_AXESTUCK_01_02", ""},
                {"PROP_HUMAN_WOOD_CHOP_AXESTUCK_03_04", ""},
                {"PROP_HUMAN_WOOD_CHOP_AXESTUCK_05_06", ""},
                {"PROP_HUMAN_WOOD_CHOP_AXESTUCK_07_08", ""},
                {"PROP_HUMAN_WOOD_CHOP_AXESTUCK_09_10", ""},
            },
            ["Logs"] = {
                {"PROP_HUMAN_WOOD_CHOP_GRAB_LOG_01_02", ""},
                {"PROP_HUMAN_WOOD_CHOP_GRAB_LOG_03_04", ""},
                {"PROP_HUMAN_WOOD_CHOP_GRAB_LOG_05_06", ""},
                {"PROP_HUMAN_WOOD_CHOP_GRAB_LOG_07_08", ""},
                {"PROP_HUMAN_WOOD_CHOP_GRAB_LOG_09_08", ""},
                {"PROP_HUMAN_WOOD_CHOP_GRAB_LOG_11_12", ""},
                {"PROP_HUMAN_WOOD_CHOP_CARRYLOG1_06_03_02", ""},
                {"PROP_HUMAN_WOOD_CHOP_CARRYLOG2_12_10_07", ""},
                {"PROP_HUMAN_WOOD_CHOP_LOGDROP1_06_03_02", ""},
                {"PROP_HUMAN_WOOD_CHOP_LOGDROP2_12_10_07", ""},
                {"PROP_HUMAN_WOOD_CHOP_SLING_GRAB", ""},
            },
            ["Picking"] = {
                {"PROP_HUMAN_WOOD_CHOP_PICKUPLSIDE1", ""},
                {"PROP_HUMAN_WOOD_CHOP_PICKUPLSIDE2", ""},
                {"PROP_HUMAN_WOOD_CHOP_PICKUPRSIDE1_01_05_04", ""},
                {"PROP_HUMAN_WOOD_CHOP_PICKUPRSIDE2_08_09_11", ""},
            },
        },
    },

    ["PROP_HUMAN_SLEEP_BED_PILLOW"] = {
        truncate = {
            "PROP_HUMAN_SLEEP_",
        },
        Scenarios = {
            ["Sleeping"] = {
                {"PROP_HUMAN_SLEEP_BED_PILLOW", ""},
                {"PROP_HUMAN_SLEEP_BED_PILLOW_HIGH", ""},
                {"PROP_HUMAN_SLEEP_BED_PILLOW_LEFT", ""},
                {"PROP_HUMAN_SLEEP_BED_PILLOW_RIGHT", ""},
            },
        },
    },

    ["PROP_HUMAN_TANNING_RACK_FLESHING"] = {
        truncate = {
            "PROP_HUMAN_",
        },
        Scenarios = {
            ["Working"] = {
                {"PROP_HUMAN_TANNING_RACK_FLESHING", ""},
                {"PROP_HUMAN_TANNING_RACK_BRAINS", ""},
                {"PROP_HUMAN_SOAK_SKINS", ""},
            },
        },
    },

    ["PROP_HUMAN_REPAIR_WAGON_WHEEL_ON_LARGE"] = {
        truncate = {
            "PROP_HUMAN_",
        },
        Scenarios = {
            ["Large Wheel"] = {
                {"PROP_HUMAN_REPAIR_WAGON_WHEEL_ON_LARGE", ""},
                {"PROP_HUMAN_REPAIR_WAGON_WHEEL_ON_LARGE_MALE_A", "male"},
            },
            ["Small Wheel"] = {
                {"PROP_HUMAN_REPAIR_WAGON_WHEEL_ON_SMALL", ""},
                {"PROP_HUMAN_REPAIR_WAGON_WHEEL_ON_SMALL_MALE_A", "male"},
            },
        },
    },

}