# Cytoid Player Branch Summary

> Branch: `feature/cytoid-player`  
> Base: `main` (`b875d780`)  
> Last updated: 2026-06-29

## Purpose

Add a standalone **Cytoid Player** Windows PC executable to the Unity core so users can launch the game directly on Windows without the Flutter host. The player includes:

- A PC-native menu for importing `.cytoidlevel` files, selecting installed levels, and choosing difficulty.
- An in-game HUD with play/pause, fullscreen toggle, back, and timeline scrubbing.
- A Windows x64 IL2CPP build pipeline.

## Commits on this branch (before cleanup)

| Commit | Message | Summary |
|--------|---------|---------|
| `331cf80d` | `feat(player): add Cytoid Player for Windows PC` | Initial player menu, HUD, `Game.Seek`, and Windows build method. |
| `ba2b8dca` | `fix(player): resolve compiler errors for Windows standalone build` | Fix `Screen` naming conflict, platform guards, IL2CPP build errors. |
| `e038c9b6` | `fix(build): use NamedBuildTarget.Standalone for Unity 6 compatibility` | Use `NamedBuildTarget.Standalone` instead of deprecated `BuildTargetGroup.Standalone`. |
| `4692e245` | `fix(build): guard Vibration APIs behind platform conditionals for Windows` | Guard `Vibration` usage on Windows. |
| `e91f75f1` | `fix(build): guard Vibration.Init behind platform conditionals` | Guard `Vibration.Init()` call. |
| `e5579f9f` | `fix(player): hide legacy debug UI, improve fullscreen/resolution, add hotkey hints` | Disable legacy debug canvas on Windows, force windowed mode, add hotkey hints. |
| `45043e2c` | `fix(player): force windowed mode on Windows PC to fix black fullscreen` | Ensure Windows player starts in windowed mode. |

## Key changes

### New files

- `engines/unity/Assets/Scripts/Navigation/CytoidPlayerMenuController.cs`
  - Runtime-built PC menu: title, import button, level list, difficulty selector, start button.
  - Windows `OpenFileDialog` P/Invoke for `.cytoidlevel` import.
  - Command-line `.cytoidlevel` import on launch.
- `engines/unity/Assets/Scripts/Game/CytoidPlayerHudController.cs`
  - Runtime-built in-game HUD: Back, Fullscreen/Windowed, Play/Pause, time display, timeline slider.
  - Hotkeys: `F11` toggle fullscreen, `ESC` exit fullscreen / pause.

### Modified files

- `engines/unity/Assets/Scripts/Context.cs`
  - Force `FullScreenMode.Windowed` on `UNITY_STANDALONE_WIN`.
  - Guard `Vibration.Init()` / haptic APIs behind mobile platforms.
  - Inject `CytoidPlayerMenuController` in `InitializeDebugNavigation()` for Windows PC builds.
- `engines/unity/Assets/Scripts/Game/Game.cs`
  - Add `Seek(float targetTime)` for timeline scrubbing.
- `engines/unity/Assets/Scripts/Navigation/DebugNavigationController.cs`
  - Hide legacy debug navigation Canvas on Windows PC builds.
- `engines/unity/Assets/Scripts/Editor/CytoidCoreBuild.cs`
  - Add `BuildCytoidPlayerWindows64()` Editor menu item and batchmode entry point.
  - Configure Windows standalone product name, window size, and windowed mode.
- `engines/unity/Assets/link.xml`
  - Preserve runtime-created UGUI types (`Canvas`, `Text`, `Button`, `Slider`, etc.) and the two new player controllers so IL2CPP does not strip them.
- `engines/unity/ProjectSettings/ProjectSettings.asset`
  - Update default screen width/height and fullscreen mode for the standalone player.

## Uncommitted fixes (latest)

After the most recent build verification, the following additional fixes were applied but not yet committed:

- **Fixed black screen in standalone build**: `CreateButton` was missing a `LayoutElement` component; callers then hit `NullReferenceException` when setting `preferredHeight`/`preferredWidth`. Added `LayoutElement` to every dynamically created button.
- **Fixed runtime `RectTransform` creation**: changed all runtime UI object creation from `new GameObject(...)` + `AddComponent<RectTransform>()` to `new GameObject(name, typeof(RectTransform))`, which is reliable in IL2CPP builds.
- **Added fallback font loading**: if `Resources.Load<Font>("Fonts/Nunito-Regular")` fails in a build, fall back to Unity's built-in legacy font.
- **Hardened UI construction**: wrapped `BuildUi()`/`BuildHud()` in try/catch with clear error logging.
- **Minor layout polish**: menu buttons are now centered and constrained to a reasonable width instead of stretching edge-to-edge.

## Build & verification

