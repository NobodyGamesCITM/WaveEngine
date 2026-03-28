local TYPEWRITER_SPEED = 0.03
local DEFAULT_SEQUENCE = "intro"

public = {
    updateWhenPaused = true
}

local canvas     = nil
local allDialogs = nil

local PORTRAIT_MAP = {
    ["Telemaco"]    = "Portrait_Telemaco",
    ["Atenea"]      = "Portrait_Atenea",
    ["John cartel"] = "Portrait_JohnCartel",
}

local currentPortrait  = nil
local lastDisplayedChars = -1

-- ===== UTF-8 helpers =====
local function utf8charlen(byte)
    if byte < 0x80 then return 1
    elseif byte < 0xE0 then return 2
    elseif byte < 0xF0 then return 3
    else return 4 end
end

local function utf8len(str)
    local len = 0
    local pos = 1
    while pos <= #str do
        pos = pos + utf8charlen(string.byte(str, pos))
        len = len + 1
    end
    return len
end

local function utf8sub(str, nchars)
    if nchars <= 0 then return "" end
    local pos = 1
    local count = 0
    while pos <= #str do
        local clen = utf8charlen(string.byte(str, pos))
        count = count + 1
        if count == nchars then
            return string.sub(str, 1, pos + clen - 1)
        end
        pos = pos + clen
    end
    return str
end
-- =========================

local state = {
    active          = false,
    currentSequence = nil,
    currentIndex    = 0,
    fullText        = "",
    fullTextLen     = 0,
    displayedChars  = 0,
    timer           = 0.0,
    isComplete      = false,
}

local function setPortrait(character)
    if currentPortrait then
        UI.SetElementVisibility(currentPortrait, false)
    end
    local elementName = PORTRAIT_MAP[character]
    if elementName then
        UI.SetElementVisibility(elementName, true)
        currentPortrait = elementName
    end
end

local function loadDialogs()
    if allDialogs then return true end
    local path = Engine.GetAssetsPath() .. "/Scripts/dialogs.lua"
    local ok, result = pcall(dofile, path)
    if not ok or not result then
        Engine.Log("[DialogSystem] ERROR loading dialogs.lua: " .. tostring(result))
        return false
    end
    allDialogs = result
    Engine.Log("[DialogSystem] Dialogs loaded")
    return true
end

local function updateUI()
    if state.displayedChars ~= lastDisplayedChars then
        UI.SetElementText("DialogText", utf8sub(state.fullText, state.displayedChars))
        lastDisplayedChars = state.displayedChars
    end
    if state.isComplete then
        UI.SetElementVisibility("ContinueIcon", true)
    end
end

local function loadDialogEntry(entry)
    UI.SetElementText("CharacterName", entry.character or "")
    setPortrait(entry.character)
    state.fullText       = entry.text or ""
    state.fullTextLen    = utf8len(state.fullText)
    state.displayedChars = 0
    state.timer          = 0.0
    state.isComplete     = false
    lastDisplayedChars   = -1
    UI.SetElementVisibility("ContinueIcon", false)
    updateUI()
end

local function startSequence(sequenceId)
    if not loadDialogs() then return end
    local seq = allDialogs[sequenceId]
    if not seq then
        Engine.Log("[DialogSystem] Sequence not found: " .. tostring(sequenceId))
        return
    end
    state.active          = true
    state.currentSequence = seq.dialogs
    state.currentIndex    = 1
    Game.Pause()
    UI.SetElementVisibility("DialogBox", true)
    loadDialogEntry(state.currentSequence[1])
    Engine.Log("[DialogSystem] Started: " .. sequenceId)
end

function ForceCloseDialog()
    if not state.active then return end
    if currentPortrait then
        UI.SetElementVisibility(currentPortrait, false)
        currentPortrait = nil
    end
    state.active          = false
    state.currentSequence = nil
    state.currentIndex    = 0
    lastDisplayedChars    = -1
    UI.SetElementVisibility("DialogBox", false)
    UI.SetElementVisibility("ContinueIcon", false)
    UI.SetElementText("DialogText", "")
    UI.SetElementText("CharacterName", "")
    Engine.Log("[DialogSystem] Force closed")
end

local function closeDialog()
    if currentPortrait then
        UI.SetElementVisibility(currentPortrait, false)
        currentPortrait = nil
    end
    state.active          = false
    state.currentSequence = nil
    state.currentIndex    = 0
    lastDisplayedChars    = -1
    UI.SetElementVisibility("DialogBox", false)
    UI.SetElementVisibility("ContinueIcon", false)
    Game.Resume()
    Engine.Log("[DialogSystem] Closed")
end

local function onAdvancePressed()
    if not state.active then
        startSequence(DEFAULT_SEQUENCE)
        return
    end
    if not state.isComplete then
        state.displayedChars = state.fullTextLen
        state.isComplete     = true
        lastDisplayedChars   = -1
        updateUI()
        return
    end
    local nextIndex = state.currentIndex + 1
    if nextIndex <= #state.currentSequence then
        state.currentIndex = nextIndex
        loadDialogEntry(state.currentSequence[nextIndex])
    else
        closeDialog()
    end
end

function TriggerSequence(sequenceId)
    startSequence(sequenceId)
end

function Start(self)
    canvas = self.gameObject:GetComponent("Canvas")
    if not canvas then
        Engine.Log("[DialogSystem] ERROR: No ComponentCanvas found")
        return
    end
    UI.SetElementVisibility("Portrait_Telemaco", false)
    UI.SetElementVisibility("Portrait_Atenea", false)
    UI.SetElementVisibility("Portrait_JohnCartel", false)
    UI.SetElementVisibility("DialogBox", false)
    UI.SetElementVisibility("ContinueIcon", false)
    UI.SetElementText("DialogText", "")
    UI.SetElementText("CharacterName", "")
    Engine.Log("[DialogSystem] Ready")
end

function Update(self, dt)
    if _DialogSystem_pendingSequence and _DialogSystem_pendingSequence ~= "" then
        local seq = _DialogSystem_pendingSequence
        _DialogSystem_pendingSequence = ""
        startSequence(seq)
    end

    if Input.GetKeyDown("P") then
        onAdvancePressed()
    end

    if not state.active or state.isComplete then return end

    state.timer = state.timer + dt
    local charsToShow = math.floor(state.timer / TYPEWRITER_SPEED)
    if charsToShow > state.displayedChars then
        state.displayedChars = math.min(charsToShow, state.fullTextLen)
        updateUI()
        if state.displayedChars >= state.fullTextLen then
            state.isComplete = true
            UI.SetElementVisibility("ContinueIcon", true)
        end
    end
end

