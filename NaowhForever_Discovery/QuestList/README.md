# Quest List

Discovery's Quest List and Rares tabs (Completo in the code: `ns.Completo`, `/nfcompleto`, the
`completo` settings store), everything there is to do and how much of it you have done. They
share Discovery's switch: the Quest List follows Discovery's `enabled`, and an old profile with
Completo on turns Discovery on. Both are tabs of the Discovery window, next to Library Books and Sleeping Bag.
The Quest List tab has every quest of every zone for your character, how many you have done per zone, and for each quest chain the step
you are on; its Rares tab every rare of every zone and which of them this character has killed.
Map Pins put a ! on the world map at each quest giver with a quest for you, a mark where each
unfinished objective of a quest in your log is and a ? where a done one is handed in, and a star where each
rare spawns; Rare Alerts warn you when a rare is near, and a left-click on the alert targets it. Off by default, every feature too: players
turn it on in Discovery's settings pages (Discovery/Quest List and Discovery/Rares).

## Layout

```
NaowhForever_Discovery/QuestList/
  QuestList.xml               every file, in load order, included by Discovery.xml
  Completo.lua                its settings (ns.CompletoSettings), the module table (ns.Completo), its
                              switch following Discovery's, and turning off an old Completo folder
  Constants.lua               the numbers several files share: a rare drop's fields, the sample rare
  Data/
    AlertSounds.lua           the game's sounds Rare Alerts offers
  Holidays.lua                which of the game's holidays are on now, from its calendar (Completo.Holidays)
  Quests.lua                  the quest rules: yours, done, chains, givers, search (Completo.Quests)
  Givers.lua                  learns which quests a quest giver really offers you
  History.lua                 Quest History: the quests you take, hand in and drop, and your levels (Completo.History)
  Objectives.lua              where the quests in your log send you: objectives and hand-ins (Completo.Objectives)
  Party.lua                   Share Quest Progress: your party's quest objectives, by addon message (Completo.Party)
  Rares.lua                   the rare rules: yours, zones, spots, drops, your kills (Completo.Rares)
  Kills.lua                   counts the rares you kill and what they drop for you
  Find.lua                    the quests, rares, and quest creatures and objects QoL's Find window searches
                              (ns.FindQuestsAndRares)
  Sounds.lua                  plays the alert's sound and lists the choices (Completo.Sounds)
  KeyBinding.lua              binds Shift-L once per character, if it is free
  View/
    Style.lua                 Completo's own look, on top of Shared/Style.lua
    View.lua                  the window's row kinds and what its rows share (Completo.View)
    Hero.lua                  the card on top of a page: done of total, count and bar
    ZoneRow.lua               a zone on All Zones, and the progress row it shares (View.ProgressRow)
    QuestRow.lua              a quest, and a chain's tree line
    RareRow.lua               a rare
    DropRow.lua               a rare's drop, under it while open
    HistoryRow.lua            a line of Quest History
    AlertCard.lua             the Rare Alert's card, live or in its preview (Completo.AlertCard)
  UI/
    RareAlert.lua             the alert on screen: seeing a rare, the card, its place, its click that
                              targets the rare (Completo.RareAlert)
    Window.lua                the Quest List and Rares tabs of the Discovery window (Completo.Tabs), and the key binding's toggle
    QuestPins.lua, .xml       the quest giver pins on the world map, and their template
    ObjectivePins.lua, .xml   the objective and hand-in pins on the world map, and their template
    MinimapPins.lua           the same quest givers and objectives on the minimap, near you
    UnitTips.lua              Quest Tooltips: a creature's, object's or item's quests and your progress on its tooltip
    NameplateIcons.lua        Quest Nameplates: a quest icon over the nameplate of a creature your quests still need
    RarePins.lua, .xml        the rare stars on the world map, and their template
    GeneralSettings.lua       the key binding card, on the Discovery/Quest List page
    QuestsSettings.lua        the quest cards on the Discovery/Quest List page, and the quest pins on QoL > Map & Pins
    RaresSettings.lua         the Discovery/Rares settings page, with the alert's live preview, and the rare pins on QoL > Map & Pins
```

Each layer only uses the ones above it: `Data` fills the rules, `View` draws what they decide,
and `UI` places it on screen. Everything the module shares hangs off `ns.Completo`; only what
the rest of the addon calls is on `ns` (`CompletoSettings`, `OpenCompletoWindow`,
`ToggleCompletoWindow`, `FindQuestsAndRares` for QoL's Find window, and the binding's
`NaowhForever_ToggleCompleto`).

## The data

`NaowhForever_DiscoveryData/Quests.lua` and `NaowhForever_DiscoveryData/Rares.lua` are generated by
`Tools/build/completo_quests.py` and `Tools/build/completo_rares.py` from Wowhead's Forever zone,
quest and creature pages. Do not edit them by hand: change the tool and run it again
(`--offline` rebuilds from the caches in `Tools/data/`).

