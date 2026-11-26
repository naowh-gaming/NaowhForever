# Group Finder

Naowh Forever on top of WoW Forever's own group finder (`Blizzard_GroupFinder_VanillaStyle`, a listing
board with no applications). The game's window stays as players know it; the module adds to its Browse
rows, puts an Apply button on its Browse screen, and docks a panel to its right.
Naowh Forever players see each other's cards and can apply to a group, by addon whispers between the two
players. A module of `NaowhForever_Utilities` (Utilities > Group Finder in the options window), needing
`NaowhForever_BiS` for the Gear Score and the BiS list; the Dungeon Journal is optional and read for kills,
quests and dungeon keys when it is loaded.

Off by default (`groupFinder.enabled`; its switch under Settings > Modules). Nothing of it is made until
it is on and the game's finder has loaded.

## On the game's Browse screen

- Each group row gets its members as five squares on the right, in their class colors with their role
  and the leader's crown, then its open spots, lit when the spot is one of your saved roles. The squares
  sit over the game's own role display, which is faded out under them, never hidden.
- Under the squares: the leader's Gear Score, and your application (Applied, Received, Invited,
  Declined), or the group's minimum score in red when yours is under it.
- The same button says Ask to Join when the picked group's leader does not run Naowh Forever: it
  whispers them your Ask to Join message.
- With Whisper on Invite on, the game's Group Invite button also whispers the player your Invite
  message, naming the dungeons you listed.
- Apply, in the game's own button style, between the game's Send Message and Group Invite, applies to the picked group with the roles
  and note picked in the panel. It is off for a leader without Naowh Forever, a delisted group or one
  you applied to.
- Groups your filters leave out stay in the list, dimmed.

## The panel

Docked to the right of the game's window and its side tabs, it follows the game's tab: Picked Group and
Filters beside Browse, your group beside Listing, nothing beside Who. Its cross hides it; a Naowh
Forever tab under the game's side tabs brings it back (`panelOpen`).

- **Picked Group:** the group picked in the game's list: dungeon, levels, playstyle and age, the
  leader's note, every member with their role, class and level, its open spots, whether it has Bloodlust
  or a Battle res, the leader's card (Gear Score, kills here, quests, BiS, zone) and their minimum. Then
  Apply as (tank, healer, damage) and a note kept for next time, Apply, or your application's state, its
  time left and Withdraw.
- **Filters:** My filters (named sets of filters, up to 20, saved with Save new filter), a search over
  leader, dungeon and note, open spot for each role, Room for my whole party, Group has (my class, Bloodlust, Battle
  res, friend or guild, any class; a second click asks for groups without it), the leader's minimum Gear
  Score, playstyle, players on their own by class and by lowest and highest level, Dim Groups That
  Declined Me, an advanced filter with its word list, and Reset. Group filters leave players on their
  own alone, and theirs leave groups alone. Every filter but the search text is kept between sessions.
- **Whispers:** beside Browse and beside your group, the whispers you received while the module is on,
  newest first (the last 100), each with Invite and Remove, and Clear; the tab counts the unread ones.
- **Your group:** what Naowh Forever players are told about your listing (the roles you still need,
  your minimum Gear Score, a note), then the players who applied, best Gear Score first, each with their
  card, note, the roles they offered (click one to invite them as it), Invite and Decline, then your
  party.
- The footer: Set My Role When I Join and your applications (joined, declined, withdrawn, no answer)
  beside Browse; Sound When Someone Applies beside your group.

## Advanced filter

Words: `tank`, `healer`, `dps`, `members`, `tankOpen`, `healerOpen`, `dpsOpen`, `score` (the leader's
Gear Score), `min` (the group's minimum), `age` (minutes), `level` (the leader's), `friends`, `myClass`,
`hasBL`, `hasBR`, and each class's name, counting its players. Numbers, `+ - * /`, brackets,
`< > <= >= == !=` (`=` and `~=` too), `and`/`&&`, `or`/`||`, `not`/`!`, `true`, `false`. Examples:
`healerOpen > 0 and age < 10`, `mage + priest >= 1`, `not hasBL`.

## Layout

