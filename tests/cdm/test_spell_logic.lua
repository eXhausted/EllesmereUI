local lu = require("luaunit")

local SpellLogic = require("EllesmereUICooldownManager.EUI_CdmSpellLogic")

TestResolveInfoSpellID = {}

function TestResolveInfoSpellID:testPrefersOverrideSpellID()
    local info = {
        spellID = 10,
        overrideSpellID = 20,
        linkedSpellIDs = { 30, 40 },
    }
    lu.assertEquals(SpellLogic.ResolveInfoSpellID(info), 20)
end

function TestResolveInfoSpellID:testFallsBackToFirstLinkedSpellID()
    local info = {
        spellID = 10,
        linkedSpellIDs = { 0, false, 30, 40 },
    }
    lu.assertEquals(SpellLogic.ResolveInfoSpellID(info), 30)
end

function TestResolveInfoSpellID:testFallsBackToSpellID()
    local info = { spellID = 77 }
    lu.assertEquals(SpellLogic.ResolveInfoSpellID(info), 77)
end

function TestResolveInfoSpellID:testAppliesCorrectionMap()
    local info = { spellID = 12950 }
    local corrections = { [12950] = 85739 }
    lu.assertEquals(SpellLogic.ResolveInfoSpellID(info, corrections), 85739)
end

function TestResolveInfoSpellID:testReturnsNilForInvalidInput()
    lu.assertNil(SpellLogic.ResolveInfoSpellID(nil))
    lu.assertNil(SpellLogic.ResolveInfoSpellID({}))
    lu.assertNil(SpellLogic.ResolveInfoSpellID({ spellID = 0, overrideSpellID = 0 }))
end

TestIsTrulyPassive = {}

function TestIsTrulyPassive:testReturnsFalseForInvalidID()
    lu.assertFalse(SpellLogic.IsTrulyPassive(nil, {}))
    lu.assertFalse(SpellLogic.IsTrulyPassive(0, {}))
end

function TestIsTrulyPassive:testReturnsFalseWhenNotPassive()
    local api = {
        IsSpellPassive = function() return false end,
    }
    lu.assertFalse(SpellLogic.IsTrulyPassive(123, api))
end

function TestIsTrulyPassive:testReturnsFalseForPassiveWithBaseCooldown()
    local api = {
        IsSpellPassive = function() return true end,
        GetSpellBaseCooldown = function() return 15000 end,
        GetSpellCharges = function() return nil end,
    }
    lu.assertFalse(SpellLogic.IsTrulyPassive(123, api))
end

function TestIsTrulyPassive:testReturnsFalseForPassiveWithCharges()
    local api = {
        IsSpellPassive = function() return true end,
        GetSpellBaseCooldown = function() return 0 end,
        GetSpellCharges = function() return { maxCharges = 2 } end,
    }
    lu.assertFalse(SpellLogic.IsTrulyPassive(123, api))
end

function TestIsTrulyPassive:testReturnsTrueForPassiveWithoutCooldownOrCharges()
    local api = {
        IsSpellPassive = function() return true end,
        GetSpellBaseCooldown = function() return 0 end,
        GetSpellCharges = function() return nil end,
    }
    lu.assertTrue(SpellLogic.IsTrulyPassive(123, api))
end

TestBuildKnownSpellIDSet = {}

function TestBuildKnownSpellIDSet:testAggregatesSpellIDsAcrossAllCategories()
    local infos = {
        [1] = { spellID = 101, overrideSpellID = 0, linkedSpellIDs = { 102, 103 } },
        [2] = { spellID = 201, overrideSpellID = 202, linkedSpellIDs = { 203 } },
        [3] = { spellID = 301, linkedSpellIDs = { 302 } },
        [4] = { spellID = 401 },
    }

    local api = {
        GetCooldownViewerCategorySet = function(cat)
            if cat == 0 then return { 1 } end
            if cat == 1 then return { 2 } end
            if cat == 2 then return { 3 } end
            if cat == 3 then return { 4 } end
            return nil
        end,
        GetCooldownViewerCooldownInfo = function(cdID)
            return infos[cdID]
        end,
    }

    local known = SpellLogic.BuildKnownSpellIDSet(api, {
        isTrulyPassive = function() return false end,
    })

    for _, sid in ipairs({ 101, 102, 103, 201, 202, 203, 301, 302, 401 }) do
        lu.assertTrue(known[sid], "expected spellID in known set: " .. sid)
    end
end

function TestBuildKnownSpellIDSet:testFiltersPassivesOnlyForCooldownCategories()
    local infos = {
        [10] = { spellID = 500 }, -- cat 0
        [11] = { spellID = 600 }, -- cat 2
    }

    local api = {
        GetCooldownViewerCategorySet = function(cat)
            if cat == 0 then return { 10 } end
            if cat == 2 then return { 11 } end
            return nil
        end,
        GetCooldownViewerCooldownInfo = function(cdID)
            return infos[cdID]
        end,
    }

    local known = SpellLogic.BuildKnownSpellIDSet(api, {
        isTrulyPassive = function(sid) return sid == 500 or sid == 600 end,
    })

    lu.assertNil(known[500])   -- filtered in category 0
    lu.assertTrue(known[600])  -- not filtered in category 2
end

function TestBuildKnownSpellIDSet:testAppliesCorrectionsToPrimarySpellID()
    local api = {
        GetCooldownViewerCategorySet = function(cat)
            if cat == 0 then return { 99 } end
            return nil
        end,
        GetCooldownViewerCooldownInfo = function()
            return { spellID = 12950 }
        end,
    }

    local known = SpellLogic.BuildKnownSpellIDSet(api, {
        buffSpellIdCorrections = { [12950] = 85739 },
        isTrulyPassive = function() return false end,
    })

    lu.assertTrue(known[85739])
    lu.assertTrue(known[12950])
end

function TestBuildKnownSpellIDSet:testHandlesMissingApiSafely()
    lu.assertEquals(SpellLogic.BuildKnownSpellIDSet(nil), {})
    lu.assertEquals(SpellLogic.BuildKnownSpellIDSet({}), {})
end

os.exit(lu.LuaUnit.run())
