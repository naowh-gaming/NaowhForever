# BiS List

Your best-in-slot picks for every gear slot, ranked: your BiS (an orange star), your second
pick (a silver one), then the rest. Picks come from what most level-60 pre-raid lists agree on for
your spec, then MythicSim's simmed level-60 gear for it (its pre-raid BiS, and its best trinkets in
sim order), then wowsrc.com's ranking for it, then ForeverChanges' picks for it that wowsrc does not
rank, then every other item those pre-raid lists name, from every dungeon drop, every piece of
crafted gear, every class quest reward and every rare or epic world drop your class can use, or from Alt+Shift-clicking any item. The list has its
own window (`/nfbis`, a key binding, or the BiS stat in the Dungeon Journal): your paperdoll
on the left, a card per slot with its picks on the right, where to run next (a waypoint on
whoever has your BiS out in the world) and the best enchant for what you wear; and a Quests
page, the quests that reward a pick you do not have yet, as the Dungeon Journal shows its own;
and Generate BiS List, an Auto list that keeps your best gear for your level as you level.
With Route Page on (off by default), a Route page lists every place your picks come from,
backups included, in the order you put them in.
Listed items say so on their tooltip, and call out when they drop. Lists are shared by every
character of a class, and can be shared as a string. Sim on MythicSim, on the window's title bar,
copies your character for MythicSim's Forever sim (mythicsim.com/wow-forever/sim), so you need no
other addon to sim your gear, bags and talents there.

What drops in a dungeon, and where, is the [Dungeon Journal](../../NaowhForever_DungeonJournal/README.md)'s:
the picker's dungeon drops and an item's boss and dungeon come from its data, so the two always
agree. Without it the list still works, from wowsrc's sources; the picker's dungeon drops, the
Quests page and Run Next's levels and quests say to turn it on instead.

Laid out like the [Dungeon Journal](../../NaowhForever_DungeonJournal/README.md), on
[`Shared/`](../../Shared/README.md).

## Layout

