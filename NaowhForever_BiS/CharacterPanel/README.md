# Character Panel

The game's character panel (C) in the BiS List's look. Blizzard keeps the panel and everything
it does: its slots' clicks, drags and tooltips, its tabs and its stats. Naowh fades its art
(`SetAlpha`, never `Hide`) and lays its own frames over it, from post-hooks only.

Off by default (BiS List > Character Panel), and nothing is hooked until it is first turned on.

EllesmereUI styles the same panel, and the two are never on at once. Turning Naowh's on turns
EllesmereUI's Character Sheet off (`EllesmereUIDB.themedCharacterSheet = false`, what its own
switch sets), and turning Naowh's off turns it back on if Naowh's was what turned it off; either
way a reload is offered, as EllesmereUI swaps its look at login. Should EllesmereUI's come back on
by other means (read through `EllesmereUI.GetBlizzWindowStyle("charsheet")`), Naowh's stands down.

## Layout

```
CharacterPanel/
  CharacterPanel.xml   what loads, in order
  CharacterPanel.lua   the namespace (ns.CharacterPanel), its switch, EllesmereUI's rule (CP.Rival)
  Constants.lua        the pane's width and edge, and the sizes and colours the panel's files and the
                       Inspect Panel share (CP.C)
  Slots.lua            the slots: edge in the quality's colour, item level, Forever's mark,
                       your BiS's star, the enchant dot
  Score.lua            your Naowh Score as a card under your level: the score big, a bar to
                       its share of the best; hover for the score with your BiS, click for
                       the BiS List
  Badge.lua            your supporter badge in the left pane's top corner (CP.BadgePlate)
  Totals.lua           your total now for each stat, plain or while the game keeps it secret (CP.Totals)
  SpecStats.lua        the stats: your spec's first (the stats it weighs, in a fixed order,
                       each with a bar for its worth against the spec's yardstick, "VS AGI",
                       and your total; hover a row for what it is worth and what it does), or
                       the game's All Stats; the switch at the bottom
  Chrome.lua           the frame: our backdrop and title, the game's art faded or tinted,
                       the stats' rows restyled as the game's list makes them
  UI/SettingsPage.lua  its cards on BiS List > Character
```

The Inspect Panel (`InspectPanel/`) dresses the inspect window with the same parts: the rule
for EllesmereUI (`CP.Rival`), the frame (`CP.Restyler`, `CP.Chrome`), the slots (`CP.SlotOver`),
the score card (`CP.ScoreCard`) and the badge plate (`CP.BadgePlate`).

## How the slots work

Ours is a frame over each of the game's slot buttons (`Character<Name>Slot`), kept in a side
table: nothing of ours is stored on the game's frames. A post-hook of
`PaperDollItemSlotButton_Update` paints it each time the game updates the slot. Turned off,
the game's art comes back and ours hides.

## Why

- With both on, a player new to Naowh Forever (the onboarding not seen yet) gets Naowh's panel from the
  next reload, told in chat; anyone else is asked once. At most one question a login, the character
  panel's first: a second confirm would close the first. The question waits `ASK_DELAY` seconds after
  entering the world, and never comes in combat.
- A "took over" that EllesmereUI's own switch does not bear out (copied in with a profile, or
  EllesmereUI's turned back on since) is forgotten at login with its question, so the player is asked
  as on a first run.
- EllesmereUI styles a window when its public `GetBlizzWindowStyle` says anything but `"off"`; it is
  nil when its window skins are not loaded.
- `CP.PANE_W` is the game's right pane (`RightPaneHost` in its CharacterFrame.xml); `CP.EDGE` is the
  one edge in from its sides that your score, the stats and the switch all keep.
- Our backdrop sits at the panel's own frame level, under the game's frames, so the game's slots,
  model and stats draw over it. Each faded or tinted piece of the game's art is remembered so turning
  it off brings it all back.
- A model's buttons are faded texture by texture: the game sets their frame's alpha itself on hover,
  never their art's. A frame covers their strip so they take no clicks; dragging the model turns it
  and the wheel zooms it.
- The stats' rows are styled as the game's list makes them (its scroll box's initialized-frame
  callback), the same on every reuse.
- The BiS List's link sits in the left pane's top-right corner on your badge's middle, clear of the
  game's toggle for the stats there (`TOGGLE_W` 28px, `TOGGLE_EDGE` 6px in).
- An empty slot is nil, and an empty ammo slot 0.
- The game's slot update sets the icon again, so it is cropped again in our look on each update.
- A black ring outside the quality's edge (the house's border) makes the edge stand off the dark
  panel round it.
- The score card is a child of the game's stats list (its fade ignored), so the game hides it with
  the list whenever its gear sets, titles or pet take that room, and it never sits over their rows.
- `ROOM` is what the game leaves between your level and its list's top (the list's first title sits
  low in its own row): only what the score needs beyond it moves the list down.
- The stats can go secret under the game's addon restrictions (combat, an encounter, some maps):
  `ADDON_RESTRICTION_STATE_CHANGED` paints them again when one lifts. While secret, the totals the
  game can still show are set straight on the row's text by the calls that take a secret (a font
  string's `SetText` and `SetFormattedText`, and `C_StringUtil`'s rounding); a total we would have to
  add up or compare ourselves shows "-". The hover card writes it the same way.
- A spec's yardstick is the stat its weights are measured in (the defaults weigh it 1: Agility or
  Strength for fighters, Stamina for tanks, Spell Damage or Healing for casters), else the heaviest
  of `YARDSTICKS`.
- A row's bar is its weight's share of the heaviest by the square root, so a small one still shows.
- The badge art is 128px: drawn at a third of that it needs the mipmapped (`TRILINEAR`) filter to
  stay sharp. Its plate sits over the model, which is at frame level 50.
- While `ns.FEATURE_BADGES` is 0 only the team's badges exist, and the badge setting's default holds;
  the Supporter Badge row is on the page only while it is 1.

## Checking

`lua Tools/regression/test-character-panel.lua`: off and hooking nothing by default, the art
faded and each part painted when on, standing down for EllesmereUI, the art back when off, and
no garbage from a slot's update.
