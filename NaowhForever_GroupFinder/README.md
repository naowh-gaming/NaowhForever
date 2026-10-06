# Group Finder

A Looking For Group layer for Naowh Forever players, on top of WoW Forever's own group finder
(`Blizzard_GroupFinder_VanillaStyle`, a bulletin board with listings and no applications). Forever
does the listing, searching and inviting; Naowh Forever players see each other's cards and can
apply to a group, by addon whispers between the two players. Off by default: players turn it on
in Settings > Modules and its settings page.

Phase 1 is the foundation: the card, the whispers, the listings reader, the settings page and a
probe command. The Browse, Applicants and Create screens come next, on this data.

## Layout

```
GroupFinder/
  GroupFinder.xml      what loads, in order (the TOC includes only this file)
  GroupFinder.lua      settings (ns.GroupFinderSettings), on or off, a small listener list (GF.Listen, GF.Fire)
  Card.lua             your card for one dungeon, and every message written and read (GF.Card)
  Comms.lua            the whispers: send queue, card requests, applications, expiry, guards (GF.Comms)
  Listings.lua         Forever's search results in pooled entries, activities to Journal keys (GF.Listings)
  Probe.lua            /nf groupfinder probe and /nf groupfinder ping <name>
  UI/SettingsPage.lua  its settings page (Group Finder/Settings): what your card shares
```

Everything hangs off `ns.GroupFinder` (`GF`). It needs the BiS module (the Naowh Score, the BiS
list); the Dungeon Journal (kills, quests, dungeon keys) is optional and checked before use.

## How it talks

Addon whispers by name, prefix `NaowhLFG`. Custom chat channels are split per realm on Forever, so
there is no channel network: a player's own search in Forever's finder is the discovery, and only
the players they look at or apply to are whispered. Every message is one plain line, version
first, the sender's GUID next, at most 255 bytes:

| Message | Sent | Answer |
| --- | --- | --- |
| `1 Q <guid> <nonce> <dungeon or ->` | are you running Naowh Forever? send your card | `C` with the same nonce |
| `1 C <guid> <nonce> <card>` | your card | |
| `1 A <guid> <id> <card> [note]` | apply: your card with the roles you apply as, and a note | `K` |
| `1 K <guid> <id>` | the leader's game received it | |
| `1 X <guid> <id>` | you withdraw it | |
| `1 D <guid> <id>` | the leader declined: kept silent, the application just expires | |

The card is nine fields, `-` for one not shared or not known:

```
<class ID> <level> <roles> <spec> <score> <BiS> <dungeon> <kills> <quests>
1          20      TD      fury-warrior 189 8/14 Deadmines 3,2,0,0,99,1,0,0 168,2040/166,214
```

- roles: `T`, `H`, `D` in that order (the game's saved LFG roles, or the ones you apply as).
- spec: the BiS list's spec key. score: the Naowh Score in tenths. BiS: have/total.
- kills: each boss the game counts, in the Journal's order, capped at 99. A screen showing them
  per boss checks the count against its own list of the dungeon's bosses first (another version of
  the data may list them differently); the total is always good.
- quests: the quests in your log, a slash, then those you still need, by quest ID (the reader names
  them in its own language).
- the note: printable ASCII, no `|` escapes, 60 bytes at most, always last.

Sizes: Q 36 bytes, C 107, A with a note 127; the biggest real application (Dire Maul's 19 bosses,
a full note) 245. When a card would not fit, its quest lists are cut first, then its kills.

Guards: nothing is registered while off; messages from yourself, players you ignore, a sender over
8 in 10 seconds, anything malformed, and anything read during chat lockdown are dropped; the send
queue keeps to 10 at once then 1 a second and holds during lockdown; card requests wait 10 seconds,
applications 10 minutes, one sweep timer with a generation number; the game's "No player named"
line is hidden only for a name whispered in the last 10 seconds. It never searches, lists,
invites or chats by itself.

## The data the screens use

- **A listing** (`GF.Listings.entries[1..n]`, after `GF.Listings.Read()`): `id`, `leader`,
  `activity`, `dungeon` (Journal key), `numMembers`, `members[1..nMembers]` (`name`, `level`,
  `class`, `role`, `leader`, up to 5), `age` in seconds, `delisted`, `party` (its party GUID).
- **A card** (`GF.Card.New()`): `guid`, `class`, `level`, `roles` (bits: `Card.TANK`, `HEALER`,
  `DAMAGE`), `spec`, `score`, `bisHave`, `bisTotal`, `dungeon`, `hasKills`, `kills[1..nKills]`,
  `hasQuests`, `have[1..nHave]`, `need[1..nNeed]`. Received ones by name: `GF.Comms.CardOf(name)`.
- **An applicant** (`GF.Comms.applicants`): `id`, `name`, `guid`, `card`, `note`, `at`, `deadline`.
- **Your application** (`GF.Comms.sent`): `id`, `name`, `dungeon`, `deadline`, `acked`, `declined`.
- Events (`GF.Listen(what, fn)`): `listings`, `listing`, `card`, `noreply`, `offline`,
  `applicant`, `received`, `withdrawn`, `expired`, `applicantExpired`.

## Checking

- `lua Tools/regression/test-group-finder.lua`: loads every file `GroupFinder.xml` lists against
  stubs, with the real Naowh Score and the Journal's real kill and quest rules, and checks it is
  free while off, the card and its messages, the whispers' guards and expiry, the listings, the
  probe, and the budgets: a card built and written under 0.1 ms, read under 0.05 ms, fifty listings
  read under 0.5 ms, none of them making garbage.
- In game: `/nf groupfinder probe`, and `/nf groupfinder ping <name>` between two players with the
  Group Finder on.
