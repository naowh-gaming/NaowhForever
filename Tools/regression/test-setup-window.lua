-- Tailor my setup's window on stub frames: the welcome, the question tiles and the setup. From
-- the repo root: lua5.1 Tools/regression/test-setup-window.lua
local checks = 0
local function check(label, ok) assert(ok, label); checks = checks + 1 end

local function Noop() end
local META = { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return Noop end end }
local made = {}

local function Frame()
    local f = setmetatable({ shown = true, scripts = {} }, META)
    made[#made + 1] = f
    local function Children(self, script)
        for _, c in ipairs(made) do
            if c.parent == self and c.shown then
                if c.scripts[script] then c.scripts[script](c) end
                c.Spread(c, script)
            end
        end
    end
    f.Spread = Children
    function f:Show()
        local was = self.shown
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
        if not was then Children(self, "OnShow") end
    end
    function f:Hide()
        local was = self.shown
        self.shown = false
        if was and self.scripts.OnHide then self.scripts.OnHide(self) end
        if was then Children(self, "OnHide") end
    end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetShown(v) if v then self:Show() else self:Hide() end end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:SetTextColor(r, g, b) self.color = { r, g, b } end
    function f:GetWidth() return self.w or 400 end
    function f:SetWidth(w) self.w = w end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetHeight(h) self.h = h end
    function f:GetStringHeight() return 14 end
    function f:GetStringWidth() return 100 end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:HookScript(k, fn)
        local old = self.scripts[k]
        self.scripts[k] = function(...) if old then old(...) end fn(...) end
    end
    function f:RegisterEvent(e)
        local events = rawget(self, "registered") or {}
        events[e] = true
        rawset(self, "registered", events)
    end
    function f:UnregisterAllEvents() rawset(self, "registered", {}) end
    function f:CreateTexture() local tx = Frame(); tx.parent = self; return tx end
    function f:CreateAnimationGroup()
        local owner = self
        local group = setmetatable({ plays = 0 }, META)
        function group.CreateAnimation() return setmetatable({}, META) end
        function group.Play() group.plays = group.plays + 1; owner.played = (owner.played or 0) + 1 end
        return group
    end
    function f:SetTexture(path) self.texture = path end
    function f:EnableMouse(on) self.mouse = on end
    return f
end

local T = { fg = { r = 1, g = 1, b = 1 }, muted = { r = 0.5, g = 0.5, b = 0.5 }, accent = { r = 0, g = 0.5, b = 1 },
    accentSoft = { r = 0.3, g = 0.7, b = 1 }, line = { r = 0.2, g = 0.2, b = 0.2 }, bg = {}, panel = {} }
local s = { combat = false, applied = nil, reloadAsked = nil, printed = nil, account = {} }
local buttons, toggles, fonts = {}, {}, {}

local plan = {
    { id = "xpBar", name = "XP Bar", theme = "Questing and Leveling", now = true, suggest = false, on = true,
      why = "You picked a clean screen.", mine = true },
    { id = "talentPoints", name = "Talent Points", theme = "Questing and Leveling", now = true, suggest = true,
      on = true, why = "Stays as you have it." },
    { id = "pvp", name = "PvP", theme = "PvP", now = false, suggest = true, on = true, why = "You play PvP.",
      module = true, loaded = false },
}

local Setup = {
    QUESTIONS = {
        { id = "amount", title = "How much?", one = true, default = "helpful", hint = "You can change it.",
          answers = { { "purist", "I'm a purist", "The game as it is.", "pure" },
              { "essentials", "Just the essentials", "Close to the game.", "ess" },
              { "helpful", "A helpful amount", "Add what fits.", "help" } } },
        { id = "addons", title = "Other addons?", hint = "Pick as many as you like.",
          answers = { { "guide", "A quest guide", "Leads me.", "g" }, { "threat", "A threat meter", "Shows threat.", "t" },
              { "none", "None of these", "Neither.", "n", none = true } } },
    },
    THEME_ICONS = { ["Questing and Leveling"] = "q", PvP = "p" },
    Detected = function() return { threat = "Omen" } end,
    Skips = function(answers) return answers.amount == "purist" end,
    Context = function() return {} end,
}
function Setup.Plan(answers)
    s.answers = answers
    local out = {}
    for i, e in ipairs(plan) do
        out[i] = {}
        for k, v in pairs(e) do out[i][k] = v end
    end
    return out
end
function Setup.Toggle(entries, id, on)
    for _, e in ipairs(entries) do
        if e.id == id then e.on = on end
    end
end
function Setup.Differs(e)
    return e.on ~= e.now or (e.idle and not e.on)
end
function Setup.Counts(entries)
    local on, off, stay = 0, 0, 0
    for _, e in ipairs(entries) do
        if e.on == e.now then stay = stay + 1 elseif e.on then on = on + 1 else off = off + 1 end
    end
    return on, off, stay
end
function Setup.NeedsReload(entries)
    for _, e in ipairs(entries) do
        if e.module and e.on ~= e.now and (not e.on or not e.loaded) then return true end
    end
    return false
end
function Setup.Apply(entries)
    s.applied = entries
    return Setup.NeedsReload(entries)
end
function Setup.ForCharacter(on)
    s.modeSet = (s.modeSet or 0) + 1
    s.forCharacter = on
end

local Parts = {}
local ns = { MEDIA = dofile("Tools/regression/core_media.lua"),
    THEME = T, Setup = Setup, UI = {},
    Shared = { Style = { CONTENT_INSET = 22, WINDOW_PAD = 12, WINDOW_HEADER = 52, RED_RGB = { r = 1, g = 0, b = 0 },
        TIP_RGB = { r = 1, g = 0.8, b = 0.5 }, LOOK_CODE = "|cff66d9ef", LOGO = "logo", BORDER_RGB = { r = 0, g = 0, b = 0 } },
        Parts = Parts },
    Font = function(parent)
        local f = Frame()
        f.parent = parent
        fonts[#fonts + 1] = f
        return f
    end,
    Solid = function() return Frame() end,
    Hairline = Noop,
    Border = function(f)
        local edge = {}
        function edge.SetColor(_, r, g, b) f.edgeColor = { r, g, b } end
        return edge
    end,
    Print = function(msg) s.printed = msg end,
    AccountSettings = function() return s.account end,
    ConfirmReload = function(msg) s.reloadAsked = msg end,
    ShowCopyLine = function(title, text) s.copied = { title = title, text = text } end,
    LINKS = { { "Discord", "discord", function() return "https://discord.gg/x" end },
        { "GitHub", "github", function() return "https://github.com/x" end } },
    LINK_ICONS = "Interface\\AddOns\\NaowhForever\\Core\\Media\\Links\\",
    VersionText = function() return "v1.0.6" end,
    StashOptionsWindow = function() s.optionsClosed = (s.optionsClosed or 0) + 1 end,
    -- Core's ns.Color for a color table: its |cffRRGGBB prefix, or text wrapped in it.
    Color = function(c, text)
        local function Byte(v) return math.floor(v * 255 + 0.5) end
        local prefix = ("|cff%02x%02x%02x"):format(Byte(c.r), Byte(c.g), Byte(c.b))
        if text == nil then return prefix end
        return prefix .. text .. "|r"
    end,
}
function ns.Button(parent, text, _, _, onClick)
    local b = Frame()
    b.parent = parent
    b.label = Frame()
    b.label.text = text
    b._onClick = onClick
    b.Click = function() b._onClick() end
    buttons[#buttons + 1] = b
    return b
end
function ns.AccentBorder(b) b.accent = true; return b end
function ns.SetButtonText(b, text) b.label.text = text end
function Parts.Window()
    local w = Frame()
    w.shown = false
    w.backdrop = { Paint = Noop }
    return w
end
function Parts.TitleBar(w, title)
    w.title = Frame()
    w.title.text = title
    w.subtitle = Frame()
    w.logo = Frame()
    w.logo.icon = Frame()
end
function Parts.IconButton(parent, onClick, texture, _, tip)
    local b = Frame()
    b.parent, b.tip, b.Click = parent, tip, onClick
    b.icon = Frame()
    b.icon.texture = texture
    return b
end
function Parts.Pill(parent, _, color)
    local p = Frame()
    p.parent, p.color, p.pillText = parent, color, ""
    return p
end
function Parts.SetPill(p, text) p.pillText = text end
function Parts.ColorPill(p, color) p.color = color end
function Parts.Link(parent, onClick)
    local l = Frame()
    l.parent = parent
    l.Click = onClick
    return l
end
function Parts.SetLink(l, text) l.text = text end
function ns.UI.SlimScroll() return Frame() end
function ns.UI.BuildToggleControl(parent, _, get, set)
    local t = Frame()
    t.parent = parent
    t._get, t._set = get, set
    t._refreshValue = function() t.on = get() end
    t._refreshValue()
    t.Click = function() set(not get()) end
    toggles[#toggles + 1] = t
    return t
end

local env = setmetatable({ _G = { NaowhForever = ns }, CreateFrame = function(_, _, parent)
        local f = Frame()
        f.parent = parent
        return f
    end, InCombatLockdown = function() return s.combat end, UnitName = function() return "Die Dudu" end },
    { __index = _G })
local chunk = assert(loadfile("Core/Onboarding/SetupWindow.lua"))
setfenv(chunk, env)
chunk()

local function Shown(f)
    while f do
        if not f.shown then return false end
        f = f.parent
    end
    return true
end
local function Find(label)
    for i = #buttons, 1, -1 do
        if buttons[i].label.text == label and Shown(buttons[i]) then return buttons[i] end
    end
end
local function Said(text)
    for _, f in ipairs(fonts) do
        if f.text == text and Shown(f) then return f end
    end
end
local function Saying(part)
    for _, f in ipairs(fonts) do
        if type(f.text) == "string" and f.text:find(part, 1, true) and Shown(f) then return f end
    end
end
local function Link(text)
    for _, f in ipairs(made) do
        if f.text == text and f.Click and Shown(f) then return f end
    end
end
local function Tile(label)
    for _, f in ipairs(made) do
        if f.name and f.name.text == label and f.onPick and Shown(f) then return f end
    end
end
local function Side(name)
    for _, f in ipairs(made) do
        if f.key and f.name and f.name.text == name and Shown(f) then return f end
    end
end
local function Pills()
    local out = {}
    for _, stat in ipairs(Side("Changes").parent.parent.stats) do
        if Shown(stat) then out[#out + 1] = stat.value.text .. " " .. stat.label.text end
    end
    return table.concat(out, ",")
end
local function RowOf(name)
    for _, f in ipairs(made) do
        if f.entry and f.name and f.name.text == name and Shown(f) then return f end
    end
end
local function Tip(tip)
    for _, f in ipairs(made) do
        if f.tip == tip and f.Click and Shown(f) then return f end
    end
end
local function Clicked(f) f.scripts.OnClick(f) end

ns.ShowSetup()
check("opening it closes the options window", s.optionsClosed == 1)
check("it opens on the welcome", Saying("One addon") and Saying("to rule") and Saying("them all.")
    and Said("Welcome, and thank you for joining us") ~= nil)
check("the thanks: a small, dedicated team with a lot of passion", Saying("small, dedicated team with")
    and Saying("a lot of passion"))
check("the welcome has its own start, no footer", Find("Let's start") and Find("Back") == nil)
check("it points to the website", Said("New here? Every feature is shown on our website:") ~= nil)
local sign
for _, f in ipairs(made) do if f.dots then sign = f end end
check("the infinity sign animates while the welcome shows", sign and sign.scripts.OnUpdate ~= nil
    and #sign.dots > 10)
local before = sign.dots[1].point[4]
sign.scripts.OnUpdate(sign, 0.5)
check("its glowing head travels along the loop", sign.dots[1].point[4] ~= before)
Link("naowh.gg/forever").Click()
check("the website link shows the address to copy", s.copied and s.copied.text == "https://naowh.gg/forever/")
local window = Find("Let's start").parent.parent
check("the title says what this is, and its logo opens nothing", window.title.text == "Naowh Forever: Onboarding"
    and window.logo.mouse == false)
check("the start button points on", Find("Let's start").arrow.texture:find("next.tga", 1, true) ~= nil)
check("the version sits at the bottom right", Said("v1.0.6") ~= nil)
Tip("Discord").Click()
check("our socials at the bottom left, each showing its address", Tip("GitHub") ~= nil
    and s.copied.text == "https://discord.gg/x")
window.scripts.OnHide(window)
check("the whole UI hidden with it is not a close: not seen yet", s.account.onboardingSeen == nil
    and s.account.welcomeSeen == nil)
Link("or keep my setup as it is").Click()
check("keep my setup as it is: the window closes", not window.shown)
check("closed: the onboarding is seen, so it never opens by itself again", s.account.onboardingSeen == true
    and s.account.welcomeSeen == true)
check("opened as usual: for every character, welcomed as before", s.modeSet == 1 and s.forCharacter == nil
    and window.subtitle.text == "Welcome")

ns.ShowSetup(true)
check("opened for this character: the setup is told, and the welcome says whose it is", s.modeSet == 2
    and s.forCharacter == true and window.shown and window.subtitle.text == "Just for Die Dudu")
Link("or keep my setup as it is").Click()
check("closed from there: still seen", not window.shown and s.account.onboardingSeen == true)

ns.ShowSetup()
check("opened as usual again: back to every character", s.modeSet == 3 and s.forCharacter == nil
    and window.subtitle.text == "Welcome")
Find("Let's start").Click()
check("past the welcome the animation stops", sign.scripts.OnUpdate == nil)
local essentials, helpful = Tile("Just the essentials"), Tile("A helpful amount")
check("the first question: tiles with a line about the player and an icon", essentials and essentials.blurb.text
    == "Close to the game." and essentials.icon.tex ~= nil)
local function Ours(texture, name)
    return texture:find("NaowhForever", 1, true) and texture:find("Setup", 1, true)
        and texture:sub(-#name - 5) == "\\" .. name .. ".tga"
end
check("each tile draws our own icon for its answer", Ours(essentials.icon.tex.texture, "ess")
    and Ours(helpful.icon.tex.texture, "help"))
local first, last = Tile("I'm a purist"), Tile("A helpful amount")
check("the answers sit as one row of cards, centred in the window", first.point[5] == last.point[5]
    and math.abs(first.point[4] - (780 - (last.point[4] + last.w))) < 0.01 and first.w == last.w)
check("the default answer starts picked, with its check", helpful.on and helpful.check.shown
    and not essentials.check.shown)
check("Back is there, to the welcome", Find("Back") ~= nil)
check("Back and Next carry arrows", Find("Back").arrow.texture:find("back.tga", 1, true)
    and Find("Next").arrow.texture:find("next.tga", 1, true))
Clicked(essentials)
check("a pick glows on the card and pops its check", essentials.glow and essentials.glow.plays == 1
    and essentials.check.pop and essentials.check.pop.plays == 1)
check("picking another answer moves the check", essentials.check.shown and not helpful.check.shown)
local question = essentials.parent
local fades = question.fadeIn and question.fadeIn.plays or 0
Find("Next").Click()
check("each new step fades in", question.fadeIn.plays == fades + 1)
local threat, none, guide = Tile("A threat meter"), Tile("None of these"), Tile("A quest guide")
check("an addon found in the game is ticked, saying which one", threat and threat.on
    and threat.blurb.text == "We found Omen." and guide.blurb.text == "Leads me." and Said("1 picked") ~= nil)
Clicked(none)
check("None of these clears the others", none.on and not threat.on)
Clicked(guide)
check("and another clears None of these", guide.on and not none.on)
Clicked(guide)
check("nothing picked: it says so", Said("Pick at least one.") ~= nil)
Find("See My Setup").Click()
check("Next waits until something is picked", Tile("None of these") ~= nil)
Find("Back").Click()
Clicked(Tile("I'm a purist"))
check("a purist goes straight to the setup", Find("See My Setup") ~= nil)
Find("See My Setup").Click()
check("the setup, with the other questions skipped", Side("Changes") ~= nil and s.answers.amount == "purist")
Find("Back").Click()
check("Back from a purist's setup returns to the first question", Tile("I'm a purist") ~= nil
    and Tile("I'm a purist").on)
Clicked(Tile("A helpful amount"))
Find("Back").Click()
check("Back on the first question returns to the welcome", Find("Let's start") ~= nil)
Find("Let's start").Click()
Find("Next").Click()
Link("Skip this question").Click()
check("skip puts the question back to what was found, and goes on", s.answers.addons.threat == true
    and s.answers.addons.guide == nil)

check("the setup's counts at the foot of the sidebar", Pills() == "1 turn on,0 turn off,2 stay")
check("Apply carries a check", Find("Apply and Reload").arrow.texture:find("check.tga", 1, true) ~= nil)
local pvpRow = RowOf("PvP")
check("each row says what happens as a pill, in its color", pvpRow.status.pillText == "Turns on"
    and pvpRow.status.color == T.accent and pvpRow.stripe.shown)
check("a row the player set is marked in gold", RowOf("XP Bar").stripe.shown
    and RowOf("XP Bar").status.pillText == "Stays on")
check("themes with changes are marked in the sidebar", Side("PvP").dot.shown)
local changes = Side("Changes")
check("the sections show our own icons", Ours(changes.icon.texture, "changes") and Ours(Side("PvP").icon.texture, "p"))
check("its sections down the side: Changes first and picked, then each theme", changes and changes.lit.shown
    and Side("Questing and Leveling").count.text == "2/2" and Side("PvP").count.text == "1/1")
local heads = {}
for _, f in ipairs(made) do
    if f.rule and f.icon and f.name and Shown(f) and f.name.text then heads[#heads + 1] = f.name.text end
end
check("Changes groups its rows under their themes", table.concat(heads, ",") == "Questing and Leveling,PvP")
check("Changes lists what turns on, and what the player set themselves", Saying("You play PvP.")
    and Saying("You set this; we'd suggest off."))
check("no All On or All Off under Changes", Find("All On") == nil)
check("a module that is not loaded: Apply and Reload", Find("Apply and Reload") ~= nil)

toggles[2].Click()
check("a switch flipped glows on its row", toggles[2].parent and toggles[2].parent.glow
    and toggles[2].parent.glow.plays == 1)
check("a correction updates the counts", Pills() == "0 turn on,0 turn off,3 stay")
Clicked(RowOf("PvP"))
check("clicking anywhere on a row flips it", Pills() == "1 turn on,0 turn off,2 stay")
Clicked(RowOf("PvP"))
check("and the button: nothing to reload", Find("Apply") ~= nil)
Find("Apply").Click()
check("nothing differs: Apply just closes, writing nothing", s.applied == nil)

ns.ShowSetup()
Find("Let's start").Click()
Find("Next").Click()
Find("See My Setup").Click()
Clicked(Side("Questing and Leveling"))
check("a theme lists all its switches, with how many are on", Said("2 of 2 on.") ~= nil and Find("All On") ~= nil)
Find("All Off").Click()
check("All Off turns the theme off", Said("0 of 2 on.") ~= nil and Side("Questing and Leveling").count.text == "0/2")
Find("All On").Click()
check("All On turns it back on", Said("2 of 2 on.") ~= nil)

s.combat = true
Find("Apply and Reload").Click()
check("in combat: nothing is applied", s.applied == nil and Said("Apply after your fight.") ~= nil)
s.combat = false
Find("Apply and Reload").Click()
check("applied: the entries as set, the player's own value kept", s.applied and s.applied[1].on == true
    and s.applied[3].on == true)
check("a module came on that is not loaded: the reload is offered", s.reloadAsked ~= nil)

math.randomseed(20261008)
local clicks = 0
for _ = 1, 4000 do
    if not window.shown then ns.ShowSetup() end
    local targets = {}
    for _, f in ipairs(made) do
        if Shown(f) and (f.Click or f.scripts.OnClick) and f ~= window then targets[#targets + 1] = f end
    end
    local f = targets[math.random(#targets)]
    s.combat = math.random() < 0.1
    if f.Click then f.Click() else Clicked(f) end
    clicks = clicks + 1
    if window.shown then
        local pages = 0
        for _, page in ipairs({ window.welcome, window.question, window.review }) do
            if page.shown then pages = pages + 1 end
        end
        if pages ~= 1 then error("random clicks: " .. pages .. " pages shown after " .. clicks .. " clicks") end
    end
end
s.combat = false
check("4000 random clicks: always one page, never an error", clicks == 4000)

print("PASS setup window: " .. checks .. " checks")
