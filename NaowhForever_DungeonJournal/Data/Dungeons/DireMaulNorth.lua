-- DireMaulNorth.lua: Dire Maul - North in the Dungeon Journal, split by hand from journal.py's Dire Maul.
local ns = _G.NaowhForever

ns.Journal.AddDungeon("DireMaulNorth", {
    name = "Dire Maul - North",
    instance = 429,
    listedAs = { "Dire Maul - Gordok Commons" },
    listsInstance = true,
    zone = "Feralas", area = 357, territory = "Contested",
    entrance = { map = 1444, x = 62.9, y = 24.9 },
    wings = {
        { bosses = {
            { npc = 14326, name = "Guard Mol'dar", model = 11561, encounters = { 362 }, loot = { 18458, 18451, 18463, 18493, 18494, 18459, 18460, 18450, 18496, 18498, 18462, 18497, 18464 }, chance = { 14, 9, 9, 8, 8, 8, 8, 7, 6, 6, 6, 5, 4 } },
            { npc = 14322, name = "Stomper Kreeg", model = 11545, encounters = { 363 }, loot = { 18425 }, chance = { 56 } },
            { npc = 14321, name = "Guard Fengus", model = 11561, encounters = { 364 }, loot = { 18463, 18464, 18458, 18451, 18460, 18450, 18462, 18459 }, chance = { 17, 16, 14, 13, 13, 12, 12, 4 } },
            { npc = 14323, name = "Guard Slip'kik", model = 11561, encounters = { 365 }, loot = { 18462, 18459, 18463, 18496, 18450, 18498, 18458, 18493, 18451, 18497, 18464, 18494, 18460 }, chance = { 16, 12, 10, 9, 9, 7, 7, 6, 6, 5, 5, 4, 4 } },
            { npc = 14325, name = "Captain Kromcrush", model = 11564, encounters = { 366 }, loot = { 18503, 18507, 18505, 18502 }, chance = { 23, 23, 22, 22 } },
            { npc = 11501, name = "King Gordok", model = 11583, encounters = { 368 }, loot = { 18521, 18524, 18523, 18527, 18525, 18520, 18522, 18526 }, chance = { 25, 24, 24, 24, 24, 24, 24, 24 } },
            { npc = 14324, name = "Cho'Rush the Observer", model = 11537, optional = true, encounters = { 367 }, loot = { 18484, 18483, 18485, 18490 }, chance = { 44, 42, 42, 42 } },
            { npc = nil, name = "Gordok Tribute", chest = 179564, loot = { 18478, 18500, 18481, 18499, 18529, 18480, 18532, 18531, 18482, 18534, 18476, 18495, 18537 }, chance = { 3, 3, 3, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1 } },
            { npc = nil, name = "Trash", trash = true, loot = { 18494, 18498, 18496, 18493, 18497, 18289, 18295, 18340, 18343, 18339, 18338, 18344, 18337, 18298, 18296, 18528, 18530, 18533, 18475, 18477, 18479 }, chance = { 7, 7, 6, 6, 6, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0 } },
        } },
    },
})
