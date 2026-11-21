-- TalentMark.lua: the glow on the next talent, a border in its button's shape that pulses while a point is free.
local ns = _G.NaowhForever

local T = ns.THEME
local Next = ns.Training.Next

local RING_ALPHA, SHINE_ALPHA, OUTER_ALPHA, HALO_ALPHA = 1, 0.8, 0.5, 0.7
local OUTER_SCALE, FALLBACK_SCALE, HALO_SCALE = 1.14, 1.3, 1.6
local WAIT_ALPHA = 0.75
local PULSE_LOW, PULSE_TIME = 0.45, 0.7
local EDGE_W, EDGE_OUT = 2, 3
local LEVEL_ABOVE, MAX_FRAME_LEVEL = 10, 9000

local function Tint(texture, alpha)
    local color = T.accentSoft
    texture:SetDesaturated(true)
    texture:SetVertexColor(color.r, color.g, color.b, alpha)
end

local function AtlasOK(atlas)
    if type(atlas) ~= "string" then return false end
    if atlas == "" then return false end
    return C_Texture.GetAtlasInfo(atlas) ~= nil
end

local function NewLayer(mark, drawLayer, additive)
    local texture = mark:CreateTexture(nil, drawLayer)
    if additive then texture:SetBlendMode("ADD") end
    texture:SetPoint("CENTER")
    return texture
end

local function NewEdge(mark)
    local color = T.accentSoft
    local edge = mark:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(color.r, color.g, color.b, 1)
    edge:Hide()
    mark.edges[#mark.edges + 1] = edge
    return edge
end

local function Edges(mark)
    mark.edges = {}
    local top = NewEdge(mark)
    top:SetPoint("TOPLEFT", -EDGE_OUT, EDGE_OUT)
    top:SetPoint("TOPRIGHT", EDGE_OUT, EDGE_OUT)
    top:SetHeight(EDGE_W)
    local bottom = NewEdge(mark)
    bottom:SetPoint("BOTTOMLEFT", -EDGE_OUT, -EDGE_OUT)
    bottom:SetPoint("BOTTOMRIGHT", EDGE_OUT, -EDGE_OUT)
    bottom:SetHeight(EDGE_W)
    local left = NewEdge(mark)
    left:SetPoint("TOPLEFT", -EDGE_OUT, EDGE_OUT)
    left:SetPoint("BOTTOMLEFT", -EDGE_OUT, -EDGE_OUT)
    left:SetWidth(EDGE_W)
    local right = NewEdge(mark)
    right:SetPoint("TOPRIGHT", EDGE_OUT, EDGE_OUT)
    right:SetPoint("BOTTOMRIGHT", EDGE_OUT, -EDGE_OUT)
    right:SetWidth(EDGE_W)
end

local function Pulse(mark)
    local pulse = mark:CreateAnimationGroup()
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(PULSE_LOW)
    fade:SetDuration(PULSE_TIME)
    pulse:SetLooping("BOUNCE")
    return pulse
end

local function ShapeAtlas(button)
    if button.StateBorder then
        local atlas = button.StateBorder:GetAtlas()
        if AtlasOK(atlas) then return atlas end
    end
    local artSet = button.artSet
    if type(artSet) ~= "table" then return nil end
    local atlas = artSet.selectable or artSet.normal
    if AtlasOK(atlas) then return atlas end
    return nil
end

local function HaloAtlas(button)
    local artSet = button.artSet
    if type(artSet) == "table" and AtlasOK(artSet.glow) then return artSet.glow end
    if button.Glow then
        local atlas = button.Glow:GetAtlas()
        if AtlasOK(atlas) then return atlas end
    end
    return nil
end

local function ArtSize(button, art, scale)
    if art then
        local width, height = art:GetSize()
        if width and width > 0 then return width, height end
    end
    return button:GetWidth() * scale, button:GetHeight() * scale
end

local function ShapeArt(mark, button)
    local atlas = ShapeAtlas(button)
    if atlas then
        if mark.atlas ~= atlas then
            mark.atlas = atlas
            mark.ring:SetAtlas(atlas)
            mark.shine:SetAtlas(atlas)
            mark.outer:SetAtlas(atlas)
            Tint(mark.ring, RING_ALPHA)
            Tint(mark.shine, SHINE_ALPHA)
            Tint(mark.outer, OUTER_ALPHA)
        end
        local width, height = ArtSize(button, button.StateBorder, FALLBACK_SCALE)
        mark.ring:SetSize(width, height)
        mark.shine:SetSize(width, height)
        mark.outer:SetSize(width * OUTER_SCALE, height * OUTER_SCALE)
    end
    local hasShape = atlas ~= nil
    mark.ring:SetShown(hasShape)
    mark.shine:SetShown(hasShape)
    mark.outer:SetShown(hasShape)
    for _, edge in ipairs(mark.edges) do
        edge:SetShown(not hasShape)
    end
end

local function HaloArt(mark, button)
    local atlas = HaloAtlas(button)
    mark.hasHalo = atlas ~= nil
    if not atlas then return end
    if mark.haloAtlas ~= atlas then
        mark.haloAtlas = atlas
        mark.halo:SetAtlas(atlas)
        Tint(mark.halo, HALO_ALPHA)
    end
    local width, height = ArtSize(button, button.Glow, HALO_SCALE)
    mark.halo:SetSize(width, height)
end

function Next.NewMark()
    local mark = CreateFrame("Frame")
    mark:Hide()
    mark.halo = NewLayer(mark, "BACKGROUND", true)
    mark.ring = NewLayer(mark, "ARTWORK", false)
    mark.shine = NewLayer(mark, "OVERLAY", true)
    mark.outer = NewLayer(mark, "OVERLAY", true)
    Edges(mark)
    mark.pulse = Pulse(mark)
    return mark
end

function Next.PlaceMark(mark, button, ready)
    if not button then
        mark.pulse:Stop()
        mark:Hide()
        return
    end
    if mark.button ~= button then
        mark:SetParent(button)
        mark:ClearAllPoints()
        mark:SetAllPoints(button)
        mark.button = button
    end
    local level = math.min(button:GetFrameLevel() + LEVEL_ABOVE, MAX_FRAME_LEVEL)
    mark:SetFrameLevel(level)
    ShapeArt(mark, button)
    HaloArt(mark, button)
    local showHalo = ready and mark.hasHalo
    mark.halo:SetShown(showHalo)
    if ready then
        if not mark.pulse:IsPlaying() then
            mark:SetAlpha(1)
            mark.pulse:Play()
        end
    else
        mark.pulse:Stop()
        mark:SetAlpha(WAIT_ALPHA)
    end
    mark:Show()
end

function Next.ButtonFor(mark, window, node)
    local current = mark.button
    if current then
        local stillThere = current:IsVisible() and Next.NodeOf(current) == node
        if stillThere then return current end
    end
    return Next.FindButton(window, node)
end
