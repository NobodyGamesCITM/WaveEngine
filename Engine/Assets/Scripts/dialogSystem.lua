local TYPEWRITER_SPEED = 0.03

public = {
    updateWhenPaused = true
}


local skipSFX = nil
local charSFX = nil

local canvas     = nil
local wasAmbient = false

_G._IsDialogActive = false

local PORTRAIT_MAP = {
    ["Telemachus"]  = "Portrait_Telemaco",
    ["Athena"]      = "Portrait_Atenea",
    ["John cartel"] = "Portrait_JohnCartel",
}

local currentPortrait    = nil
local lastDisplayedChars = -1


local allDialogs = {
    intro = {
        id = "intro",
        dialogs = {
            {
                character = "Athena",
                portrait  = "Textures/Atenea.png",
                text      = "Telemachus, you finally awaken. The ocean turned against you, but there is no time to lose. Enter the forest, and do not be deceived by its peaceful appearance, evil dwells within it. Be cautious, because a single false step could be your last.",
                mood      = ""
            },
            {
                character = "Telemachus",
                portrait  = "Textures/Telemaco.png",
                text      = "Ugh… very well. Here I go!",
                mood      = "Decided"
            }
        }
    },

    checkpointInfo = {
        id = "checkpointInfo",
        dialogs = {
            {
                character = "Athena",
                portrait  = "Textures/Atenea.png",
                text      = "You have found one of my altars. If you activate them, they will shelter you. Keep your eyes open, you will find them where you need them most.",
                mood      = ""
            },
            {
                character = "Telemachus",
                portrait  = "Textures/Telemaco.png",
                text      = "Knowing that you watch over me, even from afar, brings me comfort. Thank you Athena.",
                mood      = "Relieved"
            }
        }
    },

    sanctuaryInfo = {
        id = "sanctuaryInfo",
        dialogs = {
            {
                character = "Athena",
                portrait  = "Textures/Atenea.png",
                text      = "The island’s sanctuary, once a place of worship to Hades, serves as a bridge to the Underworld. To open it, you must find and deactivate the statues of Cerberus.",
                mood      = ""
            },
            {
                character = "Telemachus",
                portrait  = "Textures/Telemaco.png",
                text      = "It will be a harsh mission, but I will not turn back now.",
                mood      = "Generic"
            }
        }
    },

    maskInfo = {
        id = "maskInfo",
        dialogs = {
            {
                character = "Athena",
                portrait  = "Textures/Atenea.png",
                text      = "The gods granted these masks as a gift to their faithful. Wear them, without their divine power you will not prevail.",
                mood      = ""
            }
        }
    },

    portalWarning = {
        id = "portalWarning",
        dialogs = {
            {
                character = "Athena",
                portrait  = "Textures/Atenea.png",
                text      = "Tread with caution, Telemachus. Long ago, the Underworld had order, now chaos and cruelty reign within it. Remember all you have learned, you alone shall cross the portal. Do not hesitate to return if you encounter a threat beyond your strength.",
                mood      = ""
            },
            {
                character = "Telemachus",
                portrait  = "Textures/Telemaco.png",
                text      = "Alone? I will not deny that fear grips me, but I cannot stop now. I will gather the courage I need, cross the portal, and the next time you see me, I will be with Odysseus.",
                mood      = "Scared"
            }
        }
    }
}


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

