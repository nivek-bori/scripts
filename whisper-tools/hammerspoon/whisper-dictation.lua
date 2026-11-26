local DICTATION_HOTKEY = { modifiers = { "ctrl", "alt" }, key = "l" }
local MICROPHONE_INPUT = nil -- Optional AVFoundation input override, e.g. ":USB Microphone".
local CLIPBOARD_DELAY = 0.3
-- Skip silent captures before Whisper can hallucinate words from them.
local SILENCE_FILTER = "silenceremove=start_periods=1:start_duration=0.04:start_threshold=-55dB:start_silence=0.12"

local function quote(value)
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local modulePath = hs.fs.pathToAbsolute(debug.getinfo(1, "S").source:sub(2))
local repo = assert(modulePath and modulePath:match("^(.*)/hammerspoon/[^/]+$"),
    "Whisper Dictation: install this module as a symlink with ./install.sh")
local configPath = repo .. "/config.sh"
local readConfig = [[
    source "$1" &&
    printf '%s\0' "$ffmpeg" "$whisper" "$(model_path "$dictation_model")" "$language"
]]
local settings, configOK = hs.execute("/bin/zsh -fc " .. quote(readConfig) .. " _ " .. quote(configPath))
local ffmpeg, whisper, model, language = (settings or ""):match("^([^%z]+)%z([^%z]+)%z([^%z]+)%z([^%z]+)%z$")
if not configOK or not language then
    error("Whisper Dictation: could not read " .. configPath)
end

local active
local pasteboard = hs.pasteboard
local notice = {}

local function rect(x, y, w, h, radius, color)
    return {
        type = "rectangle", action = "fill", frame = { x = x, y = y, w = w, h = h },
        roundedRectRadii = { xRadius = radius, yRadius = radius }, fillColor = { hex = color },
    }
end

local function label(text, x)
    return {
        type = "text", text = text, frame = { x = x, y = 24, w = 244 - x, h = 24 },
        textFont = "HelveticaNeue-Medium", textSize = 15, textColor = { hex = "#F7F4FA" },
        textAlignment = "left", textLineBreak = "truncateTail",
    }
end

local function centerLabel(canvas, text, iconWidth, gap)
    canvas:appendElements(label(text, 0))
    local index = canvas:elementCount()
    local size = canvas:minimumTextSize(index, text)
    local width, height = math.ceil(size.w) + 2, math.ceil(size.h) + 2
    local left = math.floor((264 - iconWidth - gap - width) / 2)
    canvas:elementAttribute(index, "frame", {
        x = left + iconWidth + gap, y = math.floor((68 - height) / 2), w = width, h = height,
    })
    return left
end

local function hideStatus(session)
    if session.activity then session.activity:stop(); session.activity = nil end
    if session.capsule then session.capsule:delete(); session.capsule = nil end
end

local function showStatus(session, state)
    local screen = hs.screen.mainScreen()
    if not screen then return end
    local canvas = session.capsule
    if not canvas then
        local frame = screen:frame()
        canvas = hs.canvas.new({ x = math.floor(frame.x + (frame.w - 264) / 2),
            y = frame.y + frame.h - 100, w = 264, h = 76 })
        if not canvas then return end
        canvas:level(hs.canvas.windowLevels.overlay)
        canvas:behavior({ "canJoinAllSpaces", "fullScreenAuxiliary", "ignoresCycle" })
        canvas:clickActivating(false)
        session.capsule = canvas
    end

    local opening = state == "opening"
    local openingRed = "#FF4D5B"
    local x, y, width, height, radius = 12, 10, 240, 48, 24
    local borderWidth = opening and 5 or 1
    local background = rect(x, y, width, height, radius, opening and openingRed or "#38343F")
    background.withShadow = true
    background.shadow = { blurRadius = 9, offset = { w = 0, h = -4 }, color = { alpha = 0.32 } }
    local inset = rect(x + borderWidth, y + borderWidth, width - 2 * borderWidth,
        height - 2 * borderWidth, radius - borderWidth, opening and "#35191F" or "#141319")
    canvas:replaceElements(background, inset)

    if state == "transcribing" then
        local left = centerLabel(canvas, "Transcribing…", 24, 12)
        local center = { x = left + 12, y = 34 }
        canvas:appendElements({
            type = "circle", action = "stroke", center = center, radius = 10,
            strokeWidth = 3, strokeColor = { hex = "#544666" },
        }, {
            type = "arc", action = "stroke", center = center, radius = 10, arcRadii = false,
            startAngle = 0, endAngle = 155, strokeWidth = 3, strokeCapStyle = "round",
            strokeColor = { hex = "#C5A5FF" },
        })
        local arcIndex = canvas:elementCount()
        local angle = 0
        session.activity = hs.timer.doEvery(1 / 30, function()
            angle = (angle + 12) % 360
            canvas:rotateElement(arcIndex, angle, center)
        end)
    elseif state == "recording" then
        local left = centerLabel(canvas, "Recording…", 50, 13)
        local coral = "#FF666C"
        canvas:appendElements(rect(left, 29, 10, 10, 5, coral))
        for i, height in ipairs({ 7, 13, 20, 13, 7 }) do
            canvas:appendElements(rect(left + 17 + i * 6, 34 - height / 2, 3, height, 1.5, coral))
        end
    elseif opening then
        local left = centerLabel(canvas, "Opening microphone…", 10, 10)
        canvas:appendElements(rect(left, 29, 10, 10, 5, openingRed))
    elseif state == "noSpeech" then
        local left = centerLabel(canvas, "No speech detected", 12, 10)
        canvas:appendElements(rect(left, 32, 12, 4, 2, "#C5A5FF"))
    end
    canvas:show()
