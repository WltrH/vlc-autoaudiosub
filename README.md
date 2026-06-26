# auto_audio_sub

Extension VLC en Lua pour mémoriser et réappliquer automatiquement les pistes audio et sous-titres par dossier.

## Description

Quand tu ouvres un fichier dans un dossier déjà connu (par exemple une série), l'extension applique automatiquement tes derniers choix d'audio et de sous-titres. Plus besoin de reconfigurer à chaque épisode.

- Préférences sauvegardées localement par dossier (et sous-dossiers).
- Application automatique dès le chargement du fichier suivant.
- Résolution des pistes par label de langue — robuste même si les indices changent entre épisodes.
- Aucune dépendance externe — tout est en Lua natif.
- Compatible Windows, macOS, Linux (testé sur VLC 3.0.x macOS).

## Installation

1. Télécharge `auto_audio_sub.lua`.
2. Copie-le dans le répertoire extensions de VLC :
   - **Windows** : `%APPDATA%\vlc\lua\extensions\`
   - **macOS** : `~/Library/Application Support/org.videolan.vlc/lua/extensions/`
   - **Linux** : `~/.local/share/vlc/lua/extensions/`
3. Redémarre VLC.
4. Active l'extension via **Outils → Extensions → Auto Audio/Sub Preferences**.

## Utilisation

### Première fois sur un dossier

1. Lance un épisode dans VLC.
2. Active l'extension (**Outils → Extensions → Auto Audio/Sub Preferences**) — les pistes disponibles s'affichent automatiquement.
3. Sélectionne la piste audio et les sous-titres souhaités dans les menus déroulants.
4. Clique sur **Appliquer** — le changement est effectif immédiatement et la préférence est sauvegardée.

### Épisodes suivants

L'extension doit être active. Dès qu'un nouveau fichier du même dossier démarre, les pistes sont appliquées automatiquement — aucune action requise.

> L'extension recherche la préférence d'abord dans le dossier de l'épisode, puis dans le dossier parent. Cela permet de gérer les séries où chaque épisode est dans son propre sous-dossier.

## Interface

| Bouton | Action |
|--------|--------|
| **Rafraîchir** | Recharge les pistes du fichier en cours (utile si les menus sont vides) |
| **Appliquer** | Applique la sélection et sauvegarde la préférence pour ce dossier |
| **Infos** | Affiche le dossier courant et la préférence mémorisée |

## Exemple typique

Pour une série japonaise avec sous-titres français : ouvrir le premier épisode, sélectionner `Japanese` en audio et `French` en sous-titres, cliquer Appliquer. Tous les épisodes suivants du dossier (y compris ceux ajoutés plus tard) démarreront automatiquement avec ces réglages.

## Données locales

Les préférences sont stockées dans `audio_sub_prefs.lua` dans le répertoire de données utilisateur de VLC :

- **macOS** : `~/Library/Application Support/org.videolan.vlc/audio_sub_prefs.lua`
- **Windows** : `%APPDATA%\vlc\audio_sub_prefs.lua`
- **Linux** : `~/.local/share/vlc/audio_sub_prefs.lua`

## Licence

GNU General Public License v2.0 — voir le fichier LICENSE.
