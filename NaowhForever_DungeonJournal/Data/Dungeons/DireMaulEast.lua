-- DireMaulEast.lua: Dire Maul - East in the Dungeon Journal, split by hand from journal.py's Dire Maul.
local ns = _G.NaowhForever

ns.Journal.AddDungeon("DireMaulEast", {
    name = "Dire Maul - East",
    instance = 429,
    listedAs = { "Dire Maul - Warpwood Quarter" },
    zone = "Feralas", area = 357, territory = "Contested",
    entrance = { map = 1444, x = 64.9, y = 29.4 },
    doors = {
        { name = "Front Door", map = 1444, x = 64.9, y = 29.4 },
        { name = "Back Door", map = 1444, x = 76.5, y = 35.9 },
    },
    wings = {
        { bosses = {
            { npc = 14354, name = "Pusillin", model = 7552, encounters = { 2792 }, loot = { 18316, 18320, 18303, 18304, 18267 } },
            { npc = 11490, name = "Zevrim Thornhoof", model = 11335, encounters = { 343 }, loot = { 18306, 18308, 18313, 18323, 18319 }, chance = { 25, 24, 19, 19, 10 } },
            { npc = 13280, name = "Hydrospawn", model = 5489, encounters = { 344 }, loot = { 18305, 18307, 18322, 18317, 18324 }, chance = { 24, 24, 20, 19, 10 } },
            { npc = 14327, name = "Lethtendris", model = 14378, encounters = { 345 }, loot = { 18302, 18325, 18301, 18311, 18354 }, chance = { 29, 29, 28, 9, 0 } },
            { npc = 11492, name = "Alzzin the Wildshaper", model = 14416, encounters = { 346 }, loot = { 18310, 18314, 18321, 18315, 18328, 18312, 18309, 18326, 18327, 18318 }, chance = { 19, 19, 19, 19, 19, 19, 19, 19, 19, 19 } },
            { npc = 16097, name = "Isalien", model = 16000, optional = true, loot = { 22314, 22304, 22472, 22315, 22401, 22345 }, chance = { 22, 20, 19, 14, 12, 10 } },
            { npc = nil, name = "Trash", trash = true, loot = { 18494, 18498, 18496, 18493, 18497, 18289, 18295, 18340, 18343, 18339, 18338, 18344, 18337, 18298, 18296, 18528, 18530, 18533, 18475, 18477, 18479 }, chance = { 7, 7, 6, 6, 6, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 } },
        } },
    },
})