```
NaowhForever_Utilities/GroupFinder/
  GroupFinder.xml      what loads, in order, included by Utilities.xml
  GroupFinder.lua      its settings (ns.GroupFinderSettings), the module table (ns.GroupFinder, GF), on or
                       off, and the listeners its files tell each other through (GF.Listen, GF.Fire)
  Card.lua             your card for one dungeon, and every message written and read (GF.Card)
  Comms.lua            the whispers: send queue, card requests, applications, expiry, guards (GF.Comms)
  Listings.lua         Forever's search results in pooled entries, activities to Journal keys (GF.Listings)
  Search.lua           the activities that suit your level, as the Dungeon Journal reads them (GF.Search)
  Group.lua            your listed group: what Naowh Forever players are told, inviting as a role and
                       declining applicants (GF.Group)
  Browse.lua           each listing's leader asked once for their card after a search, and applying (GF.Browse)
  Filter.lua           which listings show bright: the filters and the advanced filter (GF.Filter)
  Roles.lua            your role set when you join a group (GF.Roles)
  Whispers.lua         Ask to Join, the whisper with an invite, and the whispers you receive (GF.Whispers)
  Tally.lua            how this character's applications went (GF.Tally)
  Probe.lua            /nf groupfinder probe and /nf groupfinder ping <name>
  View/
    Style.lua          its look and the words its views share (GF.UI, GF.UI.Style)
    Parts.lua          the panel's small parts: a stack, member lines, steppers, chips, an edit line
  UI/
    Rows.lua           our part of each row in the game's Browse list (GF.UI.Rows)
    Picked.lua         the panel's Picked Group view and applying (GF.UI.Picked)
    Filters.lua        the panel's Filters view, with My filters (GF.UI.Filters)
    Whispers.lua       the panel's Whispers view (GF.UI.WhispersView)
    Listing.lua        the panel beside the game's Listing screen (GF.UI.Listing)
    Panel.lua          the panel, the Browse screen's Apply button, and when they show (GF.UI.Panel)
    SettingsPage.lua   its settings page (Group Finder/Settings)
  README.md            this file
```

## How it talks

Addon whispers by name, prefix `NaowhLFG`. Every message is one plain line, version first, at most
255 bytes:

| Message | Sent | Answer |
| --- | --- | --- |
| `1 Q <nonce> <dungeon or ->` | asks a listed player for their card | `C` or `L` with the same nonce |
| `1 C <nonce> <card>` | your card | |
| `1 L <nonce> <card> <minimum or -> <needs> [note]` | your card and the group you listed through Create | |
| `1 A <id> <card> [note]` | applies: your card with the roles you apply as, and a note | `K` |
| `1 K <id>` | the leader's game received it | |
| `1 X <id>` | you withdraw it | |
| `1 D <id>` | the leader declined: no message, the row says Declined until the application expires | |
| `1 I <id> <role>` | the leader invites you as one role, just before the game's invite | |

The card is nine fields, `-` for one not shared or not known:

```
<class ID> <level> <roles> <spec> <score> <BiS> <dungeon> <kills> <quests>
1          20      TD      fury-warrior 189 8/14 Deadmines 3,2,0,0,99,1,0,0 168,2040/166,214
```

