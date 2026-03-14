package.path = table.concat({
    "?.lua",
    "?/init.lua",
    "./?.lua",
    "./?/init.lua",
}, ";") .. ";" .. (package.path or "")

require("tests.cdm.test_spell_logic")
