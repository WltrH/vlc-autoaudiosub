--[[
    AutoAudioSub - Extension VLC pour la sélection rapide des pistes audio et sous-titres
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
local OPENSUBTITLES_API_KEY = "YOUR_API_KEY" -- À remplacer par votre clé API OpenSubtitles

-- Variables globales
local dialog = nil
local audio_tracks = {}
local subtitle_tracks = {}
local selected_audio = 0
local selected_subtitle = 0
local preferences = {}
local current_media_path = ""

-- Fonction pour charger les préférences
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

-- Fonction pour sauvegarder les préférences
local function save_preferences()
    local file = io.open(CONFIG_FILE, "w")
    if file then
        file:write("return " .. vlc.strings.dump(preferences))
        file:close()
    else
        vlc.msg.err("Impossible de sauvegarder les préférences")
    end
end

-- Fonction pour obtenir le nom de la piste
local function get_track_name(track)
    if track and track.name and track.name ~= "" then
        return track.name
    elseif track and track.language and track.language ~= "" then
        return track.language
    else
        return "Piste " .. track.id
    end
end

-- Fonction pour vérifier si une piste en français existe
local function has_french_subtitle()
    for _, track in ipairs(subtitle_tracks) do
        if track.language == "fr" then
            return true
        end
    end
    return false
end

-- Fonction pour rechercher des sous-titres sur OpenSubtitles
local function search_subtitles()
    local input = vlc.input.item()
    if not input then return end
    
    local filename = input:name()
    local hash = input:hash()
    
    -- Construction de la requête OpenSubtitles
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
    
    -- Envoi de la requête
    local response = vlc.net.http_post(url, headers, vlc.strings.dump(body))
    if not response then
        vlc.msg.err("Erreur lors de la recherche de sous-titres")
        return
    end
    
    -- Traitement de la réponse
    local data = vlc.strings.from_json(response)
    if data and data.data and #data.data > 0 then
        local subtitle = data.data[1]
        local download_url = subtitle.attributes.files[1].file_url
        
        -- Téléchargement du sous-titre
        local subtitle_data = vlc.net.http_get(download_url)
        if subtitle_data then
            -- Sauvegarde temporaire du fichier
            local temp_file = os.tmpname() .. ".srt"
            local file = io.open(temp_file, "w")
            if file then
                file:write(subtitle_data)
                file:close()
                
                -- Ajout du sous-titre à la vidéo
                vlc.player.add_subtitle(temp_file)
                
                -- Mise à jour de la liste des sous-titres
                subtitle_tracks = vlc.player.get_subtitle_tracks()
                return true
            end
        end
    end
    
    vlc.msg.err("Aucun sous-titre français trouvé")
    return false
end

-- Fonction pour appliquer les préférences
local function apply_preferences()
    local path = vlc.input.item():uri()
    local folder = path:match("(.*[/\\])")
    
    if preferences[folder] then
        local pref = preferences[folder]
        -- Application des préférences audio
        for _, track in ipairs(audio_tracks) do
            if track.language == pref.audio then
                vlc.player.set_audio_track(track.id)
                break
            end
        end
        
        -- Application des préférences sous-titres
        for _, track in ipairs(subtitle_tracks) do
            if track.language == pref.subtitle then
                vlc.player.set_subtitle_track(track.id)
                break
            end
        end
    end
end

-- Fonction pour créer la fenêtre de dialogue
local function create_dialog()
    -- Récupération des pistes audio et sous-titres
    audio_tracks = vlc.player.get_audio_tracks()
    subtitle_tracks = vlc.player.get_subtitle_tracks()
    
    -- Création de la fenêtre de dialogue
    dialog = vlc.dialog("Sélection Audio/Sous-titres")
    
    -- Création des listes déroulantes
    local audio_label = dialog:add_label("Audio:")
    local audio_list = dialog:add_dropdown()
    
    local subtitle_label = dialog:add_label("Sous-titres:")
    local subtitle_list = dialog:add_dropdown()
    
    -- Remplissage des listes
    for _, track in ipairs(audio_tracks) do
        audio_list:add_value(get_track_name(track), track.id)
    end
    
    for _, track in ipairs(subtitle_tracks) do
        subtitle_list:add_value(get_track_name(track), track.id)
    end
    
    -- Champ pour le nom de la série/dossier
    local folder_label = dialog:add_label("Nom de la série/dossier:")
    local folder_input = dialog:add_text_input()
    
    -- Bouton de recherche de sous-titres
    local search_button = nil
    if not has_french_subtitle() then
        search_button = dialog:add_button("Chercher sous-titres", function()
            if search_subtitles() then
                -- Mise à jour de la liste des sous-titres
                subtitle_list:clear()
                for _, track in ipairs(subtitle_tracks) do
                    subtitle_list:add_value(get_track_name(track), track.id)
                end
            end
        end)
    end
    
    -- Bouton de sauvegarde des préférences
    local save_pref_button = dialog:add_button("Sauvegarder préférences", function()
        local folder = folder_input:get_text()
        if folder and folder ~= "" then
            preferences[folder] = {
                audio = audio_tracks[audio_list:get_value()].language,
                subtitle = subtitle_tracks[subtitle_list:get_value()].language
            }
            save_preferences()
            vlc.msg.info("Préférences sauvegardées pour " .. folder)
        else
            vlc.msg.err("Veuillez entrer un nom de série/dossier")
        end
    end)
    
    -- Boutons OK et Annuler
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
    
    local cancel_button = dialog:add_button("Annuler", function()
        dialog:delete()
    end)
    
    -- Affichage de la fenêtre
    dialog:show()
end

-- Fonction de descripteur de l'extension
function descriptor()
    return {
        title = "AutoAudioSub",
        version = "1.0",
        author = "Votre Nom",
        shortdesc = "Sélection rapide des pistes audio et sous-titres",
        description = "Ouvre une fenêtre de dialogue pour sélectionner rapidement les pistes audio et sous-titres",
        capabilities = {"input-listener"}
    }
end

-- Fonction d'activation de l'extension
function activate()
    load_preferences()
    create_dialog()
    apply_preferences()
end

-- Fonction de désactivation de l'extension
function deactivate()
    if dialog then
        dialog:delete()
    end
end

-- Fonction de fermeture de l'extension
function close()
    deactivate()
end
