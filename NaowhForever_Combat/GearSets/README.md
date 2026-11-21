# Gear & Trinkets

A bar of your equipment sets to swap with a click, saving new ones from what you wear, and
automatic swaps to a set while mounted, drinking, in a form or stance, in a dungeon, raid or
battleground, or resting, that put back what you wore afterwards.
Built on the client's own equipment manager, so the sets are the ones the character sheet
shows. Also a movable bar of your two trinket slots. Its settings are in the QoL store
(`gearSets`, `gearBarVisible`, `trinketBar` and the `gear*`/`trinket*` keys), on the
Gear & Trinkets/Settings page; the sets themselves are in the Gear Sets window (`/nfgear`, its
minimap and Top Bar button, Open Gear Sets on its settings page).

## Layout

```
NaowhForever_Combat/GearSets/
  GearSets.xml                every file, in load order, included by Combat.xml
  GearSets.lua                the rules and API (ns.GearSets, G): your sets, equipping one,
                              equipping after combat, putting back what you wore, the automatic swaps
  Constants.lua               what its files share (G.C): the settings page, the trinket slots
  Trinkets.lua                the trinket rules (G.Trinkets): each slot's queue and the trinket-ready alert
  View/
    Style.lua                 its look (G.Style), on top of Shared/Style.lua
    Look.lua                  a set or trinket button's look, on the bars and previews (G.Look)
  UI/
    Dialogs.lua               new, rename, save and delete a set, and the icon picker
    Bar.lua                   the Gear Set Bar, and the events behind it and the swaps
    TrinketBar.lua            the Trinket Bar and its picker of trinkets in your bags
    Window.lua                the Gear Sets window
    SettingsPage.lua          its settings page, declared as cards, with the bars' previews
  README.md                   this file
```

## Why

- Both bars' Growth Direction (`gearBarGrow`, `trinketGrow`) places buttons with `ItemBar.Place` in one
  line (`ItemBar.ONE_LINE`); Right is the way they always grew.
- Armor cannot change in combat, so a set asked for then waits for the fight to end
  (`G.EquipPending` on `PLAYER_REGEN_ENABLED`). Only the last set asked for waits.
- Swap Weapons in Combat (`gearCombatWeapons`) puts a set's main hand, off hand and ranged on at once,
  the slots the game's own `INVSLOTS_EQUIPABLE_IN_COMBAT` lets change in combat; the whole set still
  goes on when the fight ends.
- Nothing goes on while you are dead (Feign Death is not); the set waits for `PLAYER_ALIVE` or
  `PLAYER_UNGHOST`.
- After a fight the automatic swaps are worked out before the set that waited goes on, so a set picked by
  hand in combat wins, and a form shifted in and out of during the fight does not swap twice.
- The set an automatic swap replaced is kept per character in the account settings
  (`gearReturn`), so logging out in town or mounted still puts it back after the next login.
- A set picked by hand is kept when the automatic swap ends. Mounted beats drinking, then a form, then a
  dungeon, raid or battleground, then resting.
- When no set is worn as an automatic swap starts, every slot's item is kept instead (its link, or false
  for an empty slot) and put back slot by slot; an item in a slot that was empty goes into the bags.
- Free bag slots are counted once per putting back and used up as items go in, since the bags' counts
  change only when the server answers.
- Putting back a two-hander leaves the off hand alone: equipping a two-hander moves the off hand into
  the bags by itself.
- A form or stance is kept by its spell ID (`gearForms`), since a druid's form numbers shift as forms
  are learned. Its rows are the forms you have, so a class without any shows none.
- Drinking is the Drink buff on you by the Drink spell's own name (`ns.IsDrinking`), as `ns.IsDrink`
  reads drinks. In combat or while auras are secret the last answer holds.
- `UNIT_AURA` and `UPDATE_SHAPESHIFT_FORM` are listened to only while a set is picked for drinking or
  a form, and they redraw nothing.
- The automatic swap choices hold the set's name, so renaming a set updates them, and One-Key Fishing's
  Fishing Gear (`fishingGearSet`, QoL) with them.
- Putting a set on by hand (the bar, the window, `/nfgear equip`) keeps what you wore before it per
  character (`gearBefore`: the set, or the items as above), which Click Again to Take Off (`gearClickOff`)
  and `/nfgear off` put back. The window's Equip only puts a set on, so a click there never takes one off.
- `/nfgear equip <set>`, `/nfgear toggle <set>[, <other set>]` and `/nfgear off` go through `ns.GearSetsCommand`
  (Core's `MODULE_ARGS`), so a macro can bind them to a key; `/nfgear` alone still opens the window.
- A set swap fires `PLAYER_EQUIPMENT_CHANGED` once per slot; one redraw on the next frame covers
  the burst.
- The bar's Show (Always, In Combat, Out of Combat) is ignored in the HUD Editor, which always
  shows it; it listens to `PLAYER_REGEN_DISABLED` only when Show is not Always.
- The icon picker uses the client's own icon list, the one its equipment manager offers, with
  the icons of what you wear first. The list holds every macro icon while open, so it is
  released on close. Hiding the UI (Alt-Z, a cinematic) hides the dialog too, which releases
  the icons, so it stays closed when the UI comes back. The grid is built once; what changes
  per open (the icon list, the action) is kept on it.
- `EMPTY_ICON` (134400) is the game's question mark, for an empty trinket slot.
- The trinket slots are secure item buttons: a change to them waits for combat to end, and a
  right-click to pick a trinket works only outside combat. The bags are checked again on the
  click, since they may have changed since the picker opened.
- The secure item action errors on an empty slot (a nil link into `C_Item.IsEquippableItem`), so
  an empty slot gets no `type1`.
- The window listens only while it is open.
- The Trinket Queue (`trinketQueue`) keeps each slot's trinkets per character in the account settings
  (`gearTrinketQueue`), best first. The first one that is ready and in your bags, or already in the slot,
  goes on; a trinket in the slot that is not in its queue is left on.
- "Ready" is 30 seconds or less to go (`READY_WITHIN`): a trinket just put on cannot be used for 30
  seconds, so one that is nearly ready loses nothing by going on now.
- A trinket whose buff is still on you stays on until the buff ends, in case taking it off ends the buff.
  While auras are secret the queue waits.
- The queue swaps only out of combat and while alive, and waits a second (`RETRY`) while you cast or
  hold an item on the cursor, since an equip cancels a cast. It runs on events, and a timer only for
  the next trinket due to be ready; one trinket goes into one slot per pass.
- The Trinket Ready Alert (`trinketReady`) arms a timer for a worn trinket's cooldown, longer than the
  global cooldown, and says so when it ends if the same trinket is still on. A cooldown the game keeps
  secret arms nothing.

## Checking

- `lua Tools/regression/test-gear-swaps.lua`: the automatic swaps, putting back what you wore, combat
  and death, Click Again to Take Off and `/nfgear`.
- `lua Tools/regression/test-trinket-queue.lua`: the Trinket Queue and the Trinket Ready Alert.
- `lua Tools/regression/test-robin-final.lua`: the trinket bar (secure buttons, the picker, combat
  deferral, its events only while on) and the gear bar's Show choices.