local state = {
    active          = false,
    currentSequence = nil,
    currentIndex    = 0,
    fullText        = "",
    fullTextLen     = 0,
    displayedChars  = 0,
    timer           = 0.0,
    isComplete      = false,
    inputConsumed   = false,
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

    if charSFX then

        if entry.character == "Atenea" or entry.character == "Athena" then
            charSFX:SelectPlayAudioEvent("UI_OwlHoot")
        elseif entry.character == "Telémaco" or entry.character == "Telemachus" then

            Audio.SetSwitch("Player_Voice", tostring(entry.mood), charSFX)
            charSFX:SelectPlayAudioEvent("UI_TeleVocals")
        end
    else
        --Engine.Log("[DialogSystem] Character Voice Audio Source not found!")
    end

    state.fullText       = entry.text or ""
    state.fullTextLen    = utf8len(state.fullText)
    state.displayedChars = 0
    state.timer          = 0.0
    state.isComplete     = false
    lastDisplayedChars   = -1
    state.inputConsumed  = false
    UI.SetElementVisibility("ContinueIcon", false)
    updateUI()
end

local function startSequence(sequenceId)
    local seq = allDialogs[sequenceId]
    if not seq then
        --Engine.Log("[DialogSystem] ERROR: secuencia no encontrada -> " .. tostring(sequenceId))
        return
    end

    state.active          = true
    state.currentSequence = seq.dialogs
    state.currentIndex    = 1
    _G._IsDialogActive    = true
    _G.DialogActive       = true

    wasAmbient           = _G.DialogAmbientMode or false
    _G.DialogAmbientMode = false

    if not wasAmbient then
        _G._DialogBlockingPlayer = true
        if _G.SetPlayerCanMove then _G.SetPlayerCanMove(false) end
    end

    UI.SetElementVisibility("DialogBox", true)

    if wasAmbient then
        UI.SetElementVisibility("ContinueIcon", false)
    end

    loadDialogEntry(state.currentSequence[1])
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
    _G._IsDialogActive    = false
    lastDisplayedChars    = -1
    UI.SetElementVisibility("DialogBox", false)
    UI.SetElementVisibility("ContinueIcon", false)
    UI.SetElementText("DialogText", "")
    UI.SetElementText("CharacterName", "")
    _G.DialogActive          = false
    _G._DialogBlockingPlayer = false
    if _G.SetPlayerCanMove then _G.SetPlayerCanMove(true) end
    wasAmbient = false
end

function SuspendDialog()
    if not state.active then return end
    UI.SetElementVisibility("DialogBox", false)
    UI.SetElementVisibility("ContinueIcon", false)
    if currentPortrait then
        UI.SetElementVisibility(currentPortrait, false)
    end
end

function ResumeDialog()
    if not state.active then return end
    UI.SetElementVisibility("DialogBox", true)
    if currentPortrait then
        UI.SetElementVisibility(currentPortrait, true)
    end
    if state.isComplete and not wasAmbient then
        UI.SetElementVisibility("ContinueIcon", true)
    end
end

local function closeDialog()
    if currentPortrait then
        UI.SetElementVisibility(currentPortrait, false)
        currentPortrait = nil
    end
    state.active          = false
    state.currentSequence = nil
    state.currentIndex    = 0
    _G._IsDialogActive    = false
    lastDisplayedChars    = -1
    UI.SetElementVisibility("DialogBox", false)
    UI.SetElementVisibility("ContinueIcon", false)
    _G.DialogActive          = false
    _G._DialogBlockingPlayer = false
    if _G.SetPlayerCanMove then _G.SetPlayerCanMove(true) end
    wasAmbient = false
end

local function onAdvancePressed()
    if not state.active then return end
    if wasAmbient then return end
    if state.inputConsumed then return end
    state.inputConsumed = true

    if skipSFX and not Audio.IsEventPlaying("UI_SkipDialog") then
        skipSFX:SelectPlayAudioEvent("UI_SkipDialog")
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

local function FindDialogAudioSources(self)
    local skipSource = GameObject.FindInChildren(self.gameObject, "SkipSource")
    if skipSource then
        skipSFX = skipSource:GetComponent("Audio Source")
        if not skipSFX then
            --Engine.Log("[DialogSystem] Unable to retrieve Skip Audio Source Component")
        end
    end

    local charSource = GameObject.FindInChildren(self.gameObject, "CharSource")
    if charSource then
        charSFX = charSource:GetComponent("Audio Source")
        if not charSFX then
            --Engine.Log("[DialogSystem] Unable to retrieve Character Audio Source Component")
        end
    end
end

function TriggerSequence(sequenceId)
    startSequence(sequenceId)
end

function Start(self)
    _G.TriggerSequence   = TriggerSequence
    _G.ForceCloseDialog  = ForceCloseDialog
    _G.SuspendDialog     = SuspendDialog
    _G.ResumeDialog      = ResumeDialog
    _G.DialogActive      = false
    _G.DialogAmbientMode = false
    _G.AdvanceDialog     = onAdvancePressed
    _G.UpdatePauseState  = function() end

    FindDialogAudioSources(self)

    canvas = self.gameObject:GetComponent("Canvas")
    if not canvas then
        Engine.Log("[DialogSystem] ERROR: Canvas no encontrado")
        return
    end

    local ok, err = pcall(function()
        UI.SetElementVisibility("Portrait_Telemaco", false)
        UI.SetElementVisibility("Portrait_Atenea", false)
        UI.SetElementVisibility("Portrait_JohnCartel", false)
        UI.SetElementVisibility("DialogBox", false)
        UI.SetElementVisibility("ContinueIcon", false)
        UI.SetElementText("DialogText", "")
        UI.SetElementText("CharacterName", "")
    end)

    if not ok then
        Engine.Log("[DialogSystem] WARN al limpiar UI: " .. tostring(err))
    end
end

function Update(self, dt)
    if not skipSFX or not charSFX then
        FindDialogAudioSources(self)
    end

    if _DialogSystem_pendingSequence and _DialogSystem_pendingSequence ~= "" then
        local seq = _DialogSystem_pendingSequence
        _DialogSystem_pendingSequence = ""
        startSequence(seq)
    end

    if state.active then
        state.inputConsumed = false
    end

    if state.active and not wasAmbient then
        if Input.GetKeyDown("F") or Input.GetGamepadButtonDown("A") then
            onAdvancePressed()
        end
    end

    if not state.active or state.isComplete then return end

    state.timer = state.timer + dt
    local charsToShow = math.floor(state.timer / TYPEWRITER_SPEED)
    if charsToShow > state.displayedChars then
        state.displayedChars = math.min(charsToShow, state.fullTextLen)
        updateUI()
        if state.displayedChars >= state.fullTextLen then
            state.isComplete = true
            if not wasAmbient then
                UI.SetElementVisibility("ContinueIcon", true)
            end
        end
    end
end