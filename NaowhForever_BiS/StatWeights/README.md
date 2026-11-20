# Stat Weights

What each stat is worth to your spec, and so how much stronger an item makes you over what
you wear. Every spec has default weights; players change any of them in its window (the
scales on the BiS List's title bar), and only their changes are kept, for the account. Off by default.

- **Always on, for the BiS List:** its best enchant per slot and the upgrade percent on each
  BiS and on Run Next use these weights (yours where you changed them).
- **On (Upgrades on Tooltips):** a line on the tooltip of gear that is an upgrade for your spec,
  in its name: "Fire: (arrow) +9% upgrade", and under it what the item is weighed against.
  Nothing on gear that is not one. A ring or trinket is weighed against the weaker of the two
  you wear, a two-hander against both hands. While you hold a two-hander, a one-hander or an
  off-hand item is weighed with the best item in your bags for the other hand, and the line
  names it: "+4% upgrade (dot) Combat (dot) with Thrash Blade".
- **On (Upgrade Marks):** the arrow and percent on the item itself, no hover needed: quest rewards
  (at the quest giver and in the quest log and map), merchants, the loot window, loot rolls and the
  auction house's browse list. Among two or more reward choices, a gold coin marks the one that
  sells for most.
- **On (Healer Mana):** for a healer, Intellect and Spirit are worked out from your own mana instead
  of typed: Spirit from your regen while casting, Intellect from its mana over the Fight Length you
  pick and from its spell crit. Mana every 5 sec stays your number and prices both.
- **On (Mana Upgrades):** for a healer, a second tooltip line under the upgrade one when gear gives
  you more mana over a fight: "+6% mana", how much more than your mana gives now. It counts mana
  only, in Mana every 5 sec: Spirit's regen while casting, Intellect's 15 mana over the Fight Length.

Your spec is Automatic: the talent tree you spent the most points in (Forever keeps one spec
per class, its three trees as the talent tree's groups, read as its own talent frame reads
them), or the one you pick.

The switch and your spec are a card on the BiS List's settings page. The window has a switch
between your class's specs and a sample of the tooltip line; on the left only the stats the spec
uses, each a bar (how much it counts next to the others) and a number to type over, percents
and weapon dps under their own title, a changed one marked with its own reset. 0 takes a stat
off; Add a stat puts one on at 0 for your number. On the right, your BiS list's best upgrades
by these weights, so a change shows what it does. Import, Export and Reset are on its title bar. Export copies your changes as a line (`NFSW1:spec:stat=value,...`, only
what differs from the defaults); Import takes one, a WoWSims EP export (Stat Weights, Copy to
Current EP, Export), or a Healer Stat Weights Pawn string (its Export or Pawn button), which replaces
the spec's weights. An enchant's weapon damage is worth a
point of dps over the weapon's speed, so it has no weight of its own.

Forever's gear carries hit, crit, haste, expertise, dodge and block as ratings, read as their
percent (10 hit rating is 1%; `PER_PERCENT` in `StatWeights.lua`). Hit and crit are one rating each
for weapons and spells alike, so a hit item counts for Hit % and Spell Hit %, and a crit item
for Crit % and Spell Crit %: a spec weighs the one it uses.

The damage and tank defaults are MythicSim's simmed Forever weights (dated in the window's footer).
Healers keep hand-set defaults: there is no simmed healer data yet, so a healer imports the weights
Healer Stat Weights measures from their own fights, or turns on Healer Mana.

