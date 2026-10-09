-- NaowhForever_Verify.lua: the signature check for personalized Reminder Packs.
local ns = _G.NaowhForever
if not ns then return end

local band, bor, bxor2, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
local lshift, rshift = bit.lshift, bit.rshift
local floor = math.floor
local byte, char, format = string.byte, string.char, string.format

local PACK_PUBLIC_KEY_N_HEX =
    "ac6168efc5bbff818d6e31f787d91a3cba158018b1f7b5fb588503f08857d2a502c3ae9ff4b7151d010a8f127f219f8f25" ..
    "938f609850838b22f254d8e5cedd0efc920e8db6153ab2f787344ab108b26fea227464ff101899464b6cc6370339c9e7c3" ..
    "20576d136f455e638614a653b4dfb67349f1c1952661f66a78e60ca640139a504c6401e06ae838618d906ce7f55286c158" ..
    "e8c69c47b8190f2c2a696afbd32b0be40a9eacb7160ba36a8e86937eeb92af306a76dc4f1472e6b976bcf111747eb27e60" ..
    "4037c439ac550aa1f39aee10d34bba36a955dc52be94282baa1a9d66c61f399eec97e74eea655f55861aff5c64860cd792" ..
    "ede63d8914b999d0862333"
local PACK_PUBLIC_KEY_E_HEX = "10001"
local BASE = 65536
local LIMB_BITS = 16
local HEX_PER_LIMB = 4
local BYTE_BASE = 256
local SHA256_DIGESTINFO_PREFIX_HEX = '3031300d060960864801650304020105000420'
local BITS_PER_BYTE = 8
local PAD_FRAME_BYTES = 3
local MIN_PAD_BYTES = 8
local LICENSE_FORMAT_VERSION = 1
local SIGNATURE_BYTES = 256
local HEADER_BYTES = 2
local EXPIRY_BYTES = 4

local function Bxor3(a, b, c) return bxor2(bxor2(a, b), c) end

local SHA_K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function Rotr(x, n)
    return bor(rshift(x, n), lshift(x, 32 - n))
end

local function BytesToWord(s, i)
    local a, b, c, d = byte(s, i), byte(s, i + 1), byte(s, i + 2), byte(s, i + 3)
    return a * 0x1000000 + b * 0x10000 + c * 0x100 + d
end

local function WordToBytes(w)
    local a = rshift(w, 24)
    local b = band(rshift(w, 16), 0xFF)
    local c = band(rshift(w, 8), 0xFF)
    local d = band(w, 0xFF)
    return char(a, b, c, d)
end

local function Add32(a, b, c, d, e)
    local s = a + b + (c or 0) + (d or 0) + (e or 0)
    return band(s, 0xFFFFFFFF)
end

local function Sha256Pad(msg)
    local len = #msg
    local bitLenHi = floor(len / 0x20000000)
    local bitLenLo = band(len * 8, 0xFFFFFFFF)
    local padLen = (56 - ((len + 1) % 64)) % 64
    return msg .. char(0x80) .. string.rep(char(0), padLen)
        .. WordToBytes(bitLenHi) .. WordToBytes(bitLenLo)
end

local function Sha256Digest(msg)
    msg = Sha256Pad(msg)
    local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

    local w = {}
    for blockStart = 1, #msg, 64 do
        for t = 0, 15 do
            w[t] = BytesToWord(msg, blockStart + t * 4)
        end
        for t = 16, 63 do
            local s0 = Bxor3(Rotr(w[t - 15], 7), Rotr(w[t - 15], 18), rshift(w[t - 15], 3))
            local s1 = Bxor3(Rotr(w[t - 2], 17), Rotr(w[t - 2], 19), rshift(w[t - 2], 10))
            w[t] = Add32(w[t - 16], s0, w[t - 7], s1)
        end

        local a, b, c, d = h0, h1, h2, h3
        local e, f, g, h = h4, h5, h6, h7

        for t = 0, 63 do
            local S1 = Bxor3(Rotr(e, 6), Rotr(e, 11), Rotr(e, 25))
            local ch = bxor2(band(e, f), band(bnot(e), g))
            local temp1 = Add32(h, S1, ch, SHA_K[t + 1], w[t])
            local S0 = Bxor3(Rotr(a, 2), Rotr(a, 13), Rotr(a, 22))
            local maj = Bxor3(band(a, b), band(a, c), band(b, c))
            local temp2 = Add32(S0, maj)

            h = g; g = f; f = e; e = Add32(d, temp1)
            d = c; c = b; b = a; a = Add32(temp1, temp2)
        end

        h0 = Add32(h0, a); h1 = Add32(h1, b); h2 = Add32(h2, c); h3 = Add32(h3, d)
        h4 = Add32(h4, e); h5 = Add32(h5, f); h6 = Add32(h6, g); h7 = Add32(h7, h)
    end

    return WordToBytes(h0) .. WordToBytes(h1) .. WordToBytes(h2) .. WordToBytes(h3)
        .. WordToBytes(h4) .. WordToBytes(h5) .. WordToBytes(h6) .. WordToBytes(h7)
