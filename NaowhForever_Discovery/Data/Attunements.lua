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
            DRUID = { proposition = { 8905, 84147 }, compensation = { 8926, 84163 }, parting = { 8951, 84179 }, best = { 8999, 84195 } },
            HUNTER = { proposition = { 8906, 84148 }, compensation = { 8931, 84164 }, parting = { 8952, 84180 }, best = { 9000, 84196 } },
            MAGE = { proposition = { 8907, 84149 }, compensation = { 8932, 84165 }, parting = { 8953, 84181 }, best = { 9001, 84197 } },
            PALADIN = { proposition = { 8908, 84150 }, compensation = { 8933, 84166 }, parting = { 8954, 84182 }, best = { 9002, 84198 } },
            PRIEST = { proposition = { 8909, 84151 }, compensation = { 8934, 84167 }, parting = { 8955, 84183 }, best = { 9003, 84199 } },
            ROGUE = { proposition = { 8910, 84152 }, compensation = { 8935, 84168 }, parting = { 8956, 84184 }, best = { 9004, 84200 } },
            WARLOCK = { proposition = { 8911, 84153 }, compensation = { 8936, 84169 }, parting = { 8958, 84185 }, best = { 9005, 84201 } },
            WARRIOR = { proposition = { 8912, 84154 }, compensation = { 8937, 84170 }, parting = { 8959, 84186 }, best = { 9006, 84202 } },
            SHAMAN = { proposition = { 8905, 97447 }, compensation = { 8926, 97448 }, parting = { 8951, 97449 }, best = { 8999, 97450 } },
        },
        H = {
            DRUID = { proposition = { 8913, 84155 }, compensation = { 8927, 84171 }, parting = { 9016, 84187 }, best = { 9007, 84203 } },
            HUNTER = { proposition = { 8914, 84156 }, compensation = { 8938, 84172 }, parting = { 9017, 84188 }, best = { 9008, 84204 } },
            MAGE = { proposition = { 8915, 84157 }, compensation = { 8939, 84173 }, parting = { 9018, 84189 }, best = { 9014, 84205 } },
            PRIEST = { proposition = { 8916, 84158 }, compensation = { 8940, 84174 }, parting = { 9019, 84190 }, best = { 9009, 84206 } },
            ROGUE = { proposition = { 8917, 84159 }, compensation = { 8941, 84175 }, parting = { 9020, 84191 }, best = { 9010, 84207 } },
            SHAMAN = { proposition = { 8918, 84160 }, compensation = { 8942, 84176 }, parting = { 8957, 84192 }, best = { 9011, 84208 } },
            WARLOCK = { proposition = { 8919, 84161 }, compensation = { 8943, 84177 }, parting = { 9021, 84193 }, best = { 9012, 84209 } },
            WARRIOR = { proposition = { 8920, 84162 }, compensation = { 8944, 84178 }, parting = { 9022, 84194 }, best = { 9013, 84210 } },
            PALADIN = { proposition = { 97411, 97411 }, compensation = { 8927, 97412 }, parting = { 9016, 97413 }, best = { 9007, 97414 } },
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