The percent is the item's weighted stats minus what you wear there, over what your stats are
worth now (your five stats as the game sums them, the rest from your gear; a weapon's damage
per second counts too, the off hand's at half, a hunter's ranged weapon's instead). An
estimate: it orders upgrades, it does not promise a number on a meter.

## Layout

```
StatWeights/
  StatWeights.xml      what loads, in order (the addon's BiS.xml includes it)
  Data/Defaults.lua    each spec's default weights, from MythicSim (ns.StatWeightDefaults)
  Data/IntPerCrit.lua  a healer class's Intellect per 1% spell crit, by level (ns.StatWeightIntPerCrit)
  StatWeights.lua      its settings, the stats and the game's keys for them, specs, your talents' spec,
                       your changes (ns.StatWeights)
  Worth.lua            an item's stats and worth, your power, the gain and best gain (SW.Gain, SW.BestGain)
  Healer.lua           Healer Mana: a healer's Intellect and Spirit from its own mana (SW.Healer)
  Sharing.lua          a spec's weights as a line, and back, or a simulator's export (SW.Export, SW.Import)
  Tooltip.lua          the tooltip line, installed the first time the module is turned on
  UI/Marks.lua         Upgrade Marks on quest rewards, merchants, loot, rolls and the auction house
  UI/Window.lua        its window: your spec's stats as bars and numbers, your best upgrades, reset, share
  UI/SettingsPage.lua  its card on the BiS List's settings page: the switches, your spec, the fight length
```

## I want to change...

| What | Where |
| --- | --- |
| A spec's default weights | `Data/Defaults.lua` (its role's, then the spec's own) |
| A stat players can weigh | `STATS` and `GAME_KEYS` in `StatWeights.lua`, and its group in `UI/Window.lua` |
| The tooltip line | `Tooltip.lua` |

## Why

- The defaults are for level 60, measured in the spec's anchor at 1: its main stat for a fighter,
  Spell Damage for a caster, Healing for a healer, Stamina for a tank. A percent is worth that many
  anchor points per 1%, and dps a point of a weapon's damage per second (14 attack power's worth).
- `PER_PERCENT` is a rating's points per 1% at 60, as the game's tooltips read them (10 hit rating is
  "1.0%"); the weights are per 1%.
- A weapon's damage per second counts whole in the main hand, half in the off hand, and a hunter's
  ranged weapon's only. `SPEED` (2.6) stands in when the game has no weapon speed to give.
