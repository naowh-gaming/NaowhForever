-- TalentWindows.lua: finds the open talent window (Blizzard's or EllesmereUI's) and a talent's button.
local ns = _G.NaowhForever

local Next = ns.Training.Next

local SCAN_DEPTH = 6

local classWindow = {}

local function NodeOf(button)
    if button.GetNodeID then return button:GetNodeID() end
    return button.nodeID
end

local function Scan(frame, node, depth)
    if depth > SCAN_DEPTH then return nil end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsShown() then
            if NodeOf(child) == node then return child end
            local found = Scan(child, node, depth + 1)
            if found then return found end
        end
    end
    return nil
end

local function FindInButtonPool(page, node)
    for key, value in page:EnumerateAllTalentButtons() do
        local button = value
        if type(key) == "table" then button = key end
        if type(button) == "table" and NodeOf(button) == node then return button end
    end
    return nil
end

local function BlizzardFind(page, node)
    if page.GetTalentButtonByNodeID then
        local button = page:GetTalentButtonByNodeID(node)
        if button then return button end
    end
    if page.EnumerateAllTalentButtons then
        local button = FindInButtonPool(page, node)
        if button then return button end
    end
    return Scan(page, node, 0)
end

local function FillWindow(window, outer, content, search, scan)
    window.outer = outer
    window.content = content
    window.search = search
    window.scan = scan
    return window
end

function Next.NodeOf(button)
    return NodeOf(button)
end

function Next.ClassWindow()
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if talents and talents:IsVisible() then
        return FillWindow(classWindow, PlayerSpellsFrame, talents, talents.SearchBox, false)
    end
    local ellesmere = EUI_ClassicTalents
    if ellesmere and ellesmere:IsVisible() then
        return FillWindow(classWindow, ellesmere, ellesmere, nil, true)
    end
    return nil
end

function Next.FindButton(window, node)
    if window.scan then return Scan(window.content, node, 0) end
    return BlizzardFind(window.content, node)
end

function Next.EachTalentPage(fn)
    local talents = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if talents then fn(talents) end
    if EUI_ClassicTalents then fn(EUI_ClassicTalents) end
end
