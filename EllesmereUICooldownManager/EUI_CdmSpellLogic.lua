-------------------------------------------------------------------------------
--  EUI_CdmSpellLogic.lua
--  Pure spell logic helpers shared by runtime and unit tests.
-------------------------------------------------------------------------------
local _, ns = ...
if type(ns) ~= "table" then
    ns = {}
end

local CDMSpellLogic = {}

function CDMSpellLogic.ResolveInfoSpellID(info, buffSpellIdCorrections)
    if not info then return nil end

    local sid
    if info.overrideSpellID and info.overrideSpellID > 0 then
        sid = info.overrideSpellID
    else
        local linked = info.linkedSpellIDs
        if linked then
            for i = 1, #linked do
                if linked[i] and linked[i] > 0 then
                    sid = linked[i]
                    break
                end
            end
        end
        if not sid and info.spellID and info.spellID > 0 then
            sid = info.spellID
        end
    end

    if not sid then return nil end
    if buffSpellIdCorrections and buffSpellIdCorrections[sid] then
        return buffSpellIdCorrections[sid]
    end
    return sid
end

function CDMSpellLogic.IsTrulyPassive(sid, spellApi)
    if not sid or sid <= 0 then return false end
    if type(spellApi) ~= "table" then return false end

    if not (spellApi.IsSpellPassive and spellApi.IsSpellPassive(sid)) then
        return false
    end

    local baseCd = spellApi.GetSpellBaseCooldown and spellApi.GetSpellBaseCooldown(sid)
    if baseCd and baseCd > 0 then
        return false
    end

    local chargeInfo = spellApi.GetSpellCharges and spellApi.GetSpellCharges(sid)
    if chargeInfo and chargeInfo.maxCharges and chargeInfo.maxCharges > 0 then
        return false
    end

    return true
end

function CDMSpellLogic.BuildKnownSpellIDSet(cooldownViewerApi, opts)
    local known = {}
    opts = opts or {}

    if type(cooldownViewerApi) ~= "table"
            or not cooldownViewerApi.GetCooldownViewerCategorySet
            or not cooldownViewerApi.GetCooldownViewerCooldownInfo then
        return known
    end

    for cat = 0, 3 do
        local knownIDs = cooldownViewerApi.GetCooldownViewerCategorySet(cat, false)
        if knownIDs then
            local filterPassives = opts.filterPassivesByCategory ~= false and (cat == 0 or cat == 1)

            for _, cdID in ipairs(knownIDs) do
                local info = cooldownViewerApi.GetCooldownViewerCooldownInfo(cdID)
                if info then
                    local primarySid = CDMSpellLogic.ResolveInfoSpellID(info, opts.buffSpellIdCorrections)
                    local skip = filterPassives and primarySid and opts.isTrulyPassive and opts.isTrulyPassive(primarySid)

                    if not skip then
                        if primarySid and primarySid > 0 then
                            known[primarySid] = true
                        end
                        if info.spellID and info.spellID > 0 then
                            known[info.spellID] = true
                        end
                        if info.overrideSpellID and info.overrideSpellID > 0 then
                            known[info.overrideSpellID] = true
                        end
                        if info.linkedSpellIDs then
                            for _, lsid in ipairs(info.linkedSpellIDs) do
                                if lsid and lsid > 0 then
                                    known[lsid] = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return known
end

ns.CDMSpellLogic = CDMSpellLogic

return CDMSpellLogic
