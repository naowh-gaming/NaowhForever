-- DireMaulWest.lua: Dire Maul - West in the Dungeon Journal, split by hand from journal.py's Dire Maul.
local ns = _G.NaowhForever

ns.Journal.AddDungeon("DireMaulWest", {
    name = "Dire Maul - West",
    instance = 429,
    listedAs = { "Dire Maul - Capital Gardens" },
    zone = "Feralas", area = 357, territory = "Contested",
    entrance = { map = 1444, x = 60.3, y = 30.7 },
    wings = {
        { bosses = {
            { npc = 11489, name = "Tendris Warpwood", model = 14383, encounters = { 350 }, loot = { 18390, 18352, 18353, 18393, 273120 }, chance = { 24, 24, 24, 24, 0 } },
            { npc = 11488, name = "Illyanna Ravenoak", model = 11270, encounters = { 347 }, loot = { 18347, 18349, 18383, 18386 }, chance = { 24, 24, 24, 22 } },
            { npc = 11487, name = "Magister Kalendris", model = 14384, encounters = { 348 }, loot = { 18350, 18351, 18374, 18397, 18371, 22309 }, chance = { 25, 23, 20, 19, 9, 0 } },
            { npc = 11496, name = "Immol'thar", model = 14173, encounters = { 349 }, loot = { 18377, 18379, 18381, 18391, 18385, 18384, 18389, 18394, 18372, 18370 }, chance = { 26, 25, 24, 24, 21, 19, 19, 19, 10, 9 } },
            { npc = 11486, name = "Prince Tortheldrin", model = 11256, encounters = { 361 }, loot = { 18395, 18382, 18380, 18378, 18396, 18392, 18376, 18375, 18388, 18373 }, chance = { 24, 24, 23, 21, 20, 19, 18, 17, 10, 9 } },
            { npc = 11467, name = "Tsu'zee", model = 11250, rare = true, encounters = { 2794 }, loot = { 18345, 18387, 18346 }, chance = { 33, 30, 29 } },
            { npc = 14506, name = "Lord Hel'nurath", model = 14556, optional = true, encounters = { 2793 }, loot = { 18755, 18756, 18757, 18754 }, chance = { 25, 25, 24, 22 } },
            { npc = 14690, name = "Revanchion", model = 14695, optional = true, loot = { 23128, 23127, 23129 }, chance = { 56, 33, 11 } },
            { npc = nil, name = "Trash", trash = true, loot = { 18494, 18498, 18496, 18493, 18497, 18289, 18295, 18340, 18343, 18339, 18338, 18344, 18337, 18298, 18296, 18528, 18530, 18533, 18475, 18477, 18479 }, chance = { 7, 7, 6, 6, 6, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 } },
        } },
    },
})