end

local function BytesToHex(bin)
    local out = {}
    for i = 1, #bin do
        out[i] = format('%02x', byte(bin, i))
    end
    return table.concat(out)
end

local function BnTrim(a)
    local n = #a
    while n > 0 and a[n] == 0 do
        a[n] = nil
        n = n - 1
    end
    return a
end

local function BnFromHex(hex)
    hex = hex:gsub('^0x', ''):gsub('%s', '')
    if #hex % 2 == 1 then hex = '0' .. hex end
    local a = {}
    local i = #hex
    local limbIdx = 1
    while i > 0 do
        local start = i - (HEX_PER_LIMB - 1)
        local chunk = (start < 1) and hex:sub(1, i) or hex:sub(start, i)
        a[limbIdx] = tonumber(chunk, 16)
        limbIdx = limbIdx + 1
        i = i - HEX_PER_LIMB
    end
    return BnTrim(a)
end

local function BnToBytesBE(a, numBytes)
    local bytes = {}
    for i = 1, #a do
        local limb = a[i]
        bytes[#bytes + 1] = limb % BYTE_BASE
        bytes[#bytes + 1] = floor(limb / BYTE_BASE) % BYTE_BASE
    end
    while #bytes < numBytes do bytes[#bytes + 1] = 0 end
    while #bytes > numBytes do bytes[#bytes] = nil end
    local out = {}
    for i = numBytes, 1, -1 do
        out[#out + 1] = char(bytes[i])
    end
    return table.concat(out)
end

local function BnCmp(a, b)
    if #a ~= #b then return (#a < #b) and -1 or 1 end
    for i = #a, 1, -1 do
        if a[i] ~= b[i] then return (a[i] < b[i]) and -1 or 1 end
    end
    return 0
end

local function BnSub(a, b)
    local out = {}
    local borrow = 0
    for i = 1, #a do
        local x = a[i] - (b[i] or 0) - borrow
        if x < 0 then x = x + BASE; borrow = 1 else borrow = 0 end
        out[i] = x
    end
    return BnTrim(out)
end

local function BnShl1(a)
    local out = {}
    local carry = 0
    for i = 1, #a do
        local x = a[i] * 2 + carry
        if x >= BASE then out[i] = x - BASE; carry = 1 else out[i] = x; carry = 0 end
    end
    if carry == 1 then out[#a + 1] = 1 end
    return out
end

local function BnOrBit0(a)
    local out = {}
    for i = 1, #a do out[i] = a[i] end
    if #out == 0 then out[1] = 1 else out[1] = out[1] + 1 end
    return out
end

local function BnBitLength(a)
    if #a == 0 then return 0 end
    local top = a[#a]
    local bits = 0
    while top > 0 do top = floor(top / 2); bits = bits + 1 end
    return (#a - 1) * LIMB_BITS + bits
end

local function BnTestBit(a, i)
    local limbIdx = floor(i / LIMB_BITS) + 1
    local limb = a[limbIdx]
    if not limb then return false end
    local bitInLimb = i % LIMB_BITS
    return floor(limb / (2 ^ bitInLimb)) % 2 == 1
end

local function BnMulFull(a, b)
    if #a == 0 or #b == 0 then return {} end
    local out = {}
    for i = 1, #a + #b do out[i] = 0 end
    for i = 1, #a do
        local ai = a[i]
        if ai ~= 0 then
            for j = 1, #b do
                out[i + j - 1] = out[i + j - 1] + ai * b[j]
            end
        end
    end
    local carry = 0
    for i = 1, #out do
        local v = out[i] + carry
        out[i] = v % BASE
        carry = floor(v / BASE)
    end
    while carry > 0 do
        out[#out + 1] = carry % BASE
        carry = floor(carry / BASE)
    end
    return BnTrim(out)
end

local function BnMod(a, m)
    local rem = {}
    local bits = BnBitLength(a)
    for i = bits - 1, 0, -1 do
        rem = BnShl1(rem)
        if BnTestBit(a, i) then rem = BnOrBit0(rem) end
        if BnCmp(rem, m) >= 0 then rem = BnSub(rem, m) end
    end
    return rem
end

local function BnModPow(base, exp, m)
    local result = { 1 }
    local b = BnMod(base, m)
    local bits = BnBitLength(exp)
    for i = bits - 1, 0, -1 do
        result = BnMod(BnMulFull(result, result), m)
        if BnTestBit(exp, i) then
            result = BnMod(BnMulFull(result, b), m)
        end
    end
    return result
end

local function HexToBytes(hex)
    return (hex:gsub('..', function(cc) return char(tonumber(cc, 16)) end))
end

local function RsaVerify(messageBytes, signatureBytes)
    local n = BnFromHex(PACK_PUBLIC_KEY_N_HEX)
    local e = BnFromHex(PACK_PUBLIC_KEY_E_HEX)
    local s = BnFromHex(BytesToHex(signatureBytes))

    local k = math.ceil(BnBitLength(n) / BITS_PER_BYTE)
    if BnCmp(s, n) >= 0 then return false, 'signature_out_of_range' end

    local emInt = BnModPow(s, e, n)
    local em = BnToBytesBE(emInt, k)

    local hash = Sha256Digest(messageBytes)
    local t = HexToBytes(SHA256_DIGESTINFO_PREFIX_HEX) .. hash
    local psLen = k - PAD_FRAME_BYTES - #t
    if psLen < MIN_PAD_BYTES then return false, 'modulus_too_small_for_sha256' end
    local expected = '\0\1' .. string.rep('\255', psLen) .. '\0' .. t

    if em == expected then return true end
    return false, 'signature_mismatch'
end

function ns.CheckPackLicense(encoded)
    local LD = LibStub and LibStub("LibDeflate", true)
    if not LD then return false, "the serializer libraries are missing from this build" end

    local blob = LD:DecodeForPrint(encoded)
    if not blob then return false, "this pack's license is damaged (encoding)" end

    if #blob < HEADER_BYTES then return false, "this pack's license is damaged (too short)" end
    local version = byte(blob, 1)
    if version ~= LICENSE_FORMAT_VERSION then
        return false, "this pack's license needs a newer version of the addon"
    end
    local tagLen = byte(blob, 2)
    local expected = HEADER_BYTES + tagLen + EXPIRY_BYTES + SIGNATURE_BYTES
    if #blob ~= expected then return false, "this pack's license is damaged (size)" end

    local tagEnd = HEADER_BYTES + tagLen
    local expiryEnd = tagEnd + EXPIRY_BYTES
    local battletag = blob:sub(HEADER_BYTES + 1, tagEnd)
    local expiryBytes = blob:sub(tagEnd + 1, expiryEnd)
    local signature = blob:sub(expiryEnd + 1, expiryEnd + SIGNATURE_BYTES)
    local expiry = BytesToWord(expiryBytes, 1)

    local message = battletag .. expiryBytes
    local sigOk, sigErr = RsaVerify(message, signature)
    if not sigOk then return false, "this pack's license signature is invalid (" .. tostring(sigErr) .. ")" end

    if time() > expiry then
        return false, "this pack's link to your account expired -- get a fresh one from naowh.gg"
    end

    local _, myTag = BNGetInfo()
    if not myTag or myTag == "" then
        return false, "could not read your Battle.net BattleTag to check this pack's license"
    end
    if myTag:lower() ~= battletag:lower() then
        return false, format("this pack is licensed to %s, but you are logged in to Battle.net as %s", battletag, myTag)
    end

    return true, "license_ok", battletag
end