- A druid's Feral tree is weighed for damage; a bear picks Feral Tank by hand. Forever keeps one spec
  per class and its three classic trees as the talent tree's groups, which its own talent frame reads
  the same way (`C_Traits`' group display and currency info); read once, and again after a talent
  change.
- The spec you weigh by: the one picked on the page, else your talents' (Automatic), else your BiS
  list's, else your class's first.
- Your changes are kept only where they differ from the default (closer than `SAME` is the default).
- An item's stats are read once, at most `CACHE_MAX` items; then the cache starts over, so hovering
  everything stays bounded.
- While the game keeps your stats secret, a gain is measured against your stats' worth and weapon
  speeds from just before; they are forgotten when your gear or level changes, so no gain is shown
  from numbers that no longer hold.
- Under `MIN_GAIN` (half a percent) is no upgrade. A ring or trinket is weighed against the weaker of
  the two you wear, a two-hander against both hands. The game files a cloak under cloth; everyone
  wears one, so its subclass is read as 0 for the class rules.
- An item for one hand costs you the two-hander you hold, so it is weighed with a partner for the
  other hand: the best in your bags that your class can use, and for a weapon in the off hand only
  when `CanDualWield`. Both hands' best and next best (for when the item hovered is itself the best)
  are found in one pass over your bags, kept per set of weights, and read again only after
  `BAG_UPDATE`, `BAG_UPDATE_DELAYED`, a gear change, a level or learning to dual wield; your bags
  are never read while you hold no two-hander. The bag events are registered on the first such
  pass. A pass that met an item the game had no data for yet listens for `GET_ITEM_INFO_RECEIVED`
  once, so the pass is made again when it arrives. A partner is always an item you have: two new
  items offered together do not pair with each other, and a second copy of the item hovered is not
  its partner.
- The comparison tooltips beside an item's (what you wear) have no `GetItem` on this client: those go
  by the ID. An item's own link is read where there is one, for its random stats.
- A simulator's export is WoWSims' EP export: `( <tool>: v1: "Name": Class=Rogue, Agility=2.1, ... )`.
  A spell and a melee version of a stat count for the one we have, summed; keys we have no stat for
  are left out, and a hunter's weapon is its ranged one.

- The defaults convert MythicSim's EP (per point, Attack Power, a main stat or Spell Damage at 1) to
  ours: each over the spec's anchor, a rating times its points per 1%. Its pages give the same
  ratings per 1% as `PER_PERCENT` (hit, spell hit, haste and expertise 10; crit and spell crit 14),
  and Healer Stat Weights measured them the same at every level, so they do not scale with level.
- A tank's MythicSim weights are its threat table; the sim does not score survival, so Stamina,
  Armor, Defense, Dodge, Parry and Block keep ours, and the threat stats are scaled to meet them at
  the spec's previous Strength (Agility for the bear).
- Where MythicSim's reference build was at the hit cap (hit measured zero: Enhancement,
  Retribution, Survival, the tanks), the previous hit weight stays, since a player under the cap
  still gains from it. Spell penetration, Mana and Feral Attack Power have no stat here and are
  left out; a negative weight (Fire's spell haste) is 0.
- MythicSim's Weapon damage is a point of damage a swing: a weapon's dps weight is it times
  `SPEED` (2.6), two thirds of it for a rogue's two weapons, since the off hand counts half.
- Healer Mana's Spirit is 0.25 mana a second a point under 50 Spirit and 0.125 from 50, as
  Healer Stat Weights measured on Forever, times the share of it you keep while casting
  (`GetManaRegenFromSpirit`'s second value over its first), times 5 for Mana every 5 sec.
  Its Intellect is 15 mana (`MANA_PER_INTELLECT`) spread over the fight, plus 1% spell crit per
  `Data/IntPerCrit.lua`'s Intellect, between its levels in a straight line. Both read only while
  your stats are not secret; in combat the last reading stands. An Intellect or Spirit you set or
  import yourself is never worked out over.
- A Healer Stat Weights export before 13 Nov 2026 names its crit rating per point (`SpellCritRating`)
  where every other import is per 1%; its `SpellHaste` key, which no simulator uses, tells it apart,
  and its crit is read times 14. Its newer export uses Pawn's `CritRating` and `HasteRating`, per 1%.
- A healer's import reads crit and hit as Spell Crit and Spell Hit, the ones a healer is weighed by
  and Healer Mana prices Intellect's crit with: a Pawn string names them `CritRating` and `HitRating`.
- Upgrade Marks hook the game's own painters once, on first enable: `QuestInfo_ShowRewards`,
  `SetItemButtonQuality` (the quest and loot buttons, again when an item's data arrives late),
  `MerchantFrameItem_UpdateQuality` and `GroupLootFrame_SetupItemDisplay`. The auction house's
  `AuctionHouseTableCellItemDisplayMixin.UpdateDisplay` is hooked when its addon loads: a cell takes
  the mixin when it is made, so one made before the hook (Upgrade Marks turned on with the auction
  house already opened) is marked only after a reload. An auction row has only its item's ID, so a
  random-stat item there is weighed without its suffix.
- An auction row's icon is 14px, too small for the percent: it sits left of the icon in 10pt
  (`ROW_TEXT_SIZE`), where the price column leaves room, with an 8px arrow (`ROW_UP`) and no shade.
  The name starts 4px right of the icon, so nothing fits on that side.

## Checking

- `lua Tools/regression/test-stat-weights.lua`: the defaults (every spec, its anchor, ranges,
  ratings), your changes and new defaults, sharing, the gain math, a pair against a two-hander
  and its one read of your bags, the tooltip line and its
  hook only once on, the window, Healer Mana, a healer's measured export and Mana Upgrades.