- Build entry point: `CytoidCoreBuild.BuildCytoidPlayerWindows64()`
- Batchmode command:
  ```bash
  "C:\Program Files\Unity\Hub\Editor\6000.0.75f1\Editor\Unity.exe" \
    -batchmode -quit \
    -projectPath "E:/Code/Cytoid/engines/unity" \
    -executeMethod CytoidCoreBuild.BuildCytoidPlayerWindows64
  ```
- Output: `engines/unity/Builds/CytoidPlayer/CytoidPlayer.exe`
- Verified: the Windows x64 IL2CPP build launches in a 1280×720 window and displays the Cytoid Player menu; Import button opens the file picker; difficulty selection and Start Game button render correctly.

## Fixed after initial verification

- **Import no longer deletes the source file**: `InstallLevels` now accepts a `deleteSource` parameter; user imports from the file picker keep the original `.cytoidlevel`.
- **Imported levels appear in the list**: `InstallUserCommunityLevels` and the manual import path now call `LoadLevelsOfType(LevelType.User)` after installation so `LoadedLocalLevels` is populated and the UI refreshes.

## Added level management & selection visibility

- **Rich level list items**: each installed level now shows title, localized title, artist, charter, and available difficulties instead of a single-line button.
- **Explicit Select / Delete buttons**: every level row has a dedicated `Select` button and a red `Delete` button.
- **Delete confirmation**: tapping `Delete` once changes the label to `Sure?`; a second tap removes the level from disk and refreshes the list.
- **Current selection highlight**: the selected level row is highlighted in blue and the menu status bar displays `Selected: <Title> [<difficulty> <level>]`.
- **Current level shown in HUD**: the in-game top bar now shows `Title  ·  <difficulty> <level>` so the user always knows which chart is playing.

## Added seek sync, auto-hide HUD, Auto/hitsound toggles, and instant pause

- **Seek audio/chart sync fixed**: `Game.Seek()` now stops the music, seeks the audio source to the target sample, restarts playback, and rebuilds `MusicStartedTimestamp` without double-applying chart/music offsets. This keeps the chart and audio aligned after scrubbing the timeline.
- **HUD auto-hide**: the top and bottom HUD bars slide off-screen when the mouse is away and slide back in when the cursor reaches the top/bottom edge (or while dragging the timeline), so they no longer cover the playfield.
- **Auto mode toggle**: an `Auto: Off/On` button is now in the HUD top bar alongside Back/Play, and can be toggled mid-game.
- **Hitsound toggle**: a `Hitsound: On/Off` button is also in the HUD top bar; it switches `Context.Player.Settings.HitSound` between `"click1"` and `"none"`.
- **Instant pause/resume**: the PC player sets `Game.UseInstantPauseResume = true`, skipping the `PausedScreen` and the 3-second unpause countdown.

## Import UI fixes

- **Level list visibility**: the scroll area now has `minHeight = 120`, `flexibleHeight = 1`, `minWidth = 400`, and `flexibleWidth = 1`, so it expands to fill available menu space and remains visible even on small/tall windows.
- **Direct user-level loading on PC**: `RefreshLevelList` now calls `LoadLevelsOfType(LevelType.User)` directly on Windows, instead of relying on `InstallUserCommunityLevels()` which only scans for `.cytoidlevel` package files in `UserDataPath`. This ensures already-installed level folders are loaded on startup.
- **Vertical scrollbar**: a visible scrollbar is now attached to the level list for easier scrolling.
- **Auto-select imported level**: after importing a `.cytoidlevel` file, the menu automatically selects the newly imported level so the user can start it immediately.

## Known limitations / next steps

- The in-game HUD has been hardened but not fully exercised in a real chart playthrough.
- `GraphyManager` is referenced in `Context.UpdateProfilerDisplay()` but not present in the `Navigation` scene, causing harmless singleton warnings in the player log.
- No built-in levels are bundled with the player; users must import `.cytoidlevel` files.

## Files changed vs `main`

```
engines/unity/.gitignore
engines/unity/Assets/Scripts/Context.cs
engines/unity/Assets/Scripts/Editor/CytoidCoreBuild.cs
engines/unity/Assets/Scripts/Game/CytoidPlayerHudController.cs (new)
engines/unity/Assets/Scripts/Game/CytoidPlayerHudController.cs.meta (new)
engines/unity/Assets/Scripts/Game/Game.cs
engines/unity/Assets/Scripts/Navigation/CytoidPlayerMenuController.cs (new)
engines/unity/Assets/Scripts/Navigation/CytoidPlayerMenuController.cs.meta (new)
engines/unity/Assets/Scripts/Navigation/DebugNavigationController.cs
engines/unity/Assets/link.xml
engines/unity/ProjectSettings/ProjectSettings.asset
```
