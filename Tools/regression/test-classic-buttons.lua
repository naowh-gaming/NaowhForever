-- Run with Lua 5.1 from the repository root: ns.Button on the Classic+ skin is the game's own panel
-- button: its art in three pieces, pressed and disabled art, its highlight glow, and gold text that
-- turns white under the mouse. Its edge shows only when a caller marks it picked. On the default
-- skin it is as it was.
local checks = 0
local function check(label, value) assert(value, label); checks = checks + 1 end

local function Read(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a"); f:close()
    return s
end

local frames
local function New(kind)
    local o = { kind = kind, points = {}, scripts = {}, events = {} }
    return setmetatable(o, { __index = function(_, k)
        return function(self, ...)
            local args = { ... }
            if k == "SetScript" then self.scripts[args[1]] = args[2]
            elseif k == "GetScript" then return self.scripts[args[1]]
            elseif k == "RegisterEvent" then self.events[args[1]] = true
            elseif k == "SetGradient" then self.gradient = { args[2], args[3] }
            elseif k == "SetColorTexture" or k == "SetTextColor" then self.color = args
            elseif k == "GetFrameLevel" then return 1
            elseif k == "GetEffectiveScale" then return 1
            elseif k == "GetObjectType" then return self.kind
            elseif k == "IsMouseOver" then return self.mouseOver
            elseif k == "IsEnabled" then return not rawget(self, "disabled")
            elseif k == "SetTexture" then self.texture = args[1]
            elseif k == "SetTexCoord" then self.coords = args
            elseif k == "SetHighlightTexture" then
                self.highlight = New("Texture")
                self.highlight.texture, self.highlight.mode = args[1], args[2]
            elseif k == "GetHighlightTexture" then return self.highlight
            elseif k == "Hide" then self.hidden = true
            elseif k == "Show" then self.hidden = false
            elseif k == "SetShown" then self.hidden = not args[1]
            elseif k == "CreateTexture" then return New("Texture")
            elseif k == "CreateFontString" then return New("FontString")
            end
        end
    end })
end

local function Load(account)
    frames = {}
    local env = setmetatable({
        NaowhForeverDB = { account = account, profiles = {}, charActive = {} },
        CreateFrame = function(kind)
            local f = New(kind)
            frames[#frames + 1] = f
            return f
        end,
        CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end,
        PixelUtil = { GetPixelToUIUnitFactor = function() return 1 end },
    }, { __index = _G })
    env._G = env
    for _, path in ipairs({ "Core/Core.lua", "Shared/Shared.lua", "Shared/Style.lua" }) do
        local chunk = assert(loadstring(Read(path), path))
        setfenv(chunk, env)
        chunk("NaowhForever", env.NaowhForever)
    end
    for _, f in ipairs(frames) do
        if f.events.ADDON_LOADED and f.scripts.OnEvent then f.scripts.OnEvent(f, "ADDON_LOADED", "NaowhForever") end
    end
    return env.NaowhForever
end


-- The default skin: the flat button, no press handling.
local ns = Load({})
local btn = ns.Button(New("Frame"), "Close", 80, 24)
check("default: no pressed look", btn.scripts.OnMouseDown == nil and rawget(btn._bg, "gradient") == nil)
check("default: the text in the theme's text colour", btn.label.color[1] == ns.THEME.fg.r)

-- Classic+.
ns = Load({ skin = "classic" })
local St = ns.Shared.Style
local art = St.CLASSIC_BUTTON_ART
btn = ns.Button(New("Frame"), "Close", 80, 24)
local function Art(file)
    for _, piece in ipairs(btn._art) do if piece.texture ~= file then return false end end
    return #btn._art == 3
end
check("the game's panel button, in three pieces", Art(art.up) and btn._bg.hidden)
check("cropped as the game's template crops them", btn._art[1].coords[2] == St.CLASSIC_BUTTON_COORDS.left[2]
    and btn._art[3].coords[1] == St.CLASSIC_BUTTON_COORDS.right[1])
check("the game's highlight glow", btn.highlight.texture == art.highlight and btn.highlight.mode == "ADD")
local accent = ns.THEME.accent
check("gold text", btn.label.color[1] == accent.r and btn.label.color[2] == accent.g)
check("no edge round it", btn._border._frame.hidden)
btn.scripts.OnEnter(btn)
check("under the mouse: white text", btn.label.color[1] == 1 and btn.label.color[3] == 1)
btn.scripts.OnMouseDown(btn)
check("pressed: the game's pressed art", Art(art.down))
btn.scripts.OnMouseUp(btn)
check("let go: back up", Art(art.up))
btn.scripts.OnLeave(btn)
check("mouse gone: gold again", btn.label.color[1] == accent.r)
btn.disabled = true
btn.scripts.OnDisable(btn)
check("disabled: the game's grey art and grey text", Art(art.disabled) and btn.label.color[1] == St.CLASSIC_DISABLED_GREY)
btn.scripts.OnMouseDown(btn)
check("a disabled button does not press", Art(art.disabled))
btn.disabled = false
btn.scripts.OnEnable(btn)
check("enabled again", Art(art.up) and btn.label.color[1] == accent.r)

-- A main action is the game's button like any other, with no edge.
ns.AccentBorder(btn)
check("a main action has no accent edge", btn._rest ~= accent and btn._border._frame.hidden)
-- The edge still marks a picked button, as callers set it, and goes again when they clear it.
btn._border:SetColor(accent.r, accent.g, accent.b, 1)
check("a picked button shows its edge", not btn._border._frame.hidden)
btn._border:SetColor(0, 0, 0, 1)
check("cleared to black, the edge goes", btn._border._frame.hidden)

print("classic buttons: " .. checks .. " checks passed")