- `D.Zones`: each zone's uiMapID, name, continent (0 Eastern Kingdoms, 1 Kalimdor) and its quests
  or rares.
- `D.Quests[questID]`: name, level, required level, side (1 Alliance, 2 Horde, 3 both), race mask,
  class mask, start uiMapID, x, y (percent), quest giver, item. A quest an item begins has the mob
  that drops it as its giver, and the item. Spots on the maps Forever redrew are moved from
  Wowhead's classic ones onto Forever's. Each source misses the class of some class quests (Call of
  Earth on Zephras Isle, the rogues' dead drops), so the class mask is narrowed by every class named
  for the quest: the catalog's, and the class whose quest sort ForeverChanges files it under. The race
  mask is narrowed the same way by the catalog's (Alterac Valley's Frostwolf and Stormpike quests).
  `completo_fixes.json`'s `races` sets the side or races every source gets wrong. ForeverChanges' giver
  is not taken for a quest whose side Wowhead and the catalog agree on against it: its record is the
  other side's version (A Lesson to Learn, 26 and 27).
- Which quests there are, and where their givers stand, follow ForeverChanges' quest list and
  pages (`Tools/build/foreverchanges_quests.py`): a quest it does not list is left out, unless
  `completo_fixes.json`'s `unlisted` names it (one new in the game that the site has not listed
  yet), one only it lists is added (Unsorted Quests when it names no zone or giver), a quest goes
  in the zone it files it under, and its giver's spot, on Forever's own map, comes before Wowhead's. A quest with several givers is pinned at the one in its zone.
  ForeverChanges has no Ironforge map, so a giver it puts on Dun Morogh's inside the city's
  rectangle is on Ironforge's too (`listed_maps`). That rectangle takes in the city's gates, which
  are Dun Morogh's, so the quest's zone picks: a Dun Morogh quest keeps Dun Morogh's map.
  On the maps Forever redrew (Stormwind, Mulgore, Redridge, the Eastern Plaguelands) many of
  its spots are Classic's positions unconverted (Bolvar Fordragon at 78, 18), so a giver there
  is never taken from it: those quests keep Wowhead's spot. Wowhead has moved some NPCs there to
  Forever's map and not others (Anthion Harmon and Mulgore's new givers are Forever's, Tirion Fordring
  and Nathanos Blightcaller still Classic's), so its spot is moved onto Forever's map only for a giver
  the catalog does not place: one the catalog has on Forever's map there (its start for this quest or
  another) stands where the catalog says. Journeys' turn-ins and camps go by the same rule.
- Forever replaced the classic Tier 0.5 class quests (An Earnest Proposition, Just Compensation, Anthion's
  Parting Words and Saving the Best for Last, 8905 to 9022) with its own (84147 to 84210, 97411 to 97414 for
  the Horde paladin, 97447 to 97450 for the Alliance shaman), which share each classic version's completion
  bit. ForeverChanges still lists the classic ones and not Forever's, so `completo_fixes.json` names
  Forever's (`unlisted`) and the classic ones (`replaced`): the classic quests are left out, and Forever's
  take their place in the chain. Wowhead gives most of Forever's no class, so `classes` sets each from its
  reward, the class's Dungeon Set 2 piece or spec set box. Three have no giver on Wowhead, and it places
  Anthion Harmon on Forever's Eastern Plaguelands already, so `givers` puts those at another version's giver.
- The game's data keeps some of Season of Discovery's quests, which Forever does not give, and ForeverChanges
  lists a few: its versions of classic quests of the same name (Jarl Needs a Blade, 81570, beside the classic
  1203 that "Swamp Eye" Jarl offers) and the Nightmare Incursion Mission dailies. `completo_fixes.json`'s
  `ungiven` names them, and they are left out of the Quest List, its objective pins, Journeys' quest spots and
  the BiS List's quests.
