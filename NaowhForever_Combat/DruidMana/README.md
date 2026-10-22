# Druid Mana

A druid's mana while shapeshifted, as a bar under the player frame or wherever it is dragged. Under
the bar a thin line runs down the five second rule after a spell that costs mana, with its
countdown, and a soft spark pulses at the end of the fill while mana is coming back. A mark on the
bar shows what shifting back into the current form costs, a line under it how many shifts are
left, and the bar takes the warning color when there is not enough mana for one. Its settings page
is Druid Mana/Settings. Off by default (`enabled` in the `druidMana` store, from
`ns.FEATURES.druidMana`), and inert for every other class.

## Layout

```
NaowhForever_Combat/DruidMana/
  DruidMana.xml            every file, in load order, included by Combat.xml
  DruidMana.lua            the settings (ns.DruidManaSettings) and the module table (ns.DruidMana, DM)
  View/
    Style.lua              its look (DM.Style), on top of Shared/Style.lua
  UI/
    Bar.lua                the bar on screen: its mana, the five second rule, the shift cost, events
                           and Unlock Mode
    SettingsPage.lua       the Druid Mana/Settings page, declared as cards
  README.md                this file
```

## Why

- Forever may hand an addon its own mana as a secret value in combat. The bar never compares or
  does arithmetic on it: the current and maximum mana go straight to the StatusBar and to
  `SetFormattedText`, and the percent comes from `UnitPowerPercent` through a 0 to 100 curve.
- What needs a comparison (shifts left, the whole bar turning to the warning color) shows only
  while the mana is readable. While it is secret, the warning color is drawn only under the shift
  cost mark: a copy of the bar in the warning color sits in a frame clipped to the mark, so the
  fill shows the warning color exactly where it is below the cost, without the addon knowing.
- The shift cost is the current form's spell cost (`GetShapeshiftFormInfo`'s spell ID through
  `C_Spell.GetSpellPowerCost`), placed at that share of maximum mana, so talents that lower it
  are counted.
- The game has no call for the five second rule or the regen tick. The rule starts on
  `UNIT_SPELLCAST_SUCCEEDED` for a spell that costs mana (shifting itself does), and the line is a
  `Parts.TimerLine` the client runs down by itself. The spark pulses every `TICK_SECONDS` (2) by an
  animation; it marks that mana is coming back, not the exact tick.
- The form decides whether the bar shows (`GetShapeshiftFormID`): Cat 1, Bear 5 and Dire Bear 8,
  Travel 3, Aquatic 4; any other form, Moonkin among them, counts as caster form.
- It pins to a unit frame through `Shared.Anchor`, under `PlayerFrame` by default, and moves only
  out of combat. Dragging it in the HUD Editor puts it back on the screen.
- Power events are registered only while the bar is shown; a non-druid registers nothing.

## Checking

- `lua Tools/regression/test-druid-mana.lua`: nothing made or listened to while off or for another
  class, the forms it shows in, the values and text, the shift cost mark and shifts left, the
  warning with readable and secret mana, the five second rule and the settings page.