end

local function clearRecordingFeedback(session)
    if session.stopTimer then session.stopTimer:stop(); session.stopTimer = nil end
    if session.dot then session.dot:delete(); session.dot = nil end
end

local function clearFeedback(session)
    clearRecordingFeedback(session)
    hideStatus(session)
end

local function finish(session, message, details)
    clearFeedback(session)
    os.remove(session.audio)
    os.remove(session.output .. ".txt")
    hs.fs.rmdir(session.directory)
    active = nil
    if details and details:match("%S") then print("Whisper Dictation: " .. details) end
    if message then hs.alert.show(message) end
end

local function finishWithoutSpeech(session)
    finish(session)
    showStatus(notice, "noSpeech")
    notice.activity = hs.timer.doAfter(2, function() hideStatus(notice) end)
end

local labels = {
    blank_audio = true, silence = true, inaudible = true, unintelligible = true,
    no_speech = true, music = true, music_playing = true, background_music = true,
    applause = true, laughter = true, laughing = true, noise = true,
    background_noise = true, crosstalk = true,
}

local function removeLabel(label)
    local key = label:sub(2, -2):lower():match("^%s*(.-)%s*$"):gsub("[%s%-]+", "_")
    return labels[key] and " " or label
end

local function cleanText(text)
    return text:gsub("%b[]", removeLabel):gsub("%b()", removeLabel)
        :gsub("%*[^*\n]+%*", removeLabel):gsub("♪", ""):gsub("♫", "")
        :gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function paste(session, text)
    if not hs.accessibilityState() or hs.eventtap.isSecureInputEnabled() then
        finish(session, "Cannot paste. Check Hammerspoon Accessibility and leave secure input.")
        return
    end
    if #pasteboard.allContentTypes() > 1 then
        finish(session, "Clipboard contains multiple items. Copy a single item and try again.")
        return
    end
    local previous = pasteboard.readAllData()
    local function restore()
        if next(previous) then return pasteboard.writeAllData(previous) end
        pasteboard.clearContents()
        return true
    end
    if not pasteboard.setContents(text) then
        local restored = restore()
        finish(session, restored and "Could not write to the clipboard." or "Could not restore the clipboard.")
        return
    end
    local change = pasteboard.changeCount()
    hs.eventtap.keyStroke({ "cmd" }, "v", 0)
    session.pasteTimer = hs.timer.doAfter(CLIPBOARD_DELAY, function()
        local restored = pasteboard.changeCount() ~= change or restore()
        finish(session, not restored and "Could not restore the clipboard." or nil)
    end)
end

local function transcribe(session)
    showStatus(session, "transcribing")
    session.task = hs.task.new(whisper, function(code, _, stderr)
        hideStatus(session)
        local result = io.open(session.output .. ".txt", "r")
        local text = result and result:read("*a") or ""
        if result then result:close() end
        if code ~= 0 or not result then
            finish(session, "Transcription failed. Check the Hammerspoon Console.", stderr)
            return
        end
        text = cleanText(text)
        if not text:find("[^%s%p]") then
            finishWithoutSpeech(session)
        else
            paste(session, text)
        end
    end, {
        "-m", model, "-f", session.audio, "-l", language, "-nt",
        "--beam-size", "1", "--best-of", "2",
        "--no-prints", "--output-txt", "--output-file", session.output,
    })
    if not session.task or not session.task:start() then
        finish(session, "Could not start whisper-cli. Run ./install.sh.")
    end
