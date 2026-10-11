-- Stats.lua: the stats the character panel lists for your spec, in order, and what each one does for your class (CP.Stats).
local ns = _G.NaowhForever

local CP = ns.CharacterPanel

local AGI_MELEE = "Attack power, ranged attack power, crit chance, armor and dodge."
local STR_BLOCK = "Attack power and block value."
local INT_NO_MANA = "Faster weapon skill gains."
local SPI_NO_MANA = "Health back out of combat."

CP.Stats = {
    ORDER = { "agi", "str", "int", "spi", "ap", "rap", "spell", "heal", "fire", "frost", "shadow",
        "nature", "arcane", "holy", "crit", "scrit", "hit", "shit", "haste", "dps", "mp5", "def", "dodge",
        "block", "sta", "armor" },
    ALWAYS = { sta = true, armor = true },
    SHORT = { rap = "Ranged AP", mp5 = "Mana / 5 sec" },
    YARDSTICKS = { "agi", "str", "sta", "spell", "heal", "int", "ap" },
    HEADING = { agi = "VS AGI", str = "VS STR", sta = "VS STA", spell = "VS SPELL", heal = "VS HEAL",
        int = "VS INT", ap = "VS AP" },
    PERCENT = { hit = true, shit = true, crit = true, haste = true, scrit = true, dodge = true, block = true },
    DOES_BY_CLASS = {
        agi = {
            WARRIOR = "Ranged attack power, crit chance, armor and dodge.",
            ROGUE = AGI_MELEE,
            HUNTER = AGI_MELEE,
            DRUID = "Attack power in Cat Form, crit chance, armor and dodge.",
        },
        str = { WARRIOR = STR_BLOCK, PALADIN = STR_BLOCK, SHAMAN = STR_BLOCK },
        int = { WARRIOR = INT_NO_MANA, ROGUE = INT_NO_MANA },
        spi = { WARRIOR = SPI_NO_MANA, ROGUE = SPI_NO_MANA },
    },
    DOES = {
        agi = "Crit chance, armor and dodge.",
        str = "Attack power.",
        int = "Mana, spell crit chance and faster weapon skill gains.",
        spi = "Health back out of combat, and mana back while not casting.",
        ap = "More damage from your weapons.",
        rap = "More damage from your ranged weapon.",
        spell = "More damage from your spells.",
        heal = "More healing from your spells.",
        fire = "More damage from your Fire spells.",
        frost = "More damage from your Frost spells.",
        shadow = "More damage from your Shadow spells.",
        nature = "More damage from your Nature spells.",
        arcane = "More damage from your Arcane spells.",
        holy = "More damage from your Holy spells.",
        crit = "Chance for a hit to deal double damage.",
        scrit = "Chance for a spell to crit.",
        hit = "Chance not to miss: worth the most until you stop missing.",
        shit = "Chance for a spell not to miss: worth the most until you stop missing.",
        haste = "Faster attacks.",
        dps = "Your weapon's damage per second.",
        mp5 = "Mana back every 5 seconds, even while casting.",
        def = "Lowers the chance to be hit, crit and dazed.",
        dodge = "Chance to dodge a melee hit.",
        block = "Chance to block a hit with a shield.",
        sta = "Health.",
        armor = "Less physical damage taken.",
    },
}