```
BiS/
  BiS.xml             what loads, in order (the addon's BiS.xml includes it)
  BiS.lua             settings, a list's shape, change listeners (ns.BiS)
  Constants.lua       the numbers several files share: the hand slots, a list name's length (B.C)
  Data/               generated, no logic
    BiS.lua           the pre-raid lists' agreed picks and MythicSim's per spec, then wowsrc.com's ranking, ForeverChanges' and the lists' others, its trinkets in sim order, and item sources (Tools/build/bis_data.py)
    Leveling.lua      each spec's gear at levels 30, 40, 50 and 60 for each side, and its sources (Tools/build/leveling_bis.py)
    Crafts.lua        the gear professions craft, its facts and profession, for the picker (Tools/build/bis_crafts.py)
    ClassQuests.lua   the gear class quests reward, its facts, source and quest, for the picker (Tools/build/bis_class_quests.py)
    WorldDrops.lua    the rare and epic gear that drops anywhere in the world, its facts, for the picker (Tools/build/bis_world_drops.py)
    QuestLevels.lua   the level you can first take a quest that rewards a piece of gear, where above its own (Tools/build/bis_quest_levels.py)
    Spots.lua         where the NPC with a BiS stands out in the world (Tools/build/bis_spots.py)
    Enchants.lua      every enchant, what it gives and goes on, the skill it needs (Tools/build/enchants.py)
  Rankings.lua        rankings, a level's picks, dungeon drops, crafts, class quest rewards, world drops, sources, Run Next (B.Rankings)
  Lists.lua           your lists, their old formats, the Auto list's, and the ns calls that change them (B.Lists)
  Gains.lua           what your BiS gets you: Gear Score and stats over what you wear (B.Gains)
  Upgrades.lua        how much stronger each BiS makes you, in percent, by your spec's weights (B.Upgrades)
  Auto.lua            the Auto list: your best gear for your level, refreshed as you level and gear up (B.Auto)
  Enchants.lua        the best enchant for what you wear, for your spec and the item's level (B.Enchants)
  Sharing.lua         export and import strings (ns.ExportBisList, ns.ImportBisList)
  MythicSim.lua       your character as MythicSim's Forever sim reads it (B.MythicSim)
  Marks.lua           your list's rank on item tooltips, and Alt+Shift-click to add or take off an item
  Alerts.lua          Drop Alert: which picks, chat line, sounds, and the loot events while it is on (B.Alerts)
  Quests.lua          the quests that reward your picks, by zone, as the Journal's quests (B.Quests)
  Sources.lua         where a click on an item's source goes: Journal, quest, waypoint, recipe, map, Wowhead (B.Sources)
  View/
    Style.lua         what only the BiS List draws, over Shared/Style.lua (B.Style)
    View.lua          the list page and a slot's picker, on the shared engine (B.View)
    Cells.lua         what the rows share: the gain cell, where an item drops, the hover zones (B.View.Cells)
    Summary.lua       how many are yours, the filter, the bar of your slots, pinned over the list
    EnchantBadge.lua  the enchant dot on a slot's icon and its advice (B.View.EnchantBadge)
    SlotRow.lua       a slot's row: the slot, its BiS, the gain, where it drops, its picks
    PickRow.lua       a pick in the picker, and the hover, clicks and move buttons a backup shares
    BackupRow.lua     a backup pick under its slot's row, joined by a tree line
    PlaceRow.lua      a place to run next, or a step of the Route with its move buttons
    ScoreCard.lua     the Gear Score card under the paperdoll
    Paperdoll.lua     your model in your BiS, turned and zoomed, the slots as the game lays them out
    Toast.lua         Drop Alert's alert on screen, drawn by your settings, live and in its preview (B.Toast)
    RollBadge.lua     your star and rank over the game's roll frame (B.RollBadge)
    Bags.lua          Bag Marks: the slot marks on your bags' items, the game's, EllesmereUI's, or Baganator's
    QuestsPage.lua    the Quests page: the Journal's quest and item rows, on a Journal view
  UI/
    NewList.lua       the New List dialog: name, Only for, a list or Pre-raid BiS to start from (B.OpenNewList)
    Actions.lua       new, rename, delete, import, export, test: the window and page share them (B.Actions)
    Picker.lua        a slot's picker, in a side panel beside the window
    Window.lua        the window (ns.OpenBisWindow, /nfbis, its key binding)
    AlertTest.lua     Play Test: Drop Alert with your first BiS (B.Alerts.Test)
    AlertPreview.lua  Drop Alert's live preview on its settings card (B.AlertStudio)
    SettingsPage.lua  its settings page (BiS List/Settings); Stat Weights, the Character Panel and the
                      Gear Score add their cards
```

Other modules call in through `ns`: `ns.IsBisItem` (the Journal, Bag Space, the loot feed),
`ns.AddBisItem`, `ns.PromoteBisItem`, `ns.RemoveBisItem` (the Journal's item menu),
`ns.ImportBisList` (the profile import), `ns.OpenBisWindow`.

## I want to change...

| What | Where |
| --- | --- |
| A colour, a size, a font size, an icon | `View/Style.lua`, or `Shared/Style.lua` for the house look (the stars) |
| What a class can wear or wield | `Rankings.lua` |
| A spec's ranking | `python Tools/build/bis_data.py` (daily in CI); MythicSim's picks before it and its trinket order, `python Tools/build/mythicsim_bis.py`, ForeverChanges' after it, `python Tools/build/foreverchanges_bis.py`, the pre-raid lists' votes, `python Tools/build/site_bis.py`, then `bis_data.py` |
| A spec's gear at levels 30 to 60 (the Auto list's pool) | `python Tools/build/leveling_bis.py` |
| The crafted gear the picker offers | `python Tools/build/bis_crafts.py`, after the Professions' recipe data changes |
| The class quest rewards the picker offers | `python Tools/build/bis_class_quests.py`, after ForeverChanges' quest list or the Quest List's data changes |
| The world drops the picker offers | `python Tools/build/bis_world_drops.py` (Wowhead's Forever item lists; needs `WOWHEAD_PARTNER_TOKEN`) |
| Where an item drops | A dungeon drop: the Dungeon Journal's data (`Tools/build/journal.py`), which the BiS List reads; anything else: `Tools/data/bis_sources.json`, then rebuild |
| What a list keeps, or an old format | `Lists.lua` (saved lists) and `Sharing.lua` (strings) |
| Which enchant or upgrade wins for a spec | the spec's weights in `StatWeights/Data/Defaults.lua` (players change their own in the module's page); a proc's worth in `PROCS` in `Tools/build/enchants.py` |
| Where a zone's NPC stands | `python Tools/build/bis_spots.py` (on our machines: it reads Wowhead) |
| The quests that reward a BiS | `python Tools/build/foreverchanges_quests.py`, then `python Tools/build/bis_quests.py` (`--offline` without Wowhead; after `bis_data.py` and `leveling_bis.py`, whose picks it reads), then `python Tools/build/quest_chains.py` |

