# Group Finder

A Looking For Group layer for Naowh Forever players, on top of WoW Forever's own group finder
(`Blizzard_GroupFinder_VanillaStyle`, a listing board with no applications). Forever does the listing,
searching and inviting; Naowh Forever players see each other's cards and can apply to a group, by
addon whispers between the two players. A module of `NaowhForever_Utilities` (Utilities > Group Finder
in the options window), needing `NaowhForever_BiS` for the Naowh Score and the BiS list; the Dungeon
Journal is optional and read for kills, quests and dungeon keys when it is loaded.

Off by default (`groupFinder.enabled`; its switch under Settings > Modules). This is the foundation:
the card, the whispers, the listings reader, the settings page and a probe command. The Browse, Your
Group and Create screens come next, on this data.

## Layout

```
NaowhForever_Utilities/GroupFinder/
  GroupFinder.xml      what loads, in order, included by Utilities.xml
  GroupFinder.lua      its settings (ns.GroupFinderSettings), the module table (ns.GroupFinder, GF), on or
                       off, and the listeners its files tell each other through (GF.Listen, GF.Fire)
  Card.lua             your card for one dungeon, and every message written and read (GF.Card)
  Comms.lua            the whispers: send queue, card requests, applications, expiry, guards (GF.Comms)
  Listings.lua         Forever's search results in pooled entries, activities to Journal keys (GF.Listings)
  Probe.lua            /nf groupfinder probe and /nf groupfinder ping <name>
  UI/
    SettingsPage.lua   its settings page (Group Finder/Settings): what your card shares
  README.md            this file
```

## How it talks

Addon whispers by name, prefix `NaowhLFG`. Every message is one plain line, version first, at most
255 bytes:

| Message | Sent | Answer |
| --- | --- | --- |
| `1 Q <nonce> <dungeon or ->` | asks a listed player for their card | `C` with the same nonce |
| `1 C <nonce> <card>` | your card | |
| `1 A <id> <card> [note]` | applies: your card with the roles you apply as, and a note | `K` |
| `1 K <id>` | the leader's game received it | |
| `1 X <id>` | you withdraw it | |
| `1 D <id>` | the leader declined: kept silent, the application just expires | |

The card is nine fields, `-` for one not shared or not known:

```
<class ID> <level> <roles> <spec> <score> <BiS> <dungeon> <kills> <quests>
1          20      TD      fury-warrior 189 8/14 Deadmines 3,2,0,0,99,1,0,0 168,2040/166,214
```

