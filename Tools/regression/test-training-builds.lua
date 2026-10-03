-- Training Planner talent builds: sharing them as text and saving your own. An imported
-- string comes from another player, so everything it says is checked against the class tree.
local f = assert(io.open(arg[1] or "Training/NaowhForever_Training.lua", "rb"))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local function Slice(a, b)
    local first = assert(source:find(a, 1, true))
    return source:sub(first, assert(source:find(b, first + #a, true)) - 1)
end

-- A mage tree of four nodes over two rows, and one Naowh build. node = { spell, ranks, row }.
local TREE = { [8] = {
    talents = { [11] = { 1001, 3, 2 }, [12] = { 1002, 1, 1 }, [13] = { 1003, 5, 1 }, [14] = { 1004, 2, 2 } },
    { name = "Fire Leveling", spec = "Fire", points = { 13, 13, 12, 11 } },
} }
-- A warrior tree, so a mage node in a warrior build can be caught.
TREE[1] = { talents = { [21] = { 2001, 5, 1 } } }

local function Fixture(o)
    o = o or {}
    local account, printed, changes = {}, {}, 0
    -- A stand-in codec: what goes into the payload and what comes back out is the point here.
    local vault = {}
    local env = {
        ns = {
            TrainingBuilds = TREE,
            Print = function(m) printed[#printed + 1] = m end,
            Confirm = function(_, yes) yes() end,
        },
        Account = function(key)
            account[key] = account[key] or {}
            return account[key]
        end,
        Changed = function() changes = changes + 1 end,
        UnitClass = function() return "Mage", "MAGE", 8 end,
        GetClassInfo = function(id) return ({ [1] = "Warrior", [8] = "Mage" })[id] end,
        C_ClassTalents = { GetActiveConfigID = function() return o.config end },
        C_Traits = { GetNodeInfo = function(_, node) return { activeRank = (o.ranks or {})[node] or 0 } end },
        LibStub = function(name)
            if name == "LibSerialize" then
                return {
                    Serialize = function(_, v)
                        vault[#vault + 1] = v
                        return "S" .. #vault
                    end,
                    Deserialize = function(_, str)
                        local k = tonumber(tostring(str):match("^S(%d+)$"))
                        if not (k and vault[k]) then return false, "bad string" end
                        return true, vault[k]
                    end,
                }
            end
            local same = function(_, v) return v end
            return { CompressDeflate = same, DecompressDeflate = same, EncodeForPrint = same, DecodeForPrint = same }
        end,
    }
    setmetatable(env, { __index = _G })
    local code = "local Training = {}\n" .. Slice("local BUILD_PREFIX", "-------------------------------------------------------------------------------\n--  At the trainer")
        .. "\nreturn Training"
    local chunk = assert(loadstring(code)); setfenv(chunk, env)
    local training = chunk()
    -- A share string as another player's copy of the addon would write it.
    local function Pack(data)
        vault[#vault + 1] = data
        return "!NFB1!S" .. #vault
    end
    return { T = training, Pack = Pack, Saved = function(class) return (account.trainingBuilds or {})[class] or {} end,
        Printed = printed, Changes = function() return changes end }
end

local count = 0
local function Case(name, fn) fn(); count = count + 1; print("PASS " .. name) end

local function Import(t, text)
    local got
    t.T.ImportBuild(text, function(class, index) got = { class, index } end)
    return got
end

Case("an exported build imports as a saved build of its class, shown after Naowh's", function()
    local t = Fixture()
    local text = t.T.ExportBuild(8, TREE[8][1])
    assert(text:sub(1, 6) == "!NFB1!", text)
    local got = Import(t, text)
    assert(got and got[1] == 8 and got[2] == 2, "onAdded")
    local list = t.T.Builds(8)
    assert(#list == 2 and list[2].saved and list[2].name == "Fire Leveling", "listed")
    assert(table.concat(list[2].points, " ") == "13 13 12 11", table.concat(list[2].points, " "))
end)

Case("strings that are not a build, or break the tree, are turned away", function()
    local t = Fixture()
    local bad = {
        "hello",
        "!NBIS1!S1",
        t.Pack({ v = 2, class = 8, points = { 13 } }),
        t.Pack({ v = 1, class = 99, points = { 13 } }),
        t.Pack({ v = 1, class = 1, points = { 13 } }),
        t.Pack({ v = 1, class = 8, points = { 12, 12 } }),
        t.Pack({ v = 1, class = 8, points = {} }),
        t.Pack({ v = 1, class = 8, points = "13" }),
        t.Pack({ v = 1, class = 8, points = { "13" } }),
    }
    local many = {}
    for i = 1, 52 do many[i] = 13 end
    bad[#bad + 1] = t.Pack({ v = 1, class = 8, points = many })
    for i, text in ipairs(bad) do
        assert(Import(t, text) == nil, "accepted bad string " .. i)
    end
    assert(#t.Saved(8) == 0 and #t.Saved(1) == 0, "nothing saved")
    assert(#t.Printed == #bad, "each one said so")
end)

Case("an imported name is cut to 40 letters and cannot carry escape codes", function()
    local t = Fixture()
    Import(t, t.Pack({ v = 1, class = 8, name = "|cffff0000" .. string.rep("x", 60), points = { 12 } }))
    local name = t.Saved(8)[1].name
    assert(name:sub(1, 2) == "||" and #name == 41, name)
    Import(t, t.Pack({ v = 1, class = 8, name = 5, spec = {}, points = { 12 } }))
    assert(t.Saved(8)[2].name == "Imported Build" and t.Saved(8)[2].spec == "Imported", "defaults")
end)

Case("saving your talents lists them row by row, each up to its ranks", function()
    local t = Fixture({ config = 1, ranks = { [11] = 2, [12] = 1, [13] = 5, [14] = 0 } })
    local class, index = t.T.SaveMyTalents("Mine")
    assert(class == 8 and index == 2, "where it went")
    local build = t.Saved(8)[1]
    assert(table.concat(build.points, " ") == "12 13 13 13 13 13 11 11", table.concat(build.points, " "))
    assert(build.name == "Mine" and build.saved, "named")
end)

Case("nothing is saved without talents or a talent config", function()
    local t = Fixture({ config = 1 })
    assert(t.T.SaveMyTalents("Mine") == nil and #t.Saved(8) == 0, "no points")
    local none = Fixture()
    assert(none.T.SaveMyTalents("Mine") == nil, "no config")
end)

Case("deleting a saved build removes only that one", function()
    local t = Fixture({ config = 1, ranks = { [12] = 1 } })
    t.T.SaveMyTalents("One")
    t.T.SaveMyTalents("Two")
    local first = t.Saved(8)[1]
    t.T.DeleteBuild(8, first)
    assert(#t.Saved(8) == 1 and t.Saved(8)[1].name == "Two", "kept the other")
    assert(#t.T.Builds(8) == 2, "Naowh's stays")
end)

print(("test-training-builds: %d cases passed"):format(count))