## Why

- A list is `{ id, name, spec, slots = { [slot] = itemID }, extra = { [slot] = { itemID... } },
  route = { placeName... }, bySpec = { [spec] = { slots, extra, route } } }`: `slots[slot]` is a slot's
  BiS, `extra[slot]` its next picks in order, `route` the order of the Route's steps. Each spec keeps
  its own picks and route on a list; switching parks the current ones under `bySpec`.
- Picking a class list keeps the spec tab you are on, even when the list has no picks there:
  the tab is the spec you are editing, and its spec-only lists are offered beside it.
- Lists are kept per class in the account store, so every character of a class shares them and none
  travels in an exported profile; each character remembers which one it uses.
- A list made with "Only for <spec>" ticked is `specOnly`: it keeps one spec's picks (no
  `bySpec`) and is offered only on that spec's tab, under its own heading in the list menu. A spec
  tab opens the spec-only list that character last used there (`bisSpecActive`), until it picks a
  class list on that tab; leaving a spec-only list for another spec goes back to the class list it
  last used (`bisClassActive`). A spec the class no longer has turns its spec-only lists back into
  class lists, so none is ever hidden on every tab, and a class list is always there to fall back
  on.
- New List can start from any of the class's lists. A class list keeps picks per spec, so its spec
  is picked too: the tab's spec when it has picks there, else the first that has. Each slot the
  source has picked is copied unless untoggled, its BiS and backups in order, as tables of the new
  list's own. The new list is made on the tab on show, ticked or not.
- New List can also start from Pre-raid BiS: for the spec picked, each slot's pick the level-60 pre-raid
  lists agree on and its next two as backups (`preRaid` in `Data/BiS.lua`, `R.PreRaid`), leaving out
  what the client does not know, the other side's quest rewards and a second of the ring or trinket
  already picked. Naowh Picks sits under it, greyed, until Naowh's own lists ship.
- Older saved lists are moved when read: a character's own list from before lists were shared joins
  its class's (named for the character unless it had a name), a flat item list is put in slots, and
  the unordered next picks of the 0.5.12 test builds go in ranked order.
