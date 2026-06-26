--[[
    auto_audio_sub.lua  v1.3
    Mémorise et applique automatiquement audio + sous-titres par dossier.
    input_changed  → applique audio-es + audio-track dès le changement de fichier
    meta_changed   → réapplique audio-es en backup si input_changed était trop tôt
]]

local dlg        = nil
local dd_audio   = nil
local dd_sub     = nil
local lbl_status = nil

local audio_tracks = {}
local sub_tracks   = {}

local prefs      = {}
local prefs_file = nil
local meta_try   = 0

-- ── Utilitaires ───────────────────────────────────────────────────────────────

local function norm(s)
    if type(s) ~= "string" then return "" end
    return s:match("^%s*(.-)%s*$"):lower()
end

local function set_status(msg)
    if lbl_status then lbl_status:set_text(tostring(msg)) end
end

local function folder_of(uri)
    if not uri then return nil end
    local path = uri:match("^file://(.+)$") or uri
    path = path:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
    return path:match("^(.+)/[^/]+$") or path
end

local function find_pref(folder)
    if prefs[folder] then return prefs[folder] end
    local parent = folder:match("^(.+)/[^/]+$")
    if parent and prefs[parent] then return prefs[parent] end
    return nil
end

-- ── Persistance ───────────────────────────────────────────────────────────────

local function save_prefs()
    if not prefs_file then return end
    local lines = { "{" }
    for folder, p in pairs(prefs) do
        local ef = folder:gsub("\\","\\\\"):gsub('"','\\"')
        local al = (p.audio_label or ""):gsub('"','\\"')
        local sl = (p.sub_label   or ""):gsub('"','\\"')
        table.insert(lines, string.format(
            '  ["%s"] = { audio_label="%s", sub_label="%s", audio_0idx=%d, sub_0idx=%d },',
            ef, al, sl, p.audio_0idx or -1, p.sub_0idx or -1))
    end
    table.insert(lines, "}")
    local f = io.open(prefs_file, "w")
    if f then f:write(table.concat(lines, "\n")) f:close() end
end

local function load_prefs()
    if not prefs_file then return end
    local f = io.open(prefs_file, "r")
    if not f then return end
    local chunk = f:read("*a"); f:close()
    local fn = loadstring("return " .. chunk)
    if fn then
        local ok, data = pcall(fn)
        if ok and type(data) == "table" then prefs = data end
    end
end

-- ── Lecture des pistes ────────────────────────────────────────────────────────

local function load_tracks()
    audio_tracks = {}; sub_tracks = {}
    local item = vlc.input.item()
    if not item then return false end
    local ok, info = pcall(function() return item:info() end)
    if not ok or not info then return false end

    local streams = {}
    for key, data in pairs(info) do
        local n = tostring(key):match("(%d+)%s*$")
        if n and type(data) == "table" then
            local d = {}
            for k, v in pairs(data) do
                d[norm(k)] = type(v)=="string" and v:match("^%s*(.-)%s*$") or tostring(v)
            end
            local typ   = (d["type"] or ""):lower()
            local label = d["description"] or d["langue"] or d["language"] or ("Flux "..n)
            table.insert(streams, { idx=tonumber(n), typ=typ, label=label })
        end
    end
    table.sort(streams, function(a,b) return a.idx < b.idx end)
    for _, s in ipairs(streams) do
        if s.typ == "audio" then
            table.insert(audio_tracks, { id=s.idx, label=s.label })
        elseif s.typ:find("sous") or s.typ:find("sub") or s.typ:find("spu") then
            table.insert(sub_tracks,   { id=s.idx, label=s.label })
        end
    end
    return #audio_tracks > 0
end

local function resolve_id(tracks, label, default)
    if not label or label == "" then return default end
    local tl = label:lower()
    for _, t in ipairs(tracks) do
        if t.label:lower() == tl then return t.id end
    end
    for _, t in ipairs(tracks) do
        if t.label:lower():find(tl, 1, true) then return t.id end
    end
    return default
end

-- ── Application ───────────────────────────────────────────────────────────────

local function apply_es(audio_id, sub_id)
    local input = vlc.object.input()
    if not input then return false end
    pcall(vlc.var.set, input, "audio-es",    audio_id)
    pcall(vlc.var.set, input, "spu-es",      sub_id)
    return true
end

local function apply_track_pref(audio_0idx, sub_0idx)
    -- audio-track/spu-track = index 0-based parmi les pistes du type (lus au démarrage du flux)
    local input = vlc.object.input()
    if not input then return end
    if audio_0idx and audio_0idx >= 0 then
        pcall(vlc.var.set, input, "audio-track", audio_0idx)
    end
    if sub_0idx and sub_0idx >= 0 then
        pcall(vlc.var.set, input, "spu-track", sub_0idx)
    end
end

-- ── Boutons ───────────────────────────────────────────────────────────────────

