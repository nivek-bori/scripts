-- Open a file, a Notion page, or both when Dia's focused tab matches a rule
local motivationTasksURL = "https://app.notion.com/p/Just-Work-fea353f5c3c8414bbbf3cd178f3f43e4?source=copy_link#41495550d2c0806091dbc4e6004b1a87"
local DIA_BUNDLE_ID = "company.thebrowser.dia"
local NOTION_BUNDLE_ID = "notion.id"

diaFolder = {
  rules = {
    -- openRandom uses randomFolder when set, or folder by default.
    -- Use notionURL on rules that should also open a Notion page.
    { domain = "yahoo.com",   folder = "/Users/kevinboriboonsomsin/Documents/saves/identity", closeTab = true, openRandom = "any", notionURL = motivationTasksURL },
    { domain = "youtube.com",   folder = "/Users/kevinboriboonsomsin/Documents/saves/identity", closeTab = true, openRandom = "any", notionURL = motivationTasksURL },
    { domain = "instagram.com", folder = "/Users/kevinboriboonsomsin/Documents/saves/identity", closeTab = true, openRandom = "any", notionURL = motivationTasksURL },
  },
  POLL = 1,           -- seconds between checks while using Dia
  COOLDOWN = 60,       -- seconds before the same rule can fire again
  debug = false,       -- set true in the Console to log each step
  lastFired = {},
  lastHost = nil,
  lastPick = {},       -- most recent file per folder
  randomRounds = {},   -- files already picked this round, per folder and filter
}
local M = diaFolder
local action = 0
local cancelWindowSearch
local lastTabID, lastURL, lastReadError

local function log(fmt, ...)
  if M.debug then print("[diaFolder] " .. string.format(fmt, ...)) end
end

M.getURLScript = string.format([[
tell application id %q
  if (count of windows) is 0 then return {"", ""}
  set selectedTab to active tab of front window
  if selectedTab is missing value then return {"", ""}
  set u to URL of selectedTab
  if u is missing value then return {"", ""}
  return {u, id of selectedTab}
end tell
]], DIA_BUNDLE_ID)

-- Each step is a separate function so it can be tested on its own

function M.frontApp()
  local app = hs.application.frontmostApplication()
  return app and app:name()
end

function M.getURL()
  local ok, tab, raw = hs.osascript.applescript(M.getURLScript)
  if not ok then return false, nil, raw end
  return true, tab[1], raw, tab[2]
end

function M.hostOf(url)
  return url and url:match("^%a[%w+.-]*://([^/:?#]+)")
end