- A level's picks are your side's (`UnitFactionGroup`), as many are quest rewards of one side.
- Generate BiS List, beside the window's tabs, makes a spec-only list marked `auto` ("Auto <Spec>"),
  uses it and shows Your List. While it is the list you use, it is refilled when you level or change gear: each slot
  gets the items worth most to your spec's weights, best first (`PICKS`, 3), from what you wear, the
  spec's ranking, its leveling lists and the Journal's drops near your level, that your class can
  use and that need no more than Levels Ahead (`bisAutoAhead`, default 5) levels over yours. What
  you wear competes, so the list never asks you to wear worse. Trinkets go by MythicSim's sim order where it ranks them
  (the spec's `trinkets`), and those it does not after them by weights: weights give an on-use or
  proc trinket next to nothing. MythicSim sims no healer, so a healer's trinkets go by weights.
- An item's level (`R.ReqLevel`) is the level you can first take a quest that rewards it when that is
  higher than its own: many classic quest rewards need no level (Thrash Blade, from a level 45
  Maraudon quest), so the Auto list picked them for low-level characters.
- A slot's picker shows the ranking in two parts: what needs no more than Levels Ahead
  (`bisAutoAhead`, the Auto list's setting) levels over yours, then For later levels, each item
  keeping its rank. At the top level the second part is empty and the ranking reads as one list.
- MythicSim's picks lead each slot's ranking because wowsrc's rankings stop below level 40. Its
  raid trinkets stay out until the raids open (`RAIDS_OPEN` in `Tools/build/mythicsim_bis.py`).
- Ahead of MythicSim's pick goes one that at least `VOTES` (2) of it and five level-60 pre-raid
  lists pick first for the slot (`Tools/build/bis_data.py`), most votes first; a ring or trinket is
  a vote for both slots of its pair. MythicSim sims no healer, so a healer's slots are led by the
  lists' picks with one vote too. A one-faction item (PvP gear) can lead when the lists agree on it.
- A slot you change on the Auto list (add, remove, move) is kept in `kept` and never refilled;
  Generate BiS List again lets every slot go back to the Auto picks. To mix more freely, New List can
  start from the Auto list.
- The Auto list is shared by every character of a class, as every list is, and is refilled for
  the character using it. Its refill waits `REFRESH_DELAY` (0.5 s) so a gear swap's burst of
  events, and the level that `UnitLevel` returns late on `PLAYER_LEVEL_UP`, give one refill.
- The Auto list scores its pool once per spec, weights and top level, and again when an awaited
  item arrives. A gear change only ranks what you wear against those scores: scoring the whole pool
  on every swap made weapon-swap macros stutter.
- An item the client has not loaded, worn or not, is asked for, and the list is built again when it
  arrives. Only the items it waits for wake it, and only when the server sends
  them, so an item the server refuses never wakes it again. Level and gear changes are listened to only
  while the module is on and an Auto list is the one in use; switching to another spec's Auto list
  refills it for you.
- The pool's items are scored by their base stats, as the upgrade percent is: a random suffix ("of the
  Bear") is only known once you have the item, and what you wear is read by its link.
- A one-hander's worth in the main hand counts the best off hand beside it, so a two-hander wins
  only when it beats the pair. Ring 2 and Trinket 2 skip what Ring 1 and Trinket 1 took.
- When a two-hander is the main hand's top pick, the Auto list leaves the off hand empty.
- An item of a level's list that neither the Journal nor wowsrc and ForeverChanges place takes the
  leveling data's source, so its row still says where it comes from.
- A list's name shows in chat and tooltips, so its escape codes are neutralised (`|` doubled) and it
  is cut to `NAME_MAX` letters.
- A two-hander as the main hand's BiS leaves the off hand unused: its picks are kept, not counted,
  until the main hand's BiS is a one-hander again.
- Share strings are parsed as data, never run. Version 1 is a flat item list, placed as an old saved
  list is; 2 has BiS picks only; 3 has next picks unordered, put in the spec's ranked order; 4 has
  next picks in order. A spec-only list adds `only`, which older versions skip and add as a class
  list.
- What drops in a dungeon, and the boss and dungeon an item comes from, are the Dungeon Journal's,
  so the two list the same items under the same bosses. The Journal loads after the BiS List, so
  `Rankings.lua`, `Quests.lua` and `Sources.lua` read it the first time they are asked, never at load.
- A boss's drop beats a trash drop of the same item (trash counts as a chance of -1), and the boss
  likeliest to drop it is the one named.
- An item its source calls a World drop stays one when its likeliest place in the Journal is a boss
  with no chance: its click goes to Wowhead and the picker leaves it out of the dungeon drops. wowsrc
  lists some world-drop greens under bosses with no chance (Nightsky Wristbands on Grubbis), and
  naming the boss sent players to farm it there. A trash card still names its dungeon: Spirewind
  Fetter is Uldaman's trash.
- `SOURCE_SEP` is the middle dot wowsrc puts between a boss and its place; each source is split once.
- A Journal drop's place is its dungeon's English name, as the list's own sources name it, so both
  are one place in any language. `R.PlaceName` shows a place in the player's language through the
  Journal's `J.PlaceName` (a dungeon by its name there, any other place by the game's), so without
  the Journal places stay English.
- The picker lists only ranked items the running client knows: an unknown ID never finishes loading.
  Dungeon drops "near your level" are within `NEAR_LEVELS` (10) of yours.
- Run Next shows at most three places, the ones that make you strongest first (by the gains), then
  the one with the most of your BiS. A quest, a craft or a faction's reward is not a place but a
  click goes there all the same; a world drop is nowhere to go.
- The Route is a step per place, the same places as Run Next but with every pick, not only the BiS:
  a stopgap is usually a backup. A slot's picks stop at the first one you have, since the ones under
  it are done with. Steps you have not ordered go after the ones you have, lowest required level
  first, which is the order most players level through them.
- Moving a step saves the whole order shown, and keeps the places not shown (done, or no pick there
  now) after them, so a step you finish or take off keeps its place if it comes back.
- The route travels in the version 4 string as an extra field: older versions import the list and
  ignore it.
- A quest for your own side says only "Quest": the list gives you no quest of the other's.
- The quests are the Journal's records (its `Data/BiSQuests.lua`), so its rules (what to do first,
  the level, the chain, the waypoint, tracking) work on them. A quest's race limit is kept aside, as
  the Journal's rules know none; a race the mask does not know of is let through. `RACE_BITS` is your
  race's bit in a quest's races mask (`ChrRaces.PlayableRaceBit`): the classic eight, and Forever's
  Skyborne.