- Holiday quests are in, and taken only while their holiday is on: `D.Events[questID]` lists the holidays that
  give one (the game's Holidays IDs on Forever, from wago.tools), `D.Holidays` names them, and
  `D.FaireSpots[questID]` says where a Darkmoon Faire quest's giver stands for each Faire (Elwynn Forest's, 263,
  and Mulgore's, 264, from their descriptions in the game's HolidayDescriptions). The event quests are the ones
  ForeverChanges files under Seasonal, Lunar Festival, Midsummer, Darkmoon Faire or Ahn'Qiraj War
  (`EVENT_SORTS` in `Tools/build/completo_quests.py`), and the ones `completo_fixes.json`'s `events` names; each
  quest's holiday comes from its Wowhead category (`HOLIDAY_CATEGORIES`, its page's breadcrumb, cached in
  `Tools/data/event_quests.json`), or the `holidays` of the fixes group naming it. The Ahn'Qiraj War Effort, the
  Scourge Invasion and the New Year have no holiday on Forever's calendar, so their quests are still left out:
  their ! would show all year. A giver Wowhead places and ForeverChanges does not (the Lunar Festival's Elders)
  takes Wowhead's spot.
- `D.Objectives[questID]`: one entry per objective with spots, `{ place, item (1 or 0), source, ... }`, each
  source `{ kind (1 creature, 2 object), name, uiMapID, x, y, ... }`, its spawns grouped into camps. From
  `Tools/build/quest_objectives.py`: each Wowhead quest page's map names, for every point, the objective it is
  for. `D.HandIns[questID]`: `{ name, uiMapID, x, y }`, who takes it back. `D.Creatures[npcID]`,
  `D.Objects[objectID]` and `D.Items[itemID]`: `{ questID, place, item, ... }`, the objectives each creature, object
  and item is for, for Quest Tooltips. An item's ID comes from the catalog's item list, since Wowhead's points name
  the item but give no ID; a kill or use objective takes its place by the creature's or object's ID.
  `D.Paths[questID]`: `{ place, item, name, uiMapID, x, y, ... }`, the way a creature for that objective walks, as
  dots in walking order: from QuestieDB (which gave us permission), since Wowhead keeps only where a creature was
  seen. Its Forever data is in Forever's map coordinates already, cached in `Tools/data/quest_creature_paths.json`. The same pages give Journeys its quest
  spots (`NaowhForever_JourneysData`), but those keep no objective, so this has its own cache.
- `D.Gains[questID]`: `{ xp, money, factionID, amount, ... }`, what a quest gives (experience at its own level,
  copper, then each reputation), and `D.Instances[questID]`: the area ID of the instance a dungeon, raid or
  battleground quest is for, named in the client with `C_Map.GetAreaInfo`. In `Gains.lua`, from
  `Tools/build/quest_gains.py`: Wowhead Forever's quest rows, cached in `Tools/data/quest_gains.json`.
- `D.Repeatable[questID] = true`: quests you can do again and again (Wowhead's repeatable flag).
- `D.Dungeon[questID] = true`: dungeon, raid and battleground quests, listed in the zone their quest
  giver stands in. Wowhead files them under the instance, so no zone page has them: they come from
  `Tools/build/dungeon_quests.py` (the Dungeon Journal's list and spots, CMaNGOS's levels, races,
  classes and prerequisites, wowsrc.com's levels for Forever's new ones), and the ones the Journal
  lacks from `Tools/build/elsewhere_quests.py`. They get pins and rows like any other, but a zone's
  progress leaves them out, as it does the repeatable ones.
- `D.Battleground[questID] = true`: the battleground quests among `D.Dungeon` (Alterac Valley, Warsong
  Gulch, Arathi Basin), by the area CMaNGOS files each under (`BATTLEGROUNDS` in
  `Tools/build/elsewhere_quests.py`).
- `D.Elsewhere[questID] = true`: class, reputation and epic quests, which Wowhead files under their
  category, from `Tools/build/elsewhere_quests.py`: CMaNGOS's quests that Forever's client has
  (wago.tools' QuestV2), at the spot Wowhead gives their giver for another quest. A giver with no
  such spot leaves its quests out, and holiday, event and profession quests are left out. A zone's
  progress leaves them out too.
- `D.Requires[questID]`: what must be done before it opens, every element of the list. An element is a
  quest, or a list of alternatives one of which will do: quests of one name (each class's or faction's
  version) and the quests the zones lack, which cannot be told apart. From Forever's Series box,
  Wowhead Classic's Requires box, and for a quest with no Requires box the catalog's prerequisites
  (`quest_entity_catalog.json`'s preQuestGroup, all needed, and preQuestSingle, one of them).
  `Tools/data/completo_fixes.json` adds what those leave out (Toxic Soil, a Storyline and no Series)
  and drops what they get wrong, each fix with what shows it. A fix naming a quest the data lacks is
  skipped with a warning, so the build still runs.
- `D.Chains`: each chain's steps in order. A step with more than one quest has parallel quests,
  all of which finish it, or with `any = true` the faction or class versions of one quest.
- `D.Exclusive`: groups of quests of which you take one. The versions of one quest the game counts as
  one: quests of one name that share a completion bit (QuestV2's `UniqueBitFlag`, cached in
  `Tools/data/quest_bits.json`), such as Divine Grace from each priest trainer or each level bracket's
  Battle of Warsong Gulch. A bit's quests of different names are not grouped (The Last Element shares
  one with the orcs' first quest). Then the camping quests of one name (each starting
  area's The Great Outdoors, The Adventurer and Camping 101 for each profession; ForeverChanges files
  them under the game's Camping quest sort, 666), and the pairs in `completo_fixes.json`. A quest is in
  one group at most: the build skips, with a warning, a hand-kept group naming a quest already in one.
- `D.Breadcrumb[questID]`: the quest a breadcrumb sends you to (it ends at that quest's giver), from
  `completo_fixes.json` and the catalog's breadcrumbForQuestId.
- `D.Profession[questID]`: the skill line (SkillLine) a quest needs, and `D.Recipe[questID]` the camp
  recipe a Camping 101 quest teaches, from `completo_fixes.json`, then the catalog's requiredSkill;
  `D.SkillRank[questID]` the rank it needs where that is more than 1.
- `D.MinReputation[questID]` and `D.MaxReputation[questID]`: `{ factionID, standing }`, the standing a
  quest needs at least, or is given only below (Neutral 0, Friendly 3000, as `currentStanding` counts).
  `D.MaxLevel[questID]`: the level it is given up to (each battleground bracket's quests).
- `D.ClosedBy[questID]`: the quests that close it once done or in your log, less any it needs: the
  catalog's exclusiveTo, and for a breadcrumb each quest whose disabledByQuest names it (each names a
  breadcrumb to its own giver, as Report to Sen'jin Village leads to Master Gadrin's quests).
  `D.Until[questID]`: the quest it is given until that is done (the Saptas, until Call of Earth).
- `D.Rares[npcID]`: name, lowest and highest level (0 when not known, -1 for a boss level, "??"),
  elite (1 for a rare elite), how it meets the Alliance and the Horde (-1 hostile, 0 neutral,
  1 friendly), uiMapID, `{ x, y, ... }` where it spawns (percent, on Forever's map), and for one
  that patrols `{ x, y, ... }` dots along its way.
- `D.Loot[npcID]`: its special drops (rare and epic items, recipes, what is new in Forever), its
  own first, then the best and likeliest, each `{ itemID, quality, chance (percent), name, 1 when
  new in Forever }`; `more` is how many more there are. A rare with none has no entry.

## Why

- The zone you stand in and the quest givers and rares on a map are read through `Places.SameMap`,
  so Zephras Isle's second map (2665) finds 2521's quests and rares (Shared/README.md, Why).
- Nothing runs until one of its tabs is open: it reads what you have done when it draws, and listens
  for quest events only while it is shown. Which quests are yours (faction, race, class) is worked
  out once, the first time it is asked, and again only when a giver offers you one the data says is
  not yours.
- What you have done, your log, skills, recipes, reputations and holidays are read again (`Quests.Refresh`)
  only when one of them changes (`Quests.Stale`, from a quest accepted, turned in or removed, a level, a
  skill or recipe learned, a reputation or the calendar) or a minute has passed (`Quests.Update`). The
  full read takes tens of milliseconds, and the map's pins, the minimap's, every giver you speak to and
  each search asked for it, so opening the map or changing zone stuttered.
- The quests and rares (close to two megabytes once loaded) ship in `NaowhForever_DiscoveryData`, a
  load-on-demand addon. `ns.CompletoQuestData` and `ns.CompletoRareData` start empty with a hook
  that loads it on the first read of any field, so the files here keep the tables they took as they
  loaded, and a player with the Quest List off never loads them. If it does not load (turned off
  in the AddOns list, or missing), both tables are left with empty lists, so the Quest List shows
  nothing instead of erroring, and the load is not tried again.
- `RACE_BITS` maps the client's race IDs to their bit in Wowhead's race masks, Forever's own two
  races (95 and 96) too.
- A quest for both sides whose race mask names only the High Order Skyborne is both Skyborne's: Wowhead
  and ForeverChanges both call those both sides' (`races` in `Tools/build/completo_quests.py`). Other
  masks are only narrowed, never widened, from the sources, even where they look like slips: 64
  Forever-new Alliance quests leave Humans out (Goldshire's Delicate Instruments and Northshire's
  Rascally Rodents among them), and some Zephras Isle quests name Tauren but not the Windshaper Skyborne.
  Wowhead's pages show the same, so they wait for a check in game; a giver's offer makes such a quest
  yours meanwhile. One seen in game goes in `completo_fixes.json`'s `races`: EG Link's turn-ins show
  Windshaper Skyborne druids doing the Tauren's A Lesson to Learn and Lessons Anew chains.
- A quest the data says is not yours (its race or class) that a giver offers you is yours from then on
  (`completoMine`, per character), so a mask the data still has wrong corrects itself the first time
  you speak to the giver.
- A chain keeps only the steps you can do; one left with a single step is no chain for you.
- `MAX_UNDER` is 10: Wowhead's required level is wrong for some quests (Mending Old Wounds says
  level 15 for a level 60 quest, and the game does not offer it at 15), so no quest is taken as
  needing less than its own level less 10.
- A repeatable quest is never done for good, so zone counts leave it out.
- A quest you can no longer take is "Not offered any more": one of its exclusive group, its breadcrumb's
  target (or one of the target's group), a quest that needs it or one of its `D.ClosedBy` is done or in
  your log, its `D.Until` is done, you know the camp recipe it teaches, or you are past its level or the
  standing it is given below. One needing a profession you lack, or more of it, is "Needs a profession";
  a quest that introduces a profession (My First Alchemy Set and My First Real Potion) needs none, as it
  is for players who lack it, while The Quarry's Smith and This Is Spinal Axe need Blacksmithing, as the
  catalog has them. One needing more standing with a faction than you have is "Needs reputation". None of
  them gets a ! or counts toward its zone unless it is done or in your log, so a zone can reach all of
  its quests and its count matches its rows. Such
  a quest its giver does offer is open for good (`completoReopened`, per character). That is apart from
  `completoOpened`, which a quest offered past a requirement gets, so such a quest still closes once it
  can no longer be taken. A side quest the data lists as needed by a later one closes with that later one
  too, so `completo_fixes.json` drops such requirements.
- Your professions and their ranks (`GetProfessions`), the camp recipes you know
  (`C_SpellBook.IsSpellKnown`), your standing with each faction a quest names
  (`C_Reputation.GetFactionDataByID`; one it gives nothing for holds nothing back), the quests in your
  log, `completoOpened` and `completoReopened` are read on each refresh with what you have done, not on
  each check: a zone count checks every quest of every zone. The window and the map's
  quest pins also redraw on `SKILL_LINES_CHANGED` and `LEARNED_SPELL_IN_SKILL_LINE` while shown.
  Camping 101: Cooking teaches cooking, so it needs no profession and teaches no recipe.
- A quest with an unmet requirement is "Needs an earlier quest", with no ! on the map, and its row
  says "Requires: <quest>" (up to three, all of them in its tooltip). The data cannot know every
  prerequisite (a Forever-only quest's quests where the catalog names none). A quest it says you could
  take, but whose giver does not offer it, is held back ("Not offered yet", no !) until you level up or
  hand in a quest in its zone; one its giver has not offered at two levels (`MISSES_HELD`) stays held
  until the giver offers it, so a ! the data has wrong does not come back with each level. It is kept
  per character (name-realm) in the account settings,
  `completoNotOffered` and `completoTurnIns`. A quest held back as "Needs an earlier quest" that its
  giver does offer is taken as open for good (`completoOpened`), so a requirement the data has wrong
  corrects itself the first time you speak to the giver.
- The giver's list is read from the gossip window, the quest greeting (the quest ID is
  `GetAvailableQuestInfo`'s fifth answer where the client gives it, else the quest is found by its
  title), or the one quest an NPC with nothing else opens straight away. That last is skipped when
  it comes from a list just seen, a player sharing it, or an item.
- Givers leave grey quests out of their list unless low level quests are tracked on the minimap,
  so a grey quest missing then is not held back.
- A quest is low level by the game's own colour for its level; without it, by classic's rule:
  more than the green range (8 when the client has no `GetQuestGreenRange`) under your level.
- Map pins override `CheckMouseButtonPassthrough` with nothing: the map calls it on every pin, and
  its `SetPassThroughButtons` is protected, so calling it from our refresh is blocked in combat.
  Our pins want their clicks, so there is nothing to pass through.
- The pin mixins are globals so the XML templates can name them.
- Quest and rare pins scale with `ns.Shared.ScalePin`, so they keep one size on screen however far
  the map is zoomed, in the small map's window and on the full screen map alike. Quest pins take
  `QUEST_PIN_SCALE` (0.5) of it and rares `RARE_PIN_SCALE` (0.75), so at 20, the default every map pin
  shares (`PIN_SIZE_DEFAULT`), each is the size that reads best: the same number sizes every kind of pin alike.
- Their switches, Pin Sizes and options are rows on the Map Pins card of QoL's Map & Pins tab
  (`ns.Shared.MapPins`), with every other map pin; the keys stay in Completo's store.
- Quest pins redraw on a quest taken, handed in or dropped, and on a level up (which turns some
  grey and lets others be picked up). A giver whose quests are all repeatable gets the game's blue
  mark, grey or not: a repeatable quest is done for its reward, not its experience; where an atlas
  is missing, the gossip window's ! is tinted instead. A giver with a dungeon
  or raid quest gets a green ! (`DUNGEON_RGB`), as the tracker's dungeon quests stand out from the
  zone's: no green quest atlas is known in the client, so it is the yellow ! tinted. Chains Only
  leaves dungeon and raid quests on the map: most are no chain, and the run is the reason to go.
  Color Dungeon Quests (on by default) can turn the tint off, and Dungeon Quest Color picks it
  (`mapDungeonColor`, `DUNGEON_RGB` until you pick one).
- A battleground quest is in `D.Dungeon` as an instance quest (out of a zone's progress, kept with
  Chains Only), but its giver gets the plain ! and its tooltip line no "Dungeon": it is no dungeon or
  raid.
- Holding Shift over a giver's pin (world map or minimap) lists, under each quest, its experience, money and
  reputation (`D.Gains`), the instance it is for (`D.Instances`), the breadcrumbs still
  open to you that lead to it (`Q.Breadcrumbs`, `D.Breadcrumb` turned around) and every later step of its
  chain (one version of an `any` step). The experience is Wowhead's, at the quest's level, cut as the game
  cuts it once you are more than five levels over the quest (80% six levels over, 60% seven, then 50% however
  far over: Forever never cuts it to Classic's 10%), and left out at max level; experience buffs
  are not counted. The tooltip listens for `MODIFIER_STATE_CHANGED` only while a pin
  with more to show is hovered, and redraws as Shift goes down or up.
- An objective pin is matched to the game's objective by its place among the quest's objectives of its kind:
  items (`type` "item") apart from the rest. Wowhead's map gives an item objective its place among the items,
  but a kill or use objective only its creature or object, so a kill's place comes from the catalog's
  objective list, which keeps the quest's order (Wowhead's points are in ID order). Where the catalog cannot
  say (none listed, or creatures and objects both), the place is 0: its pins stay until every objective of
  that kind is done, so a pin is never put away while its objective is still to do. A quest with one such
  objective needs no place.
- Wowhead lists every creature that drops an item, the world over (Westfall Stew's vulture meat names
  Thousand Needles' vultures), so an objective with sources on the quest's giver's or hand-in's map keeps only
  those, and at most `SOURCES` of them, the most spawns first. Spawns within `CAMP` (3) map percent share a pin.
- Objective pins redraw on `QUEST_LOG_UPDATE`, which comes with every kill and loot, but only while the world
  map is open; the spots are read again then, from `C_QuestLog.GetQuestObjectives`. Spots of several quests at
  one place share a pin, whose tooltip names each quest and its objective.
- Quests on Minimap shows what the world map's Quest Givers and Quest Objectives show, for the map you stand on,
  through `Parts.MinimapLayer`. The layer reads its spots again each time you move, so it is handed lists only it
  uses: its own `Objectives.List()` and copies of the givers, which `Q.Givers` reuses on every world map redraw.
  Its pins are the world map pins' `Paint`, tooltip and click on a minimap button. The objective pin keeps its
  spot in `target`, not `spot`: the minimap layer keeps the index it painted in `pin.spot` and repaints a pin
  whenever that changes, which a table there would make every tick.
- A quest log update redraws only the minimap's objectives; the givers wait for a quest taken, handed in or
  dropped, a level, or a new map. `ZONE_CHANGED` comes with every subzone, so it redraws only when the map
  under you changes.
- A holiday's quest out of season is "Only during its holiday", with its holiday named on its row, and gets no
  !. The holidays on now are read from the game's calendar (`C_Calendar`, opened once with `OpenCalendar` as
  Blizzard's guild news does) on each refresh, for today whatever month the calendar shows: a holiday starting
  or ending today counts from its start time to its end time. The calendar fills in after login
  (`CALENDAR_UPDATE_EVENT_LIST`), so the pins redraw then. Holiday quests count toward no zone, as repeatable
  ones do: most come back each year.
- Keep Quest History records, per character (`completoHistory`), each quest taken (`QUEST_ACCEPTED`), handed in
  (`QUEST_TURNED_IN`, with its experience and money) and dropped, and each level reached, with the time, the
  quest's title and its level then: a quest out of the log has neither to read later. It keeps the latest
  `KEEP` (5000), about a character's whole levelling. A drop is the quest `C_QuestLog.SetAbandonQuest` was given
  when `C_QuestLog.AbandonQuest` runs (secure hooks on both): `QUEST_REMOVED` comes for a hand-in too, and
  which comes first is not documented. It keeps nothing from before it is turned on.
- The History tab shows the latest `HISTORY_SHOWN` (300) lines, newest first, a section per day; a
  search reads every line's title.
- Find's Creatures & Objects are every hand-in NPC and objective creature or object the data places, one per
  name and map at its first spot, named for the first of its quests that is yours and not done; one with none
  is left out. Quest givers are not among them: Find's Quests section already finds a quest by its giver's name.
  They are indexed on the first search, not at load.
- Quest Tooltips add your own quest lines to a creature's, object's or item's tooltip only when the game's has none
  (`Enum.TooltipDataLineType.QuestObjective` or `QuestTitle`): the client can show those from the server, so a
  creature never names its quest twice. Your party's progress (Share Quest Progress) is added either way. Its NPC ID comes from the tooltip's GUID, skipped while secret; an
  object's from its GUID or the tooltip's ID, an item's from the ID. The
  tooltip hooks cannot be taken off, so they are added the first time Quest Tooltips is on and do nothing while off.
- Patrol Paths draws a wandering objective creature's way as small, faint objective marks along it, as Rare Pins draws
  a patrolling rare's, on the world map only: a minimap full of dots would hide the pins near you. Its dots are
  their own spots, never merged into an objective pin at the same place, so a pin keeps its size, and sit a
  frame level below the pins (the dig site level, which Forever's map does not use), so a way starting on a pin's
  spot never takes its hover.
- Quest Nameplates hangs its own small frame on each nameplate it marks, kept in a table by nameplate and never
  written into the game's frame, as Glimmer's effect is. A nameplate carries its creature's NPC ID from its GUID,
  read when the nameplate comes; one that comes while that GUID is secret gets no icon. A forbidden nameplate (friendly
  ones in an instance) is skipped. The quest log's updates repaint the nameplates already shown.
- Share Quest Progress says, under the `NaowhQuests` prefix to your party (`PARTY`, or `INSTANCE_CHAT` in an
  instance group; never a raid), each quest in your log and its objectives' counts, each marked as an item
  objective or not, so the receiver places them as it places its own (`Objectives.Progress`). Version 1:
  `1 <GUID> <quest>:<i|o><have>/<need>,...;<quest>:-` for a quest gone. After the first, only what changed is
  said, `SEND_DELAY` (2) seconds after the last quest log change, never in combat or chat lockdown (then once it
  ends), split under `MESSAGE_MAX` (250) bytes. A message the channel refuses (`SendAddonMessage`'s result, a
  throttle) makes the next send the whole log again. Someone joining makes everyone ask (`1 ? <GUID>`) and say
  the whole log; any other roster change says nothing. An ask is answered only from a party member, never your
  own: the party channel brings your own messages back.
- A message is taken only from a party member whose name and GUID match (`ns.SenderIs`), with every field
  readable; one with any entry past `MAX_QUESTS`, `MAX_OBJECTIVES` or `MAX_COUNT` is dropped whole, as only
  changes are said and a part taken would leave the rest stale. A member who leaves is forgotten.
  Their progress shows under each objective pin's and Quest Tooltips' quest, for the objectives still to do.
- A right-click on a quest pin, on the map or the minimap, offers to hide each of its quests: a hidden quest gets
  no !, no objective pins and no hand-in, but stays in the Quest List's pages. It is kept per character
  (`completoHidden`), and Hidden Quests' Show All on the Map Pins card puts them all back. The pins listen to
  `Q.SetHidden` and `Q.ShowHidden` (secure hooks, as for the settings), so a hide redraws at once.
- A done quest (`C_QuestLog.IsComplete`, which a quest with no objectives is from the start) shows only its
  hand-in; a failed one shows nothing.
- The game keeps no record of the rares you killed, so Completo counts them itself, per character
  by GUID (`completoRareKills`, `completoRareDrops`), from when it is on: a rare you targeted dying
  while it was yours (not tapped by someone else), or a corpse you loot. Each creature counts once,
  and the record keeps the last creature's GUID, so its corpse looted again after a reload is not
  a second kill. One killed before can be ticked off by hand (its count is 0).
- A rare friendly to your faction is left out: you cannot kill it.
- Every unit value read for rares (GUID, dead, tapped, classification, name, level,
  loot links and sources, minimap marks) can be a secret value: each is checked with
  `issecretvalue` before it is compared or used, and a secret one is skipped.
- A rare's waypoint goes to the spawn spot or patrol dot nearest you while you are on its map,
  else to where it spawns most (its first spot).
- Inside a dungeon, a rare the Dungeon Journal's Rare Alert covers there is left to it
  (`ns.JournalRareHere`), so one rare never brings two alerts.
- Rare Alerts check a unit's classification first, before anything that makes a string, since
  every nameplate comes through. Any creature the game calls rare counts, in the data or not.
- `AGAIN_AFTER` is 300: each rare alerts once in five minutes, not every time its nameplate comes
  back. A rare you killed alerts only with Alert for Killed Rares.
- Completo's Lua never marks a rare: raid marks are Blizzard-only on Forever (`SetRaidTarget` has
  `HasRestrictions`), so an addon calling it is blocked. With Skull on Click, the targeting button
  below runs the game's own `/tm !8` after `/targetexact`: the `!` leaves a skull already on the
  rare in place instead of toggling it off. `/cleartarget` comes first, so a rare out of reach
  leaves nothing targeted and the skull never lands on what you had targeted before. It is off by
  default because a mark is seen by your whole group.
- Targeting is protected too, so a left-click on the alert targets its rare through a secure
  button running `/targetexact` and the rare's name. It is laid over the card, all but its pin,
  only while the pointer is on the card, and draws nothing, so the card looks and reads as it did.
- That button is a frame of its own on UIParent, placed where the card is but neither its child
  nor anchored to it: either would make the card protected, so it could not show or hide in combat.
- Its macro is set and it is shown only out of combat; it hides when combat starts, before the
  lockdown, so in combat a left-click on the card does nothing. A right-click on it closes the
  card, as on the card itself. It is made the first time the card is hovered.
- The sounds offered are the game's: SOUNDKIT names (left out where the client lacks one), kit IDs
  for the flag sounds SOUNDKIT has no name for, and the sound file IDs rare scanners use, the
  Gruntling Horn first. The addon's spoken lines and the error collector's sound are left out. A
  key no longer offered plays the Gruntling Horn.
- The card's place is kept in the screen's units (the HUD Editor reports the holder's scaled
  units), so Size grows it about the same spot; it starts 260 above the middle of the screen. It
  was `rareAlertPos` before the HUD Editor placed it: the same CENTER offset, moved over once.
- A real alert follows its rare (`UNIT_FLAGS`, only while the card is up): someone tapping it
  shows on the card, and its kill puts the card away. An alert from the minimap takes the first
  live creature of that rare seen.
- The portrait is the unit's model while it is in sight, else the creature's; the rare star for a
  rare with neither. The settings preview sets its model again when shown, as one set while the
  stage had no size, or dropped while the settings were shut, would be missing.
- The preview fits the card on its stage: at least 32 to spare across and 8 down, its glow
  counted, and a 600 wide stage before layout has run.
- A rare's star is where it is most likely to be. Hovering it shows its tooltip (what it is,
  whether you killed it, its drops), its other spawn spots and its way, smaller and taking no
  mouse (a level under the star, so nothing covers it), and fades the others. Right-click keeps
  that so (focus) after the pointer moves off, with no panel; right-click it again, or another
  star, to let go. Let go of, every star is back at once, not only once the pointer moves off,
  and its tooltip stays while the pointer is still on it. Another map lets go of it.
- The Rares tab listens to no events: a rare changes only by a kill counted, which redraws it.
- A search names every zone, so its rows do not name their zone; a rare opened from the map stays
  listed even with Hide Killed Rares.
- Bindings.xml gives Completo no default key, so it never binds while Completo is off. Once per
  character, with Completo on, Shift-L is bound to it if nothing else has it and Completo has no
  key yet; else a chat line says where to bind it. Never again after that, so a key changed or
  cleared stays as it was left.

- `/nfquests` and `/nfcompleto` are made in `Core/Commands.lua`, not here, and call
  `NaowhForever_ToggleCompleto`, which the core defines as "Discovery is switched off" and this
  tabs' file replaces when Discovery loads. So with Discovery off they say so instead of doing
  nothing, as the key binding does, and `/nf help` lists them.

## Checking

- `luacheck NaowhForever_Discovery` from the repo root.
- `lua Tools/regression/test-completo-rares.lua`: the rare rules, counting kills, Rare Alerts,
  their settings and preview, and the rare map pins and their focus. Its `SetRaidTarget` raises
  an error, so no rare path may set a raid mark; Skull on Click only adds `/tm` to the button's macro.
- `lua Tools/regression/test-completo-quest-prereqs.lua`: requirements, what a row says is missing, and a quest
  its giver offers.
- `lua Tools/regression/test-completo-quest-givers.lua`: a quest the data says is not yours becomes yours
  once a giver offers it, and a closed quest it offers opens, while one opened past a requirement still
  closes.
- `lua Tools/regression/test-completo-quest-gating.lua`: exclusive groups, breadcrumbs, a quest that needs
  it taken, professions and camp recipes close a quest, a quest in your log counts toward its zone, and
  every zone's count stays cheap.
- `lua Tools/regression/test-completo-quest-pins.lua`: the quest pins are Pin Size and keep one
  size on screen as the map zooms.
- `lua Tools/regression/test-completo-objective-pins.lua`: objective pins match the game's objectives by their
  place, go once done, give way to the hand-in, share a spot, and cost nothing while off.
- `lua Tools/regression/test-completo-quest-holidays.lua`: the holidays on today, a holiday's quests while it is
  on and off, the Faire's givers following the Faire, and the shipped data's holidays.
- `lua Tools/regression/test-completo-quest-history.lua`: what Quest History keeps, per character, and that it
  listens to nothing while off.
- `lua Tools/regression/test-completo-unit-tips.lua`: what a creature's tooltip adds, and when it adds nothing.
- `lua Tools/regression/test-completo-party-progress.lua`: what is said and when, what is taken, and each
  member's progress by an objective's place.
- `lua Tools/regression/test-completo-minimap-pins.lua`: the minimap shows what the map's switches show, from
  its own copies, and redraws only what an event changes.
- `lua Tools/regression/test-discovery-data-load.lua`: the quests and rares load once on the first
  read, and read as empty lists when `NaowhForever_DiscoveryData` does not load.
- In game: `/reload` after changing a file. A new file needs a restart.
