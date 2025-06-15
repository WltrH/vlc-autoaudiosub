--[[
    AutoAudioSub - VLC extension for quick audio and subtitle track selection
    Copyright (C) 2024

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
]]

-- Configuration
local CONFIG_FILE = vlc.config.userdatadir() .. "/autosub_config.lua"
local OPENSUBTITLES_API_KEY = "YOUR_API_KEY" -- Replace with your OpenSubtitles API key

-- Global variables
local dialog = nil
local audio_tracks = {}
local subtitle_tracks = {}
local selected_audio = 0
local selected_subtitle = 0
local preferences = {}
local current_media_path = ""

-- Function to load preferences
local function load_preferences()
    local file = io.open(CONFIG_FILE, "r")
    if file then
        local content = file:read("*all")
        file:close()
        if content and content ~= "" then
            preferences = load("return " .. content)()
        end
    end
end

-- Function to save preferences
local function save_preferences()
    local file = io.open(CONFIG_FILE, "w")
    if file then
        file:write("return " .. vlc.strings.dump(preferences))
        file:close()
    else
        vlc.msg.err("Unable to save preferences")
    end
end

-- Function to get track name
local function get_track_name(track)
    if track and track.name and track.name ~= "" then
        return track.name
    elseif track and track.language and track.language ~= "" then
        return track.language
    else
        return "Track " .. track.id
    end
end

-- Function to check if a French subtitle exists
local function has_french_subtitle()
    for _, track in ipairs(subtitle_tracks) do
        if track.language == "fr" then
            return true
        end
    end
    return false
end

-- Function to search subtitles on OpenSubtitles
local function search_subtitles()
    local input = vlc.input.item()
    if not input then return end
    
    local filename = input:name()
    local hash = input:hash()
    
    -- Build OpenSubtitles request
    local url = "https://api.opensubtitles.com/api/v1/subtitles"
    local headers = {
        ["Api-Key"] = OPENSUBTITLES_API_KEY,
        ["Content-Type"] = "application/json"
    }
    
    local body = {
        query = filename,
        languages = "fr",
        moviehash = hash
    }
    
    -- Send request
    local response = vlc.net.http_post(url, headers, vlc.strings.dump(body))
    if not response then
        vlc.msg.err("Error while searching for subtitles")
        return
    end
    
    -- Process response
    local data = vlc.strings.from_json(response)
    if data and data.data and #data.data > 0 then
        local subtitle = data.data[1]
        local download_url = subtitle.attributes.files[1].file_url
        
        -- Download subtitle
        local subtitle_data = vlc.net.http_get(download_url)
        if subtitle_data then
            -- Save temporary file
            local temp_file = os.tmpname() .. ".srt"
            local file = io.open(temp_file, "w")
            if file then
                file:write(subtitle_data)
                file:close()
                
                -- Add subtitle to video
                vlc.player.add_subtitle(temp_file)
                
                -- Update subtitle list
                subtitle_tracks = vlc.player.get_subtitle_tracks()
                return true
            end
        end
    end
    
    vlc.msg.err("No French subtitles found")
    return false
end

-- Function to apply preferences
local function apply_preferences()
    local path = vlc.input.item():uri()
    local folder = path:match("(.*[/\\])")
    
    if preferences[folder] then
        local pref = preferences[folder]
        -- Apply audio preferences
        for _, track in ipairs(audio_tracks) do
            if track.language == pref.audio then
                vlc.player.set_audio_track(track.id)
                break
            end
        end
        
        -- Apply subtitle preferences
        for _, track in ipairs(subtitle_tracks) do
            if track.language == pref.subtitle then
                vlc.player.set_subtitle_track(track.id)
                break
            end
        end
    end
end

-- Function to create dialog window
local function create_dialog()
    -- Get audio and subtitle tracks
    audio_tracks = vlc.player.get_audio_tracks()
    subtitle_tracks = vlc.player.get_subtitle_tracks()
    
    -- Create dialog window
    dialog = vlc.dialog("Audio/Subtitle Selection")
    
    -- Create dropdown lists
    local audio_label = dialog:add_label("Audio:")
    local audio_list = dialog:add_dropdown()
    
    local subtitle_label = dialog:add_label("Subtitles:")
    local subtitle_list = dialog:add_dropdown()
    
    -- Fill lists
    for _, track in ipairs(audio_tracks) do
        audio_list:add_value(get_track_name(track), track.id)
    end
    
    for _, track in ipairs(subtitle_tracks) do
        subtitle_list:add_value(get_track_name(track), track.id)
    end
    
    -- Series/folder name field
    local folder_label = dialog:add_label("Series/Folder name:")
    local folder_input = dialog:add_text_input()
    
    -- Subtitle search button
    local search_button = nil
    if not has_french_subtitle() then
        search_button = dialog:add_button("Search subtitles", function()
            if search_subtitles() then
                -- Update subtitle list
                subtitle_list:clear()
                for _, track in ipairs(subtitle_tracks) do
                    subtitle_list:add_value(get_track_name(track), track.id)
                end
            end
        end)
    end
    
    -- Save preferences button
    local save_pref_button = dialog:add_button("Save preferences", function()
        local folder = folder_input:get_text()
        if folder and folder ~= "" then
            preferences[folder] = {
                audio = audio_tracks[audio_list:get_value()].language,
                subtitle = subtitle_tracks[subtitle_list:get_value()].language
            }
            save_preferences()
            vlc.msg.info("Preferences saved for " .. folder)
        else
            vlc.msg.err("Please enter a series/folder name")
        end
    end)
    
    -- OK and Cancel buttons
    local ok_button = dialog:add_button("OK", function()
        selected_audio = audio_list:get_value()
        selected_subtitle = subtitle_list:get_value()
        
        if selected_audio > 0 then
            vlc.player.set_audio_track(selected_audio)
        end
        if selected_subtitle > 0 then
            vlc.player.set_subtitle_track(selected_subtitle)
        end
        
        dialog:delete()
    end)
    
    local cancel_button = dialog:add_button("Cancel", function()
        dialog:delete()
    end)
    
    -- Show window
    dialog:show()
end

-- Extension descriptor function
function descriptor()
    return {
        title = "AutoAudioSub",
        version = "1.0",
        author = "Your Name",
        shortdesc = "Quick audio and subtitle track selection",
        description = "Opens a dialog window to quickly select audio and subtitle tracks",
        capabilities = {"input-listener"}
    }
end

-- Extension activation function
function activate()
    load_preferences()
    create_dialog()
    apply_preferences()
end

-- Extension deactivation function
function deactivate()
    if dialog then
        dialog:delete()
    end
end

-- Extension close function
function close()
    deactivate()
end