- The Quests page has the quests that reward a pick of a spec's ranking or of its level-60 leveling
  gear: the rankings stop below level 40, so a list with that gear on it brings the endgame's quests. The level-30 to 50 lists are not read: their quest rewards show where a ranking has them.
- A quest starts where ForeverChanges maps its quest giver, else Wowhead, else the map of the
  Journal's quest giver, else the dungeon it starts inside.
- Enchants: the game puts no level limit on any; the level is advice. `SKILL_LEVELS` follows the
  trainers, who teach up to 75 at level 5, 150 at 10, 225 at 20 and 300 at 35; Forever's recipes past
  300 come from its endgame (`ENDGAME_LEVEL`). Of two as good, the cheaper recipe wins. A special
  enchant (a proc no stat can say) shows when the spec values its stat at `SPECIAL_WORTH` or more.
  Weapon damage per swing is worth the weapon's damage per second over its speed.
- An item's stats are fixed, so each is read once (through Stat Weights' bounded cache); what you
  wear is read by its link, as a suffix ("of the Monkey") changes its stats.
- The upgrade percent is an estimate, as the weights are: it orders upgrades, it does not promise a
  number on a meter.
- Drop Alert speaks once per drop: a roll by its ID, a loot window's item by the corpse and the item,
  and an item said in the last `SAME_DROP` seconds (a boss's roll, then its loot window) not again.
  What was said is let go after `FORGET` seconds. Looted, won or handed to you is "yours", but not a
  second copy of what you wear. The loot events are listened to only while the module and Drop Alert
  are on, on a frame made the first time.
- The roll badge is ours, anchored to the game's roll frame and never kept on it; Forever's roll
  frames are unverified, so a missing one just goes without.
- The toast's star is on a frame of its own above the icon (`STAR_LIFT` levels, over the icon's
  corner badge too): the icon is a frame, so a texture on the alert would sit under it. Live toasts
  stack under a holder you move in Unlock Mode; nothing is made before the first.
- Bag Marks: ours is a frame over each bag button, kept in our own table (nothing stored on theirs),
  painted after the bag paints the slot. Off, nothing is hooked or made; turned off after being on,
  ours hide and EllesmereUI's overlay hook is let go. Baganator gets the same marks through the
  corner widget its API offers other addons, registered once the first time Bag Marks is on, because
  that registration cannot be taken back. Our marks sit on the frame it places in a corner, sized to
  the whole button, and that frame stays shown while the slot has an item: Baganator hides it and
  skips the callback when the slot is empty, and our marks go with it. Closing the bags hides them
  without changing that frame's shown state, so they come back when the bags reopen, which repaints
  only the slots that changed. The callback answers false, so Baganator's own item level can sit beside ours.
  While Bag Marks is off the callback hides them and answers nothing. Your weights and what your
  gear is worth are read once a frame: a
  bag paints every slot in one go, EllesmereUI and Baganator one slot per call. On EllesmereUI's
  buttons its BoE word puts our star after it, Pawn's arrow our item level before it, and its own
  item level hides while ours stands in for it. A level shows
  on gear only, in its quality's colour (gold for common and poor) so it never reads as a stack count.