- roles: `T`, `H`, `D` in that order (the game's saved LFG roles, or the ones you apply as).
- spec: the BiS list's spec key. score: the Gear Score in tenths. BiS: have/total.
- kills: each boss the game counts, in the Journal's order, capped at 99. A screen showing them per
  boss checks the count against its own list of the dungeon's bosses first; the total is always good.
- quests: the quests in your log, a slash, then those you still need, by quest ID (the reader names
  them in its own language).
- the note: printable ASCII, no `|` escapes, 60 bytes at most, always last.
- `L`'s minimum: the Gear Score in tenths. needs: three digits, the tanks, healers and damage you want.

Sizes: Q 15 bytes, C 86, L with a note 129, A with a note 106; the biggest real application (Dire
Maul's 19 bosses, a full note) 248. When a card would not fit, its quest lists are cut first, then its
kills.

## The data the screens use

- **A listing** (`GF.Listings.entries[1..n]`, after `GF.Listings.Read()`): `id`, `leader` (nil until
  the game names them), `activity`, `dungeon` (Journal key), `numMembers`, `members[1..nMembers]`
  (`name`, `level`, `class`, `roles` as card role bits, `leader`, `zone` or nil, up to 5), `tanks`, `healers`,
  `damage`, `age` in seconds, `delisted`, `mine` (your own), `party` (its party GUID), `style` (its
  playstyle, 1 to 4). By the game's result ID: `GF.Listings.ById(id)`.
  `GF.Listings.state` is `ready`, `locked`, `failed` or `none`. An activity
  (`GF.Listings.Activity(id)`, read once): `name`, `short`, `min` and `max` levels, `size`.
- The game's finder searches. The category's activities by level: `GF.Search.Activities(list)`, and
  whether one suits your level: `GF.Search.Suits(id)`. A leader's card (`GF.Browse.CardOf(name)`): the
  card, and whether one is still awaited. Which listings show bright: `GF.Filter.Pass(entry)`; a role's
  open spots: `GF.Filter.Open(entry, role)`, the leader's `L` needs when they sent one, else the
  dungeon's one tank, one healer and three damage less who is there.
- **A card** (`GF.Card.New()`): `class`, `level`, `roles` (bits: `Card.TANK`, `HEALER`, `DAMAGE`),
  `spec`, `score`, `bisHave`, `bisTotal`, `dungeon`, `hasKills`, `kills[1..nKills]`, `hasQuests`,
  `have[1..nHave]`, `need[1..nNeed]`. Received ones by name: `GF.Comms.CardOf(name)`, with `group`
  (`min`, `tanks`, `healers`, `damage`, `note`) when they answered with `L`.
- **An applicant** (`GF.Comms.applicants`): `id`, `name`, `card`, `note`, `at`, `deadline`, `invited`,
  `as` (the role the leader picked).
- **Your application** (`GF.Comms.sent`, one by leader: `GF.Comms.SentTo(name)`): `id`, `name`,
  `dungeon`, `deadline`, `acked`, `declined`, `roles` (applied as), `invitedAs`.
- **Your group** (`GF.Group`): what Naowh Forever players are told while it is listed: `min` (tenths),
  `tanks`, `healers`, `damage` still wanted, and `note`. Inviting takes one from the role's count.
- Events (`GF.Listen(what, fn)`): `listings` (true when the search failed), `listing`, `card`, `noreply`,
  `offline`, `applicant`, `newApplicant`, `received`, `declined`, `invitedAs`, `withdrawn`, `expired`,
  `applicantExpired`, `applied`, `joined`, `group`, `filter`, `tally`.

## Why

- Robin, 2026-11-15: players know the game's own group finder, so the module adds to it instead of being
  a window of its own.
- Rows are decorated from a post-hook on `LFGBrowseSearchEntry_Update`, the function every row's init and
  its `LFG_LIST_SEARCH_RESULT_UPDATED` call. Our parts are child frames we own, kept in a side table by
  row, never fields on the game's frames, so a pooled row picks them up again on its next update.
- The game's role display under the squares is faded with SetAlpha, never hidden, and a filtered row is
  dimmed with SetAlpha: the list's data provider is the game's, and rows are never removed from it.
- The filters and the search live in the panel, not on the game's window: Forever's Browse screen already
  has its own Players and Groups Need role filters between its dropdowns and its list (seen in game
  2026-11-16), so there is no room there.
- Apply uses `UIPanelButtonTemplate` so it matches the game's Send Message and Group Invite beside it.
- The panel follows the game's tab with HookScript on `LFGBrowseFrame` and `LFGListingFrame`, and the
  picked group with a post-hook on `LFGBrowseFrame:UpdateButtonState`, which the game calls on every
  selection change.
- There is no Whisper button of ours: the game's Send Message is beside Apply, and opening chat from
  addon code would taint the chat box.
- The game's finder is load-on-demand, so everything waits for it with `EventUtil.ContinueOnAddOnLoaded`.
- The Dungeon Journal's Find Group stays hidden: opening the game's finder from addon code taints its
  panel layout (CONTRIBUTING), and the module no longer has a window of its own (`ns.OpenGroupFinder`).
- Set My Role uses `UnitSetRole`, as the game's own Listing role dropdown does. Its restrictions are not
  documented beyond `HasRestrictions`; it waits for combat to end and only sets a role that differs.
- `1 I` carries the leader's pick because the game's invite carries no role. An older version drops it as
  malformed, and the applicant's own applied or saved role is used instead.
- A party's applicants are not in the protocol: each player applies alone.
- Ask to Join and the invite whisper are sent with `C_ChatInfo.SendChatMessage` from the button's click,
  never by opening the chat box: an addon filling the chat box taints it.
- Placeholders are `%class%` (in your client's language, lower case), `%level%`, `%spec%` (the BiS
  List's spec, short), `%role%` (the roles you apply as), `%score%` (your Gear Score) and `%dungeon%`.
  A line over 255 letters, or one during chat lockdown, is not sent and chat says why.
- The Whispers list has no "where is this player": a /who from addon code can open the game's Who
  list from addon code, which taints it.
- The panel redraws once per frame however many events ask (`Panel.Refresh` queues `Draw`): a search,
  a card and a selection change often arrive together.
- Whispers you receive are kept only for the session and only while the module is on; a whisper the
  game hides during an encounter is skipped.
- Inviting does not lower Looking For: an invite can be ignored. The spot is held while the invite is
  out (`Group.Open`), and the count drops when the player shows up in your party.
- The leader's name may not be readable on the first roster update after you join, so Set My Role tries
  again on the next few (`JOIN_TRIES`).
- Custom chat channels are split per realm on Forever, so there is no channel network: a player's
  own search in Forever's finder is the discovery, and only the players they look at or apply to are
  whispered.
- Its own prefix: the BiS List's inspect whisper and the Gear Score's share answer a unit you
  inspect or your group, while a card goes to a stranger from a listing and carries dungeon kills and
  quests they do not.
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
- An activity finds its Journal dungeon by its name, else a dungeon's other names (`listedAs`, Dire
  Maul's Warpwood Quarter, Capital Gardens and Gordok Commons), else the longest dungeon name it starts
  with, else the one dungeon whose name starts with it, else the one dungeon on its instance. Dire Maul's
  wings share one instance and one activity, so none of those can pick a wing for an activity named
  just Dire Maul: the wing marked `listsInstance` (North, the Tribute runs most groups list) takes
  the instance's own name, in the client's language.
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
  the client's language, as the Journal's names do outside English, so both are compared without
  spaces and ASCII punctuation only: the letters of other alphabets are kept.
- Every table that grows with other players is bounded: the queue, pings, applications, applicants,
  kept cards, senders, askers, names whispered and leaders asked.
- `C_LFGList.GetAvailableCategories`, `GetAvailableActivities` and `GetSearchResultMemberCounts` are not
  in the generated API docs, but the game's own Forever finder calls them
  (`Blizzard_LFGVanilla_Browse.lua`, `Blizzard_LFGVanilla_ParentFrame.lua`), and Group Finder Roles reads
  the member counts too.
- The kills on a row are the leader's own boss kills in that dungeon, not how far the group has got:
  a card carries no run progress yet.
- A listed leader answers with one `L`, the card and the group together, not two whispers: answers are
  capped to keep the send rate free, and an answer cut there looks like a leader without Naowh Forever.
- Invite is `C_PartyInfo.InviteUnit` by the applicant's name; the game asks for confirmation itself when
  inviting would turn the party into a raid.
- Only the current leader (or a solo player) answers card requests, takes applications, and sees and
  acts on its applicants (`Group.Answering`), even when the game also gives party members the active
  listing.
- Applicants are kept through a delist and a change of leader, as the game's own Listing tab keeps its
  state there (`Blizzard_LFGVanilla_Listing.lua` only repaints on `GROUP_ROSTER_UPDATE` and
  `PARTY_LEADER_CHANGED`). The applicant's game keeps its application for `APP_TTL` too, so the two
  agree when the listing or the lead comes back, and nobody is dropped without being told.
- Applicant records are not pooled: a row still showing one who withdrew, expired or was declined can
  never invite or decline whoever applied next, since Invite and Decline act only on a record still in
  the list.
- Every application starts uninvited, a repeated ID too: a player's IDs restart after a `/reload`, so a
  matching ID is not the same application.
- Withdrawals and expiry remove the record before notifying the window, so its count and rows describe
  the updated list.
- Withdrawing an unsent application removes it from the send queue. Expired applications and card
  requests leave the queue too, so ending chat lockdown cannot send an already cancelled request.
- A full queue keeps a sent application or an applicant: Withdraw returns false, and Decline says in
  chat to try again.

## Settings

| Key | Default | What it is |
| --- | --- | --- |
| `enabled` | `false` | the module |
| `autoRole` | `false` | Set My Role When I Join, its switch in `Core/Features.lua` |
| `shareScore` | `true` | your Gear Score on your card |
| `shareKills` | `true` | your boss kills for the dungeon |
| `shareQuests` | `true` | the dungeon's quests you have or need |
| `shareBis` | `true` | how many of your BiS items you have |
| `hideDeclined` | `false` | dim the groups that declined you |
| `applySound` | `false` | a sound when someone applies to your group |
| `panelOpen` | `true` | the panel beside the game's window |
| `applyNote` | `""` | the note you apply with, kept |
| `applyRoles` | `0` | the roles you apply as; 0 is the game's saved roles |
| `filters` | `false` | the filters as they were left, as plain data |
| `presets` | `false` | My filters, by name |
| `askMessage` | `"Hi! I am a %spec% %class%, level %level%. Inv please"` | Ask to Join's whisper |
| `inviteWhisper` | `false` | Whisper on Invite |
| `inviteMessage` | `"Hey! Want to join %dungeon%?"` | the whisper with an invite |

The search text lasts until a reload; every other filter is kept. The applications tally is kept
per character (`groupFinderTally` in the account settings, by GUID).

## Checking

- `lua Tools/regression/test-group-finder.lua`: loads its rules against stubs and checks it is free
  while off, the card and its messages, the whispers' guards and expiry, answering only while listed,
  names across realms, the listings, the filters and the advanced filter, asking leaders for cards, a
  listed leader's `L`, inviting as a role, applying with roles and a note, setting your role on joining,
  players on their own, saved filters and My filters, Ask to Join, the invite whisper, the whispers list,
  the probe, and the budgets.
- The panel, the strip and the row parts have no offline test: check them in game.
- In game: `/nf groupfinder probe`, and `/nf groupfinder ping <name>` between two players with the
  Group Finder on; the one pinged needs a listing up in the game's Group Finder.
