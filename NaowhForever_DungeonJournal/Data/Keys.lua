-- Keys.lua: the key each dungeon needs to get in, the ones that open doors or a shortcut inside, and what calls a boss, by hand.
local J = _G.NaowhForever.Journal

J.Keys = {
    ScarletMonasteryArmory = { { item = 7146, boss = 6487 } },
    ScarletMonasteryCathedral = { { item = 7146, boss = 6487 } },
    Scholomance = { { item = 13704, quest = { A = 5505, H = 5511 } } },
    UpperBlackrockSpire = { { item = 12344, quest = 4742 } },
    OnyxiasLair = { { item = 16309, quest = { A = 6502, H = 6602 } } },
    DireMaulWest = { { item = 18249, boss = 14354, opens = "doors" } },
    DireMaulNorth = { { item = 18249, boss = 14354, opens = "doors" } },
    BlackrockDepths = {
        { item = 11000, quest = 3802, opens = "shortcut" },
        { item = 11140, boss = 9018, opens = "doors" },
    },
    Gnomeregan = { { item = 6893, boss = 6235, opens = "shortcut" } },
    Stratholme = { { item = 12382, boss = 10435, opens = "shortcut" } },
    Maraudon = { { item = 17191, quest = 7046, opens = "shortcut" } },
}

J.Summons = {
    [7273] = { { item = 9240, drop = "Qiaga the Keeper", zone = 1425, opens = "summon" } },
    [8443] = { { item = 10465, quest = 3528, opens = "summon" } },
    [10506] = { { item = 13523, quest = 5384, opens = "summon" } },
    [10584] = { { item = 12534, boss = 9196, opens = "summon" } },
    [16080] = { { item = 22049, quest = 8966, opens = "summon" } },
    [16097] = { { item = 22050, quest = 8967, opens = "summon" } },
    [16118] = { { item = 22052, quest = 8969, opens = "summon" } },
    [16042] = { { item = 22056, quest = 8995, opens = "summon" } },
}