- roles: `T`, `H`, `D` in that order (the game's saved LFG roles, or the ones you apply as).
- spec: the BiS list's spec key. score: the Naowh Score in tenths. BiS: have/total.
- kills: each boss the game counts, in the Journal's order, capped at 99. A screen showing them per
  boss checks the count against its own list of the dungeon's bosses first; the total is always good.
- quests: the quests in your log, a slash, then those you still need, by quest ID (the reader names
  them in its own language).
- the note: printable ASCII, no `|` escapes, 60 bytes at most, always last.

Sizes: Q 15 bytes, C 86, A with a note 106; the biggest real application (Dire Maul's 19 bosses, a
full note) 248. When a card would not fit, its quest lists are cut first, then its kills.

## The data the screens use

- **A listing** (`GF.Listings.entries[1..n]`, after `GF.Listings.Read()`): `id`, `leader` (nil until
  the game names them), `activity`, `dungeon` (Journal key), `numMembers`, `members[1..nMembers]`
  (`name`, `level`, `class`, `roles` as card role bits, `leader`, up to 5), `age` in seconds,
  `delisted`, `party` (its party GUID). `GF.Listings.state` is `ready`, `locked`, `failed` or `none`.
- **A card** (`GF.Card.New()`): `class`, `level`, `roles` (bits: `Card.TANK`, `HEALER`, `DAMAGE`),
  `spec`, `score`, `bisHave`, `bisTotal`, `dungeon`, `hasKills`, `kills[1..nKills]`, `hasQuests`,
  `have[1..nHave]`, `need[1..nNeed]`. Received ones by name: `GF.Comms.CardOf(name)`.
- **An applicant** (`GF.Comms.applicants`): `id`, `name`, `card`, `note`, `at`, `deadline`.
- **Your application** (`GF.Comms.sent`): `id`, `name`, `dungeon`, `deadline`, `acked`, `declined`.
- Events (`GF.Listen(what, fn)`): `listings`, `listing`, `card`, `noreply`, `offline`, `applicant`,
  `received`, `withdrawn`, `expired`, `applicantExpired`.

## Why

- Custom chat channels are split per realm on Forever, so there is no channel network: a player's
  own search in Forever's finder is the discovery, and only the players they look at or apply to are
  whispered.
- Its own prefix: the BiS List's inspect whisper and the Naowh Score's share answer a unit you
  inspect or your group, while a card goes to a stranger from a listing and carries dungeon kills and
  quests they do not.
- Listings are read here rather than through Chat Zones or Group Finder Roles: those are Quality of
  Life features that may be off, and each reads only the one field it needs.
- Messages carry no GUID: the game names the sender, and a GUID in the text would only be the
  sender's own claim.
- Names are compared after `Ambiguate(name, "none")`: your own realm's suffix goes and other realms
  keep theirs, so Bob-A and Bob-B are two players, and your name on another realm is someone else.
  A reply to a ping or an application also matches when one of the two names has no realm, since
  Forever's listings name the leader without one.
- A card request or an application is answered only while you are listed
  (`C_LFGList.HasActiveEntryInfo`): browsing players ask listed players, and nobody else needs your
  card.
- Card requests are answered at most `ANSWERS_MAX` per `ANSWERS_WINDOW` seconds (half the send rate)
  and once per player per `ANSWER_GAP`, so players browsing your listing cannot fill the queue your
  own applications and acknowledgements go through.
- The send queue keeps to `BURST` at once then `RATE` a second, holds during chat lockdown, and waits
  again when the game answers with its own throttle.
- Listings are not read in chat-messaging lockdown, when the search results are secret. A listing or
  member with a secret field is skipped. Members' roles are the ones they signed up as (`lfgRoles`),
  as Group Finder Roles reads them.
- `GetFilteredSearchResults` leaves out listings the player reported, as the game's own finder does.
  `LFG_LIST_SEARCH_FAILED` marks the listings `failed`, so a screen can say so instead of waiting.
- The game's "No player named" line is hidden only for a name whispered in the last
  `NOT_FOUND_WINDOW` seconds, and ends that name's ping as offline.
- One sweep timer with a generation number expires pings, applications and applicants; turning the
  module off makes a pending sweep stale.
- Activities are matched to Journal dungeons by name, then by instance map when only one dungeon has
  it, never guessing between Scarlet Monastery's wings or the Blackrock Spires. Activity names come in
  the client's language, so outside English only the map match works for now.
- Every table that grows with other players is bounded: the queue, pings, applications, applicants,
  kept cards, senders, askers and names whispered.

## Settings

| Key | Default | What it is |
| --- | --- | --- |
| `enabled` | `false` | the module |
| `shareScore` | `true` | your Naowh Score on your card |
| `shareKills` | `true` | your boss kills for the dungeon |
| `shareQuests` | `true` | the dungeon's quests you have or need |
| `shareBis` | `true` | how many of your BiS items you have |

## Checking

- `lua Tools/regression/test-group-finder.lua`: loads every file `GroupFinder.xml` lists against
  stubs and checks it is free while off, the card and its messages, the whispers' guards and expiry,
  answering only while listed, names across realms, the listings, the probe, and the budgets: a card
  built and written under 0.1 ms, read under 0.05 ms, fifty listings read under 0.5 ms, none of them
  making garbage.
- In game: `/nf groupfinder probe`, and `/nf groupfinder ping <name>` between two players with the
  Group Finder on; the one pinged needs a listing up in the game's Group Finder.