end

local function selectMicrophone()
    if MICROPHONE_INPUT then return MICROPHONE_INPUT end

    local default = hs.audiodevice.defaultInputDevice()
    local transport = default and default:transportType()
    if transport and not transport:lower():find("bluetooth", 1, true) then
        return ":default"
    end

    -- Opening a Bluetooth headset mic can lower the volume of audio already playing.
    local fallback
    for _, device in ipairs(hs.audiodevice.allInputDevices()) do
        local kind, name = device:transportType(), device:name()
        if kind and name and not kind:lower():find("bluetooth", 1, true) then
            if kind == "Built-in" then return ":" .. name end
            fallback = fallback or ":" .. name
        end
    end
    return fallback
end

local function startRecording()
    hideStatus(notice)
    if not hs.accessibilityState() then
        hs.alert.show("Enable Hammerspoon in Privacy & Security → Accessibility.")
        return
    end
    for _, path in ipairs({ ffmpeg, whisper, model }) do
        if (hs.fs.attributes(path, "size") or 0) == 0 then
            hs.alert.show("Dictation dependency is missing. Run ./install.sh.")
            return
        end
    end
    local microphone = selectMicrophone()
    if not microphone then
        hs.alert.show("Connect a built-in or wired microphone to keep Bluetooth playback volume.")
        return
    end
    local directory, created = hs.execute('/usr/bin/mktemp -d "${TMPDIR:-/tmp}/whisper-dictation.XXXXXXXX"')
    if not created then
        hs.alert.show("Could not create a temporary recording folder.")
        return
    end
    directory = directory:gsub("\n$", "")
    local session = {
        directory = directory, audio = directory .. "/audio.wav", output = directory .. "/result",
        recording = true, errors = "",
    }
    active = session
    showStatus(session, "opening")
    session.task = hs.task.new(ffmpeg, function(code, _, stderr)
        clearRecordingFeedback(session)
        local errors = session.errors .. (stderr or "")
        if not session.recording and not session.ready then
            finish(session)
        elseif session.recording or (code ~= 0 and not session.interrupted) then
            finish(session, "Microphone recording failed. Check Hammerspoon Microphone permission and the Console.", errors)
        elseif (hs.fs.attributes(session.audio, "size") or 0) < 6400 then
            finishWithoutSpeech(session)
        else
            transcribe(session)
        end
    end, function(_, _, stderr)
        session.errors = (session.errors .. (stderr or "")):sub(-4096)
        -- AVFoundation reports the input after receiving its first audio frame.
        if active == session and session.recording and not session.ready and
           session.errors:find("Input #0, avfoundation", 1, true) then
            session.ready = true
            showStatus(session, "recording")
            session.dot = hs.menubar.new()
            if session.dot then
                session.dot:setTitle(hs.styledtext.new("●", { color = { red = 1, green = 0.2, blue = 0.2 } }))
                session.dot:setTooltip("Whisper Dictation is recording")
            end
        end
        return true
    end, {
        "-hide_banner", "-loglevel", "info", "-nostats", "-stdin",
        -- AVFoundation supplies the audio format at open, so no extra probing is needed.
        "-f", "avfoundation", "-nofind_stream_info", "-i", microphone,
        "-af", SILENCE_FILTER,
        "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", session.audio,
    })
    if not session.task or not session.task:start() then
        finish(session, "Could not start FFmpeg. Run ./install.sh.")
    end
end

local hotkey = hs.hotkey.bind(DICTATION_HOTKEY.modifiers, DICTATION_HOTKEY.key, function()
    local session = active
    if not session then
        startRecording()
    elseif session.recording then
        session.recording = false
        if not session.ready then hideStatus(session) end
        -- Queue q even if FFmpeg is still opening the input device.
        local recorder = session.task
        recorder:setInput("q\n")
        session.stopTimer = hs.timer.doAfter(3, function()
            if recorder:isRunning() then
                session.interrupted = true
                recorder:interrupt()
            end
        end)
    end
end)

return { hotkey = hotkey }
