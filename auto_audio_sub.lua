--[[
    auto_audio_sub.lua
    VLC extension to automatically remember and reapply audio/subtitle track choices per folder.
    Compatible with Windows, macOS, Linux.
    Author: William
    License: GPL v2
]]

-- Required for JSON encoding/decoding
local json = require("dkjson")

-- Path to the config file (in VLC user data directory)
local CONFIG_FILE = vlc.config.userdatadir() .. "/audio_sub_prefs.json"

-- Global variables
local dialog = nil
local audio_tracks = {}
local subtitle_tracks = {}
local preferences = {}
local current_folder = nil
local ignore_change = false

-- Utility: Load preferences from JSON file
local function load_preferences()
    local file = io.open(CONFIG_FILE, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            local obj, _, err = json.decode(content)
            if obj then preferences = obj end
        end
    end
end

-- Utility: Save preferences to JSON file
local function save_preferences()
    local file = io.open(CONFIG_FILE, "w")
    if file then
        file:write(json.encode(preferences, { indent = true }))
        file:close()
    end
end

-- Get folder path from media URI
local function get_folder_from_uri(uri)
    if not uri then return nil end
    local path = vlc.strings.decode_uri(uri)
    -- Remove 'file://' prefix if present
    path = path:gsub("^file://", "")
    -- Remove filename
    local folder = path:match("(.*)[/\\]")
    return folder
end

-- Apply saved preferences for the current folder
local function apply_preferences()
    if not current_folder then return end
    local pref = preferences[current_folder]
    if not pref then return end
    -- Apply audio track
    for _, track in ipairs(audio_tracks) do
        if track.language == pref.audio then
            vlc.player.set_audio_track(track.id)
            break
        end
    end
    -- Apply subtitle track
    for _, track in ipairs(subtitle_tracks) do
        if (pref.subtitle == "OFF" and (track.language == nil or track.language == ""))
            or (track.language == pref.subtitle) then
            vlc.player.set_subtitle_track(track.id)
            break
        end
    end
end

-- Save current selection as preference for the folder
local function save_current_selection()
    if not current_folder then return end
    local audio_id = vlc.player.audio_track()
    local sub_id = vlc.player.subtitle_track()
    local audio_lang, sub_lang = nil, nil
    for _, track in ipairs(audio_tracks) do
        if track.id == audio_id then audio_lang = track.language end
    end
    for _, track in ipairs(subtitle_tracks) do
        if track.id == sub_id then sub_lang = track.language or "OFF" end
    end
    if audio_lang then
        preferences[current_folder] = { audio = audio_lang, subtitle = sub_lang or "OFF" }
        save_preferences()
    end
end

-- Listen for input changes (new file loaded)
function input_changed()
    if ignore_change then return end
    local item = vlc.input.item()
    if not item then return end
    local uri = item:uri()
    current_folder = get_folder_from_uri(uri)
    audio_tracks = vlc.player.get_audio_tracks() or {}
    subtitle_tracks = vlc.player.get_subtitle_tracks() or {}
    load_preferences()
    apply_preferences()
end

-- Listen for user changes (audio/subtitle track changed)
function meta_changed()
    -- Save the new selection as preference
    save_current_selection()
end

-- VLC extension descriptor
function descriptor()
    return {
        title = "Auto Audio/Sub Preferences",
        version = "1.0",
        author = "William",
        shortdesc = "Auto audio/subtitle per folder",
        description = "Automatically remembers and reapplies your audio and subtitle choices per folder.",
        capabilities = {"input-listener", "meta-listener"}
    }
end

function activate()
    -- No dialog needed, everything is automatic
    load_preferences()
    input_changed()
end

function deactivate()
    -- Nothing to clean up
end

function close()
    deactivate()
end 