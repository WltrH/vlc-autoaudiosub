# auto_audio_sub
VLC extension in Lua to automatically remember and reapply audio and subtitle track choices per folder

## Description
This VLC extension automatically remembers your audio and subtitle track choices for each folder (for example, a TV series folder). When you open another file in the same folder, your last choices are automatically reapplied—no need to set them again.

- Preferences are saved in a local JSON file for each folder.
- Works automatically: no need to click any button or open a dialog.
- Compatible with Windows, macOS, and Linux.

## Installation
1. Download the following files:
   - `auto_audio_sub.lua` (this extension)
   - [`dkjson.lua`](https://github.com/LuaDist/dkjson/blob/master/dkjson.lua) (JSON library for Lua)
2. Place both files in your VLC extensions directory:
   - **Windows**: `%APPDATA%\vlc\lua\extensions`
   - **macOS**: `/Users/<your_user>/Library/Application Support/org.videolan.vlc/lua/extensions`
   - **Linux**: `~/.local/share/vlc/lua/extensions`
3. Restart VLC.

## Usage
- Open a video file in VLC.
- Select your preferred audio and subtitle tracks (using VLC's standard controls).
- The extension will automatically save your choice for the folder.
- When you open another file in the same folder, your preferences will be applied automatically.

## Requirements
- VLC Media Player
- `dkjson.lua` (must be in the same folder as the extension)

## Local Data
- Preferences are stored in a file named `audio_sub_prefs.json` in VLC's user data directory. This file is local and should be added to your `.gitignore` if you use version control.

## License
This project is licensed under the GNU General Public License v2.0 - see the LICENSE file for details.
