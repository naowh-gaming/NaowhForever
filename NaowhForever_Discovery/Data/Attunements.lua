-- Attunements.lua: the keys and attunements dungeons and raids ask for, each with the quest that gives it, and the Tier 0.5 questline.
local ns = _G.NaowhForever

local BLACKROCK_DEPTHS = "Blackrock Depths"
local BLACKROCK_SPIRE = "Lower Blackrock Spire"
local MARAUDON = "Maraudon"
local DIRE_MAUL = "Dire Maul"
local WINDSOR = "Marshal Windsor"
local INFILTRATOR = "Scarshield Infiltrator"
local FALRIN = "Falrin Treeshaper"

ns.Attunements = {
    list = {
        { dungeon = MARAUDON, item = 17191, quest = 7046 },
        { dungeon = BLACKROCK_DEPTHS, item = 11000, quest = 3802 },
        { dungeon = "Scholomance", item = 13704, quest = { A = 5505, H = 5511 } },
        { dungeon = "Molten Core", icon = 18412, quest = 7848, raid = true },
        { dungeon = "Upper Blackrock Spire", item = 12344, quest = 4743 },
        { dungeon = "Onyxia's Lair", item = 16309, quest = { A = 6502, H = 6602 }, raid = true },
        { dungeon = "Tier 0.5", icon = 22014, class = true, steps = {
            "proposition", { A = 8922, H = 8923 }, 8921, 8924, 8925, 8928, { A = 8977, H = 8978 },
            "compensation", { A = 8929, H = 8930 }, 8945, 8946, 8947, 8948, 8949, 8950, 9015,
            "parting", { A = 8960, H = 9032 }, 8961, { 8962, 8963, 8964, 8965 }, { 8966, 8967, 8968, 8969 }, 8970,
            { 8985, 8986, 8987, 8988 }, { 8989, 8990, 8991, 8992 }, 8994, 8995, 8996, { A = 8997, H = 8998 },
            "best",
        } },
    },
    classQuests = {
        A = {
            DRUID = { proposition = { 84147, 8905 }, compensation = { 84163, 8926 }, parting = { 84179, 8951 }, best = { 84195, 8999 } },
            HUNTER = { proposition = { 84148, 8906 }, compensation = { 84164, 8931 }, parting = { 84180, 8952 }, best = { 84196, 9000 } },
            MAGE = { proposition = { 84149, 8907 }, compensation = { 84165, 8932 }, parting = { 84181, 8953 }, best = { 84197, 9001 } },
            PALADIN = { proposition = { 84150, 8908 }, compensation = { 84166, 8933 }, parting = { 84182, 8954 }, best = { 84198, 9002 } },
            PRIEST = { proposition = { 84151, 8909 }, compensation = { 84167, 8934 }, parting = { 84183, 8955 }, best = { 84199, 9003 } },
            ROGUE = { proposition = { 84152, 8910 }, compensation = { 84168, 8935 }, parting = { 84184, 8956 }, best = { 84200, 9004 } },
            WARLOCK = { proposition = { 84153, 8911 }, compensation = { 84169, 8936 }, parting = { 84185, 8958 }, best = { 84201, 9005 } },
            WARRIOR = { proposition = { 84154, 8912 }, compensation = { 84170, 8937 }, parting = { 84186, 8959 }, best = { 84202, 9006 } },
            SHAMAN = { proposition = { 97447 }, compensation = { 97448 }, parting = { 97449 }, best = { 97450 } },
        },
        H = {
            DRUID = { proposition = { 84155, 8913 }, compensation = { 84171, 8927 }, parting = { 84187, 9016 }, best = { 84203, 9007 } },
            HUNTER = { proposition = { 84156, 8914 }, compensation = { 84172, 8938 }, parting = { 84188, 9017 }, best = { 84204, 9008 } },
            MAGE = { proposition = { 84157, 8915 }, compensation = { 84173, 8939 }, parting = { 84189, 9018 }, best = { 84205, 9014 } },
            PRIEST = { proposition = { 84158, 8916 }, compensation = { 84174, 8940 }, parting = { 84190, 9019 }, best = { 84206, 9009 } },
            ROGUE = { proposition = { 84159, 8917 }, compensation = { 84175, 8941 }, parting = { 84191, 9020 }, best = { 84207, 9010 } },
            SHAMAN = { proposition = { 84160, 8918 }, compensation = { 84176, 8942 }, parting = { 84192, 8957 }, best = { 84208, 9011 } },
            WARLOCK = { proposition = { 84161, 8919 }, compensation = { 84177, 8943 }, parting = { 84193, 9021 }, best = { 84209, 9012 } },
            WARRIOR = { proposition = { 84162, 8920 }, compensation = { 84178, 8944 }, parting = { 84194, 9022 }, best = { 84210, 9013 } },
            PALADIN = { proposition = { 97411 }, compensation = { 97412 }, parting = { 97413 }, best = { 97414 } },
        },
    },
    inside = {
        [4242] = { BLACKROCK_DEPTHS, WINDSOR }, [4264] = { BLACKROCK_DEPTHS }, [4282] = { BLACKROCK_DEPTHS, WINDSOR },
        [4322] = { BLACKROCK_DEPTHS, WINDSOR },
        [4742] = { BLACKROCK_SPIRE, INFILTRATOR }, [4743] = { BLACKROCK_SPIRE, INFILTRATOR },
        [7046] = { MARAUDON, "Celebras the Redeemed" },
        [8946] = { "Stratholme", "Ysida Harmon" }, [8949] = { DIRE_MAUL, FALRIN }, [8950] = { DIRE_MAUL, FALRIN },
        [8996] = { "Upper Blackrock Spire", "Spirit of Lord Valthalak" }, [9015] = { DIRE_MAUL, FALRIN },
    },
    notes = {
        [8961] = "On Forever it asks for the Ash of Asharell, not the Cinder of Cynders: Executor Asharell drops it, in a cave in the Burning Steppes (72.4, 68.5).",
    },
}
