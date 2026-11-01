# Dustbound Frontier — മലയാളം ഇൻസ്റ്റലേഷൻ

### 1. Godot-ൽ ഗെയിം തുറക്കാം
1. **Dustbound_Frontier.zip** Windows PC-യിൽ Download ചെയ്ത് Extract ചെയ്യുക.
2. **Godot 4** ഇൻസ്റ്റാൾ ചെയ്യുക: https://godotengine.org/download/windows/
3. Godot → **Import** → Extract ചെയ്ത folder-ലുള്ള **project.godot** തിരഞ്ഞെടുക്കുക.
4. Project തുറക്കുക. Godot Editor-ൽ **F5** അമർത്തുക. ഗെയിം തുടങ്ങും.
5. Game run ചെയ്യുമ്പോൾ **W A S D** ഉപയോഗിച്ച് നടക്കുക, Mouse ഉപയോഗിച്ച് ക്യാമറ തിരിക്കുക.

### 2. Horse riding / Combat
- **E** = കുതിരയിൽ കയറുക / ഇറങ്ങുക / NPC-യോട് സംസാരിക്കുക
- **F** = കുതിരയെ വിളിക്കുക
- **Shift** = വേഗത്തിൽ ഓടുക / Gallop
- **Mouse Left** = വെടിവെക്കുക
- **Mouse Right** = Aim
- **R** = Reload
- **F5 (game window)** = Save
- **F9** = Load
- **ESC** = Pause menu

### 3. ആദ്യ Mission
Sheriff Office-ന്റെ അടുത്തുള്ള **Marshal Reed**-നെ കാണുക. **E** അമർത്തി mission ഏറ്റെടുക്കുക. തുടർന്ന് കുതിരയിൽ **Coyote Ridge** camp-ലേക്ക് യാത്ര ചെയ്ത് മൂന്ന് bandits-നെ തോൽപ്പിക്കുക. വീണ്ടും Sheriff-ന്റെ അടുത്തെത്തിയാൽ $75 reward ലഭിക്കും.

### 4. Blender-ൽ തുറക്കാം
**Blender → File → Import → glTF 2.0** വഴി **assets/frontier_town_preview.glb** import ചെയ്യുക. Edit ചെയ്യാൻ കഴിയുന്ന original 3D town preview ഇതിലുണ്ട്.

പുതിയ `.blend` Blender file നിർമ്മിക്കാൻ: Blender → **Scripting** → **blender/build_frontier.py** open → **Run Script**. ഇതിലൂടെ editable `.blend` ഫയൽ സേവ് ചെയ്യും.

### 5. Windows .exe ഉണ്ടാക്കാം
Godot → **Editor → Manage Export Templates** വഴി Windows export templates install ചെയ്യുക. തുടർന്ന് **Project → Export → Windows Desktop → Export Project**.

**പ്രധാനപ്പെട്ട കാര്യം:** ഇത് ഒരു ചെറിയ *playable prototype* ആണ്; Red Dead Redemption 2 പോലൊരു പൂർണ്ണ AAA ഗെയിം ഇതുവരെ അല്ല. ഇവിടെയുള്ള environment-ൽ Godot/Blender ഇല്ലാത്തതിനാൽ run ചെയ്ത് test ചെയ്യാൻ കഴിഞ്ഞിട്ടില്ല.

### 6. ഈ പതിപ്പിലെ തിരുത്തലുകൾ
- ഭൂമി (terrain) തെറ്റായ ദിശയിലായിരുന്നതിനാൽ കളിക്കാരൻ നിലത്തിലൂടെ താഴേക്ക് വീഴുമായിരുന്നു. അത് ശരിയാക്കി.
- Minimap-ലെ ഒരു തെറ്റ് (`player_ref.y`) ഓരോ frame-ലും error കാണിച്ചിരുന്നു. ശരിയാക്കി.
- കുതിരപ്പുറത്തിരിക്കുമ്പോൾ വെടിയുണ്ട സ്വന്തം കുതിരയിൽ തട്ടുന്നത് ശരിയാക്കി. ഇപ്പോൾ സവാരിക്കാരൻ കുതിരപ്പുറത്ത് കാണാം.
- `frontier_town_preview.glb` കറുത്ത നിറത്തിൽ കാണുന്നതും തൂണുകൾ കിടന്നുപോകുന്നതും ശരിയാക്കി.
- വിശദാംശങ്ങൾ: `docs/VALIDATION_REPORT.md`.

Godot-ൽ ആദ്യമായി run ചെയ്യുമ്പോൾ **Output** panel-ൽ error കണ്ടാൽ, file പേരും line നമ്പറും അയച്ചുതരിക.
