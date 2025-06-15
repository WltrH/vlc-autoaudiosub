# vlc-autoaudiosub
VLC extension in Lua for quick audio and subtitle track selection

## Description
This VLC extension provides a user-friendly interface to quickly select audio and subtitle tracks for your media files. It also includes features to:
- Save preferences for specific series/folders
- Automatically search for French subtitles on OpenSubtitles
- Remember your last selections

## Installation
1. Copy the `autoaudiosub.lua` file to your VLC extensions directory:
   - Windows: `%APPDATA%\vlc\lua\extensions`
   - macOS: `/Users/<username>/Library/Application Support/org.videolan.vlc/lua/extensions`
   - Linux: `~/.local/share/vlc/lua/extensions`

2. Restart VLC

## Usage
1. Open a media file in VLC
2. Go to View > AutoAudioSub in the menu
3. Select your preferred audio and subtitle tracks
4. Optionally save your preferences for the current series/folder

## Requirements
- VLC Media Player
- OpenSubtitles API key (optional, for subtitle search feature)

## License
This project is licensed under the GNU General Public License v2.0 - see the LICENSE file for details.