function M.matches(host, domain)
  return host == domain or host:sub(-(#domain + 1)) == "." .. domain
end

function M.findRule(host)
  for _, r in ipairs(M.rules) do
    if M.matches(host, r.domain) then return r end
  end
end

function M.hasFile(r)
  return r.openFile or r.openRandom or r.openNewest
end

local function fileFolder(r)
  if r.openRandom and not r.openFile then return r.randomFolder or r.folder end
  return r.folder
end

-- Turns a Lua string into a quoted AppleScript string
function M.asString(s)
  return '"' .. (s:gsub('\\', '\\\\'):gsub('"', '\\"')) .. '"'
end

-- Closes the focused tab only if it still has this URL
function M.closeTab(url, tabID)
  local checkID = tabID and ("\n    if id of selectedTab is not " .. M.asString(tabID) .. " then return false") or ""
  local script = string.format([[
tell application id %q
  try
    set selectedTab to active tab of front window
    if URL of selectedTab is not %s then return false%s
    close selectedTab
    return true
  on error
    return false
  end try
end tell
]], DIA_BUNDLE_ID, M.asString(url), checkID)
  local ok, closed = hs.osascript.applescript(script)
  return ok and closed == true
end

local function closeRuleTab(r, url, tabID)
  if not r.closeTab or not url then return end
  if M.closeTab(url, tabID) then
    log("closed tab %s", url)
  else
    log("could not close tab %s (focus changed or tab already gone)", url)
  end
end

M.EXT = {
  video = { mp4 = true, mov = true, m4v = true, mkv = true, webm = true, avi = true },
  audio = { mp3 = true, m4a = true, wav = true, aac = true, flac = true },
  pdf   = { pdf = true },
  image = { jpg = true, jpeg = true, png = true, heic = true, gif = true },
}
M.SKIP = { crdownload = true, download = true, part = true, tmp = true }  -- unfinished downloads

-- Whether a file extension fits: "any", a kind from M.EXT, or a list of extensions
local function wants(kind, ext)
  if kind == "any" then return not (ext and M.SKIP[ext]) end
  if not ext then return false end
  if type(kind) == "table" then
    for _, e in ipairs(kind) do
      if e:lower() == ext then return true end
    end
    return false
  end
  return M.EXT[kind] ~= nil and M.EXT[kind][ext] == true
end

-- All visible files in a folder that fit the kind
function M.listFiles(folder, kind)
  local files = {}
  if hs.fs.attributes(folder, "mode") ~= "directory" then return files end
  for name in hs.fs.dir(folder) do
    if name:sub(1, 1) ~= "." then
      local path = folder .. "/" .. name
      local attrs = hs.fs.attributes(path)
      local ext = name:match("%.([^.]+)$")
      ext = ext and ext:lower()
      if attrs and attrs.mode == "file" and wants(kind, ext) then
        files[#files + 1] = { path = path, modified = attrs.modification }
      end
    end
  end
  return files
end

function M.newestFile(folder, kind)
  local best
  for _, f in ipairs(M.listFiles(folder, kind)) do
    if not best or f.modified > best.modified then best = f end
  end
  return best and best.path
end

local function randomFilterKey(kind)
  if type(kind) ~= "table" then return kind end
  local extensions, seen = {}, {}
  for _, extension in ipairs(kind) do
    local ext = extension:lower()
    if not seen[ext] then
      seen[ext] = true
      extensions[#extensions + 1] = ext
    end
  end
  table.sort(extensions)
  return table.concat(extensions, "\0")
end

-- Draw from the files that haven't been picked this round.
function M.randomFile(folder, kind, remember)
  local files = M.listFiles(folder, kind)
  if #files == 0 then return nil end

  local filter = randomFilterKey(kind)
  local rounds = M.randomRounds[folder] or {}
  local picked = rounds[filter] or {}
  local choices = {}
  for _, file in ipairs(files) do
    if not picked[file.path] then choices[#choices + 1] = file end
  end
  if #choices == 0 then
    choices, picked = files, {}
  end

  local previous = M.lastPick[folder]
  if #choices > 1 and previous then
    for i, file in ipairs(choices) do
      if file.path == previous then table.remove(choices, i) break end
    end
  end

  local path = choices[math.random(#choices)].path
  if remember then
    picked[path] = true
    rounds[filter] = picked
    M.randomRounds[folder] = rounds
  end
  return path
end

function M.fileFor(r, rememberRandom)
  if r.openFile then
    local path = r.openFile:sub(1, 1) == "/" and r.openFile or (r.folder .. "/" .. r.openFile)
    return hs.fs.attributes(path, "mode") == "file" and path or nil
  elseif r.openRandom then
    return M.randomFile(fileFolder(r), r.openRandom, rememberRandom)
  elseif r.openNewest then
    return M.newestFile(r.folder, r.openNewest)
  end
end

local function openWithMacOS(args, onOpened)
  local target = args[#args]
  log("opening %s", target)
  local task = hs.task.new("/usr/bin/open", function(code, _, err)
    if code ~= 0 then print("[diaFolder] could not open " .. target .. ": " .. err) end
    if onOpened then onOpened(code == 0) end
  end, args)
  if task and task:start() then return task end
  print("[diaFolder] could not start open for " .. target)
  if onOpened then onOpened(false) end
end

function M.openFileFor(r, onOpened)
  local path = M.fileFor(r, true)
  if not path then
    if M.hasFile(r) then log("no matching file for %s", r.domain or fileFolder(r)) end
    if onOpened then onOpened() end
    return
  end
  local folder = fileFolder(r)
  if folder then M.lastPick[folder] = path end

  return openWithMacOS({ path }, onOpened and function(ok)
    onOpened(ok and path or nil)
  end)
end

local function fileWindowFor(path)
  local filename = path:match("[^/]+$")
  local stem = filename:match("^(.+)%.[^.]+$") or filename
  local absolute = hs.fs.pathToAbsolute(path) or path
  local function titleMatches(window)
    local title = window:title() or ""
    local label = title:match("^(.-) %- ") or title:match("^(.-) — ") or title:match("^(.-) – ")
    return title == filename or title == stem or label == filename or label == stem
  end

  local function documentMatches(window, titleMatch)
    local element = hs.axuielement.windowElement(window)
    if not element then return titleMatch end
    if not element:setTimeout(0.1) then return false end
    local document, err = element:attributeValue("AXDocument")
    local documentPath = type(document) == "string" and document:match("^file://(.*)$")
    if documentPath then
      documentPath = documentPath:gsub("^localhost/", "/"):gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
      end)
      return (hs.fs.pathToAbsolute(documentPath) or documentPath) == absolute
    end

    -- Keep title matching for viewers without AXDocument, but retry temporary AX errors.
    return titleMatch and (not err or err == "Attribute is not supported by target"
      or err == "Requested value does not exist")
  end
  return titleMatches, documentMatches
end

local function defaultAppFor(path)
  local source = string.format([[
ObjC.import("AppKit");
var file = $.NSURL.fileURLWithPath(%s[0]);
var appURL = $.NSWorkspace.sharedWorkspace.URLForApplicationToOpenURL(file);
ObjC.unwrap($.NSBundle.bundleWithURL(appURL).bundleIdentifier) || "";
]], hs.json.encode({path}))
  local ok, bundleID = hs.osascript.javascript(source)
  if ok and type(bundleID) == "string" and bundleID ~= "" then return bundleID end
  log("could not resolve the default app for %s", path)
end

local function findWindow(app, titleMatches, documentMatches)
  local otherWindows = {}
  local function checkCandidate(window)
    if not window or not window:isStandard() then return end
    if not titleMatches then return window end
    if titleMatches(window) then
      if documentMatches(window, true) then return window end
    else
      otherWindows[#otherWindows + 1] = window
    end
  end

  local focused = app:focusedWindow()
  local window = checkCandidate(focused)
  if window then return window end
  for _, candidate in ipairs(app:visibleWindows()) do
    if candidate ~= focused then
      window = checkCandidate(candidate)
      if window then return window end
    end
  end
  for _, candidate in ipairs(otherWindows) do
    if documentMatches(candidate, false) then return candidate end
  end
end

local function waitForWindow(bundleID, windowed, onReady, titleMatches, documentMatches)
  local deadline = hs.timer.absoluteTime() + 10 * 1000000000
  local timer, appWatcher, windowWatcher, watchedPID
  local fullscreenWindow
  local function stop()
    cancelWindowSearch = nil
    if timer then timer:stop() end
    if appWatcher then appWatcher:stop() end
    if windowWatcher then windowWatcher:stop() end
  end
  local function check()
    if cancelWindowSearch ~= stop then return end
    local app
    if bundleID then
      app = hs.application.applicationsForBundleID(bundleID)[1]
    else
      app = hs.application.frontmostApplication()
    end
    local window = app and findWindow(app, titleMatches, documentMatches)
    if window then
      if not windowed or not window:isFullScreen() then
        stop()
        onReady(window)
        return
      end
      local windowID = window:id() or window
      if fullscreenWindow ~= windowID then
        fullscreenWindow = windowID
        window:setFullScreen(false)
      end
    end
    if hs.timer.absoluteTime() >= deadline then
      log("could not find the opened window")
      stop()
      onReady(window)
      return
    end

    if app and watchedPID ~= app:pid() then
      if windowWatcher then windowWatcher:stop() end
      watchedPID = app:pid()
      windowWatcher = app:newWatcher(check)
      if windowWatcher then
        local events = hs.uielement.watcher
        windowWatcher:start({events.windowCreated, events.focusedWindowChanged, events.mainWindowChanged})
      end
    end
    if not appWatcher then
      local events = hs.application.watcher
      appWatcher = events.new(function(_, event, changedApp)
        if (event == events.launched or event == events.activated) and changedApp
          and (not bundleID or changedApp:bundleID() == bundleID) then
          check()
        end
      end):start()
    end
    if not timer then
      timer = hs.timer.doAfter(0.2, function()
        timer = nil
        check()
      end)
    end
  end
  cancelWindowSearch = stop
  check()
end

local function placeWindow(window, screen, side, scaleHeight)
  local display = screen:frame()
  local half = math.floor(display.w / 2)
  local left = side == "left"
  local x = left and display.x or display.x + half
  local width = left and half or display.w - half
  local height = display.h
  if not left then
    local current = window:frame()
    local preferred = current.h
    if scaleHeight and current.w > 0 then preferred = preferred * width / current.w end
    height = math.min(math.floor(preferred), display.h)
  end
  local y = display.y + math.floor((display.h - height) / 2)
  window:setFrame({ x = x, y = y, w = width, h = height }, 0)

  if not left then
    -- Some file viewers adjust the height when their width changes.
    local actual = window:frame()
    local centeredY = display.y + math.floor((display.h - actual.h) / 2)
    if actual.y ~= centeredY then window:setTopLeft({ x = x, y = centeredY }) end
  end
end

function M.fire(r, url, tabID)
  action = action + 1
  local thisAction = action
  if cancelWindowSearch then cancelWindowSearch() end
  closeRuleTab(r, url, tabID)

  local function openNotion(fileWindow, screen)
    if not r.notionURL then return end
    local link = r.notionURL:gsub("^https?://", "notion://")
    local args = { "-b", NOTION_BUNDLE_ID, link }
    if fileWindow then table.insert(args, 1, "-g") end
    openWithMacOS(args, function(ok)
      if not fileWindow or thisAction ~= action then return end
      if not ok or not screen then
        fileWindow:focus()
        return
      end
      waitForWindow(NOTION_BUNDLE_ID, true, function(notionWindow)
        if notionWindow and not notionWindow:isFullScreen() then
          placeWindow(notionWindow, screen, "left")
          notionWindow:raise()
        end
        fileWindow:focus()
      end)
    end)
  end

  M.openFileFor(r, function(path)
    if thisAction ~= action then return end
    if not path then
      openNotion()
      return
    end
    local bundleID = defaultAppFor(path)
    local titleMatches, documentMatches = fileWindowFor(path)
    waitForWindow(bundleID, r.notionURL ~= nil, function(fileWindow)
      local screen
      if fileWindow then
        if r.notionURL and not fileWindow:isFullScreen() then
          screen = fileWindow:screen()
          local ext = (path:match("%.([^.]+)$") or ""):lower()
          if screen then placeWindow(fileWindow, screen, "right", M.EXT.video[ext]) end
        end
        fileWindow:focus()
      end
      openNotion(fileWindow, screen)
    end, titleMatches, documentMatches)
  end)
end

function M.reset()
  M.lastFired, M.lastHost, M.lastPick = {}, nil, {}
  M.randomRounds = {}
  lastTabID, lastURL = nil, nil
  print("[diaFolder] cooldowns cleared")
end

function M.check()
  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= DIA_BUNDLE_ID then
    if M.lastHost then log("left Dia (front app: %s)", tostring(app and app:name())) end
    M.lastHost, lastTabID, lastURL = nil, nil, nil
    return
  end

  local ok, url, raw, tabID = M.getURL()
  if not ok then
    local err = hs.inspect(raw)
    if err ~= lastReadError then print("[diaFolder] could not read Dia's active tab: " .. err) end
    lastReadError = err
    return
  end
  lastReadError = nil

  local host = M.hostOf(url)
  if not host then
    M.lastHost, lastTabID, lastURL = nil, nil, nil
    return
  end
  if tabID == lastTabID and url == lastURL then return end
  log("active tab: %s (%s)", host, url)
  M.lastHost, lastTabID, lastURL = host, tabID, url

  local r = M.findRule(host)
  if not r then log("no rule for %s", host) return end

  local now, last = os.time(), M.lastFired[r.domain]
  if last and now - last < M.COOLDOWN then
    closeRuleTab(r, url, tabID)
    log("cooldown: %ds left for %s", M.COOLDOWN - (now - last), r.domain)
  else
    M.lastFired[r.domain] = now
    M.fire(r, url, tabID)
  end
end

-- Tests: run from the Hammerspoon Console

function M.test()
  local pass, fail = 0, 0
  local function expect(name, got, want)
    if got == want then
      pass = pass + 1
      print("PASS  " .. name)
    else
      fail = fail + 1
      print(string.format("FAIL  %s: got %s, want %s", name, hs.inspect(got), hs.inspect(want)))
    end
  end

  print("-- URL parsing --")
  expect("plain domain",   M.hostOf("https://github.com/org/repo"), "github.com")
  expect("subdomain",      M.hostOf("https://gist.github.com/x"), "gist.github.com")
  expect("port stripped",  M.hostOf("http://localhost:3000/a"), "localhost")
  expect("query stripped", M.hostOf("https://figma.com?x=1"), "figma.com")
  expect("about: page",    M.hostOf("about:blank"), nil)
  expect("empty string",   M.hostOf(""), nil)
  expect("AppleScript quoting", M.asString('a"b\\c'), '"a\\"b\\\\c"')

  print("-- Domain matching --")
  expect("exact",        M.matches("github.com", "github.com"), true)
  expect("subdomain",    M.matches("gist.github.com", "github.com"), true)
  expect("lookalike",    M.matches("notgithub.com", "github.com"), false)
  expect("suffix trick", M.matches("github.com.evil.com", "github.com"), false)

  print("-- Rules --")
  for _, r in ipairs(M.rules) do
    expect("rule found: " .. r.domain, M.findRule(r.domain), r)
    if M.hasFile(r) then
      local kind = not r.openFile and (r.openRandom or r.openNewest)
      local folder = fileFolder(r)
      if kind then
        expect("source folder exists: " .. folder, hs.fs.attributes(folder, "mode"), "directory")
        print(string.format("      %d matching file(s) in %s", #M.listFiles(folder, kind), folder))
      end
      local f = M.fileFor(r)
      expect("file found for " .. r.domain, f ~= nil, true)
      if f then print("      would open: " .. f) end
    end
  end

  print("-- Dia connection --")
  local ok, url, raw = M.getURL()
  expect("AppleScript ran", ok, true)
  if ok then print("      focused tab URL: " .. hs.inspect(url))
  else print("      error: " .. hs.inspect(raw)) end

  print("-- Timer --")
  expect("timer running", M.timer ~= nil and M.timer:running(), true)

  print(string.format("== %d passed, %d failed ==", pass, fail))
end

function M.testLive(delay)
  delay = delay or 5
  print(string.format("Switch to Dia now. Checking in %d seconds...", delay))
  M._liveTimer = hs.timer.doAfter(delay, function()
    local name = M.frontApp()
    print("front app: " .. hs.inspect(name) .. (name == "Dia" and "  PASS" or "  FAIL, expected \"Dia\""))
    local ok, url, raw = M.getURL()
    print("URL:  " .. (ok and hs.inspect(url) or ("error " .. hs.inspect(raw))))
    local host = M.hostOf(url)
    print("host: " .. hs.inspect(host))
    local r = host and M.findRule(host)
    print("rule: " .. (r and r.domain or "none"))
  end)
end

-- Runs a rule's open actions without going through Dia
function M.testOpen(i)
  local r = M.rules[i or 1]
  print("testing rule for " .. r.domain)
  M.fire(r)
end

M.timer = hs.timer.doEvery(M.POLL, M.check)
