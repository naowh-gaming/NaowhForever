# Druid Mana

A druid's mana while shapeshifted, as a bar under the player frame or wherever it is dragged. Under
the bar a thin line runs down the five second rule after a spell that costs mana, with its
countdown, and a soft spark pulses at the end of the fill while mana is coming back. The end of
the fill shows what shifting back into the current form would take, with a line where the mana
would land, a line under the bar how many shifts are left, and the bar's edge takes the shift
cost color when there is not enough mana for one. Its settings page
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
- The shift cost hangs off the right end of the fill, like a spell's cost preview: a segment as
  wide as the cost's share of maximum mana, anchored to the fill texture, with the line at its
  left edge, in a frame clipped to the bar. It reads only the cost and maximum mana, never the
  current mana, so it looks the same whether that is secret or not; below one shift it covers the
  whole fill and the line falls outside the bar. The cost is the current form's spell cost
  (`GetShapeshiftFormInfo`'s spell ID through `C_Spell.GetSpellPowerCost`), so talents that lower
  it are counted.
- What needs a comparison (shifts left, the edge turning to the shift cost color) shows only while
  the mana is readable.
- The segment and the spark are anchored to the fill each time the bar is styled, after its
  texture is set.
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