function do_refresh()
    if not load_tracks() then
        set_status("Aucune piste — lance un fichier puis réessaie.")
        return
    end
    dd_audio:clear()
    for _, t in ipairs(audio_tracks) do dd_audio:add_value(t.label, t.id) end
    dd_sub:clear()
    dd_sub:add_value("Désactivés", -1)
    for _, t in ipairs(sub_tracks) do dd_sub:add_value(t.label, t.id) end
    set_status(#audio_tracks.." audio | "..#sub_tracks.." sous-titres.")
end

function do_apply()
    local msgs = {}
    local ok, err = pcall(function()
        local audio_id, audio_label = dd_audio:get_value()
        local sub_id,   sub_label   = dd_sub:get_value()
        audio_id = tonumber(audio_id) or -1
        sub_id   = tonumber(sub_id)   or -1
        if sub_label == "Désactivés" then sub_label = "" end

        if not apply_es(audio_id, sub_id) then
            table.insert(msgs, "Erreur: pas de lecture.") return
        end
        table.insert(msgs, "Appliqué.")

        -- Calcule l'index 0-based parmi les pistes de chaque type
        local audio_0idx = -1
        for i, t in ipairs(audio_tracks) do
            if t.id == audio_id then audio_0idx = i-1; break end
        end
        local sub_0idx = -1
        for i, t in ipairs(sub_tracks) do
            if t.id == sub_id then sub_0idx = i-1; break end
        end

        local item = vlc.input.item()
        if item then
            local folder = folder_of(item:uri())
            if folder then
                local entry = {
                    audio_label = audio_label or "",
                    sub_label   = sub_label   or "",
                    audio_0idx  = audio_0idx,
                    sub_0idx    = sub_0idx,
                }
                prefs[folder] = entry
                local parent = folder:match("^(.+)/[^/]+$")
                if parent then prefs[parent] = entry end
                save_prefs()
                table.insert(msgs, 'Sauvegardé ("'..(audio_label or "?")..'" / "'..(sub_label ~= "" and sub_label or "sans srt")..'").')
            end
        end
    end)
    if not ok then table.insert(msgs, "ERR: "..tostring(err):sub(-40)) end
    set_status(table.concat(msgs, " "))
end

function do_info()
    local item  = vlc.input.item()
    local uri   = item and item:uri() or "(aucun)"
    local folder = folder_of(uri) or "?"
    local n = 0; for _ in pairs(prefs) do n=n+1 end
    local pref = find_pref(folder)
    local pstr = pref and ('audio="'..pref.audio_label..'" 0idx='..tostring(pref.audio_0idx)..
                           ' sub="'..pref.sub_label..'" 0idx='..tostring(pref.sub_0idx)..'")') or "aucune"
    set_status(n.." préf. | "..folder:match("[^/]+$").." | "..pstr)
end

-- ── Auto-apply ────────────────────────────────────────────────────────────────

local function auto_apply_for(pref)
    -- 1. Applique la préférence initiale (pour le démarrage du flux)
    apply_track_pref(pref.audio_0idx, pref.sub_0idx)

    -- 2. Tente aussi le switch runtime si les pistes sont lisibles
    if load_tracks() then
        local aid = resolve_id(audio_tracks, pref.audio_label, -1)
        local sid = resolve_id(sub_tracks,   pref.sub_label,   -1)
        apply_es(aid, sid)
        set_status('Auto: "'..pref.audio_label..'" / "'..(pref.sub_label ~= "" and pref.sub_label or "sans srt")..'" ('..meta_try..')')
    else
        set_status("Auto: pistes pas encore disponibles (essai "..meta_try..")")
    end
end

-- ── VLC callbacks ─────────────────────────────────────────────────────────────

function descriptor()
    return {
        title        = "Auto Audio/Sub Preferences",
        version      = "1.2",
        author       = "WltrH",
        shortdesc    = "Audio/sous-titres auto par dossier",
        description  = "Mémorise et applique audio + sous-titres par dossier.",
        capabilities = { "input-listener", "meta-listener" }
    }
end

function activate()
    prefs_file = vlc.config.userdatadir().."/audio_sub_prefs.lua"
    load_prefs()
    create_dialog()
    do_refresh()
end

function deactivate()
    if dlg then dlg:delete() end
    dlg=nil; dd_audio=nil; dd_sub=nil; lbl_status=nil
end

function close() deactivate() end

function input_changed()
    meta_try = 0
    pcall(function()
        local item = vlc.input.item()
        if not item then return end
        local folder = folder_of(item:uri())
        local pref = folder and find_pref(folder)
        if not pref then return end
        apply_track_pref(pref.audio_0idx, pref.sub_0idx)
        if load_tracks() then
            local aid = resolve_id(audio_tracks, pref.audio_label, -1)
            local sid = resolve_id(sub_tracks,   pref.sub_label,   -1)
            apply_es(aid, sid)
            set_status('Auto: "'..pref.audio_label..'" / "'..(pref.sub_label ~= "" and pref.sub_label or "sans srt")..'"')
        end
    end)
end

function meta_changed()
    meta_try = meta_try + 1
    pcall(function()
        local item = vlc.input.item()
        if not item then return end
        local folder = folder_of(item:uri())
        local pref = folder and find_pref(folder)
        if not pref then return end
        auto_apply_for(pref)
    end)
end

-- ── Dialogue ──────────────────────────────────────────────────────────────────

function create_dialog()
    dlg = vlc.dialog("Auto Audio / Sous-titres")
    dlg:add_label("Audio :",       1, 1, 1, 1)
    dd_audio = dlg:add_dropdown(   2, 1, 2, 1)
    dlg:add_label("Sous-titres :", 1, 2, 1, 1)
    dd_sub   = dlg:add_dropdown(   2, 2, 2, 1)
    dlg:add_button("Rafraîchir",  do_refresh, 1, 3, 1, 1)
    dlg:add_button("Appliquer",   do_apply,   2, 3, 1, 1)
    dlg:add_button("Infos",       do_info,    3, 3, 1, 1)
    lbl_status = dlg:add_label("Lance un fichier puis Rafraîchir.", 1, 4, 3, 1)
end