- An item's card comes up over its icon and name only, so it never covers the list while the mouse
  crosses a row; the zone takes the mouse over it, not its clicks (`SetMouseClickEnabled(false)`
  after `SetScript`, as setting mouse scripts turns clicks back on).
- A row's gain bar is its share of the list's biggest gain by the square root, so +1% still shows
  beside +18%. A gain of `GAIN_BIG` and up is the upgrade green, under `GAIN_SMALL` muted.
- The backup tree's branch sits `TREE_DROP` under the row's middle, level with the rank's letters:
  the Naowh font leaves room above its capitals, so a line on the middle reads a pixel high
  (unmeasured; check in game).
- The summary is not a row of the list: the window pins it over it, so it stays in sight however far
  the list scrolls.
- The paperdoll leaves the ranged slot off the model, as trying it on takes a hand. A new model frame
  starts shown, so its OnShow covers only later shows and the first dress is made at once.
- Handing the screen to the Dungeon Journal or the world map (Run Next, a source) puts the window
  away; it comes back when that one closes, unless it was opened again meanwhile.
- The Quests page is a Journal view, made the first time the page opens, as the Journal loads after
  the BiS List.
- Sim on MythicSim writes the character JSON MythicSim's Forever sim reads: the WoWSims exporter's
  fields (name, realm, race, class, level, talents, professions, gear), its `mythicsim` object (the
  client, faction and race ID, the talents' spells, the character sheet, the spells you know) and
  `bags`, the equippable items you carry, for its Best Gear. Gear goes in `SLOTS`' order, which its
  site reads rings and trinkets in. `Undead` is the game's `Scourge`, and a profession its English
  name by skill line.
- The talents are one digit per talent, a tab's rows top to bottom, each left to right, tabs joined
  by `-`: the sim reads them by position. A talent's tab is its group among the tree's display
  groups (Stat Weights reads the same ones); its row and column are its place over `SQUARE`, counted
  from the tree's top row and the tab's first column. A node off the grid (past `MAX_ROW` or
  `MAX_COL`: Hunter's old Lightning Reflexes, Priest's Holy Specialization) is left out, since one
  digit too many moves every talent after it; where two share a square, the newer node is the live
  one. Each talent's spell and rank go along in `talentSpells`, for the site to match by spell when
  its trees and the game's drift apart. Checked against the 1.60.1.70938 client's tables: every
  class's order matches MythicSim's own exporter.
- The export waits out combat: the game hides your stats and auras then
  (`C_Secrets.ShouldUnitStatsBeSecret`, `ShouldAurasBeSecret`). Forever has no weapon skills, so the
  sheet has none.

## Checking

- `lua Tools/regression/test-bis-slots.lua`: lists, picks, old formats, sharing, Run Next, the Route.
- `lua Tools/regression/test-bis-dungeon-drops.lua`: class rules, dungeon drops, sources.
- `lua Tools/regression/test-bis-window.lua`: the window, paperdoll and picker, a click
  changing the list, Generate BiS List, the redraw's cost (no garbage), Drop Alert only listening while on and as
  you set it (which picks, alert, chat, sounds, its look, and the settings page's studio and
  rows), Run Next's waypoints, and enchants by spec and item level.
- `lua Tools/regression/test-bis-mythicsim.lua`: the MythicSim export: its JSON, gear, bags, talents
  in the sim's order (off-grid and replaced nodes left out), professions, and waiting out combat.
- `lua Tools/regression/test-bag-marks.lua`: Bag Marks in the game's bags, EllesmereUI's, and Baganator's.
- `lua Tools/regression/test-dungeon-journal.lua`: also the Quests page, the quests that
  reward your picks, by zone, for your side, class and race.
