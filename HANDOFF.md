# Handoff: windowlog (RustDesk fork)

Read `AGENTS.md` first. Its rules apply to everything below.

## What this fork is

A rebrand of RustDesk called **windowlog**, with one product feature:
**"close to tray" for the Connection Manager (CM) window on Windows.**

Branch: `windowlog-cm-tray` on `https://github.com/ancientdev0x/rustdesk`.
Base: upstream commit `392188596`.

## The feature

When someone connects *to* this PC, RustDesk starts a separate `--cm` process
that shows the Connection Manager window. Upstream, closing that window kicks
the remote user. Users asked for it to minimize to tray instead.

| Action (Windows only) | Result |
|---|---|
| X on the CM, or Alt+F4 | CM hides, the taskbar button disappears, a tray icon appears, the session stays connected |
| Click the tray icon, or tray → Open | CM is restored and the tray icon is removed |
| Tray → Disconnect | Existing close path: `closeAll`, then the CM process exits. The main app and the service keep running |
| The remote side disconnects while hidden | CM exits as before and the tray icon is removed |
| A new connection or chat message arrives while hidden | CM is shown again (`showCmWindow` restores it), so a new request is never hidden |
| Linux / macOS | Unchanged |

Decisions already made. Don't re-open them without the owner:
- The tray icon belongs to the **CM process** (Flutter `tray_manager` 0.5.3),
  not to the existing `--tray` process. That process only runs when the
  service is installed, and using it would need new IPC.
- "Disconnect" closes **only** the sessions and the CM, not the main
  window or the service.
- The tray icon is always visible while the CM is hidden. It is the user's
  only sign that someone is connected. No option to hide it.
- The menu reuses existing translation keys (`Open`, `Disconnect`), so no
  `src/lang` changes.

Files:
- `flutter/lib/desktop/widgets/cm_tray.dart` (new): tray icon, menu, tooltip.
- `flutter/lib/desktop/pages/server_page.dart`: Windows hooks in
  `handleWindowCloseButton` (returns `false` after hiding), `onWindowClose`,
  `onRemoveId`, `initState`, `dispose`.
- `flutter/lib/main.dart`: `setPreventClose(true)` for the CM on Windows.
  `showCmWindow` restores from the tray.
- `flutter/assets/tray-icon.ico` (copied from `res/tray-icon.ico`).
- `flutter/pubspec.yaml` / `pubspec.lock`: `tray_manager`, `menu_base`,
  `shortid` (hand-added lock entries, no other lock churn).

## The rename

- Binary and EXE metadata: `Cargo.toml`, `build.py`,
  `flutter/windows/CMakeLists.txt`, `flutter/windows/runner/Runner.rc`.
- Runtime name: `init_app_name()` in `src/common.rs` sets
  `hbb_common::config::APP_NAME` to `windowlog` when it is still the default
  `RustDesk`, so a custom-client `app-name` still wins. It is called from every
  entry point (`main.rs`, `core_main.rs`, `flutter.rs`, `flutter_ffi.rs`,
  `service.rs`).
- Consequence: `is_custom_client()` is now true. That is RustDesk's
  white-label mode:
  - auto-update is off (intended, otherwise it would update to RustDesk);
  - "Powered by RustDesk" shows on the home page;
  - lang/theme defaults change;
  - the "Hide connection management window" option becomes available.
- Config dir is now `%APPDATA%\windowlog`, so old RustDesk settings and the
  ID don't carry over.
- Deliberately kept as "RustDesk": the 2FA issuer (`src/auth_2fa.rs`),
  because changing it breaks existing authenticators, plus internal
  identifiers and the crate/lib names (`librustdesk`).

## Status

- [x] Feature implemented and reviewed
- [x] Rename implemented and reviewed
- [x] First Windows build done on the friend's laptop (from an older commit of this branch; rebuild with the latest code)
- [ ] Manual test matrix (below) not run yet
- [ ] Before distributing: publish the source (AGPL-3.0), and run your own
      `hbbs`/`hbbr` instead of RustDesk's public servers

## Windows setup (once)

Install these exact versions; the project is pinned to them:

| Tool | Version |
|---|---|
| Visual Studio 2022 Build Tools | "Desktop development with C++" workload |
| Git, Python 3 | latest |
| LLVM | **15.0.6** (set `LIBCLANG_PATH=C:\Program Files\LLVM\bin`) |
| Rust | **1.75** (`rustup default 1.75`) |
| Flutter | **3.24.5** (`C:\flutter\bin` on PATH) |
| GitHub CLI | latest, then `gh auth login` |

```powershell
git clone https://github.com/microsoft/vcpkg C:\vcpkg
cd C:\vcpkg; git checkout 9e593bb18ea69cc5095e012465dcd675a822ed0d; .\bootstrap-vcpkg.bat
setx VCPKG_ROOT C:\vcpkg
setx LIBCLANG_PATH "C:\Program Files\LLVM\bin"
# open a new PowerShell after setx

mkdir C:\src -Force; cd C:\src
git clone --branch windowlog-cm-tray --recurse-submodules https://github.com/ancientdev0x/rustdesk.git windowlog
cd windowlog
C:\vcpkg\vcpkg install --triplet x64-windows-static --x-install-root="C:\vcpkg\installed"

# Generated FFI bridge files (gitignored). Taken from upstream CI run 38844847670
# (commit 53996e3c4), whose src/flutter_ffi.rs matches ours. Do NOT run
# flutter_rust_bridge_codegen. If src/flutter_ffi.rs function signatures change,
# these must be regenerated (see .github/workflows/bridge.yml).
gh run download 38844847670 --repo rustdesk/rustdesk -n bridge-artifact -D .
```

## Build

Full release build (output in `flutter\build\windows\x64\runner\Release\`;
ship the whole folder, because `windowlog.exe` needs `librustdesk.dll`):

```powershell
python build.py --portable --flutter --skip-portable-pack --hwcodec
```

A faster dev loop for Dart-only changes, with hot reload:

```powershell
cargo build --features flutter --lib     # once, or after Rust changes
cd flutter; flutter run -d windows
```

`flutter pub get` on a different Flutter version rewrites `pubspec.lock`.
Don't commit lock changes beyond the three tray packages.

## Manual test matrix

Testing needs a second machine: the friend, or the official RustDesk client
connecting to this PC's ID.

1. Someone connects, then X on the CM: hidden, no taskbar button, the tray
   icon shows, the session stays alive. The tooltip reads `windowlog (1)`.
2. Same with Alt+F4.
3. Click the tray icon: the CM is restored and the tray icon disappears.
4. Tray → Disconnect: the remote user is kicked, the CM exits, no ghost tray
   icon, the main window and service are unaffected.
5. Hidden, then the remote disconnects: the CM exits with no ghost icon.
6. Hidden, then a second person connects: the CM reappears with the request.
7. Two sessions, hide, restore: both intact. Disconnect closes both.
8. Rename: Task Manager shows `windowlog.exe`, window titles say windowlog,
   `windowlog://<id>` opens the app, a second launch focuses the existing
   window.

## Known limits (accepted, don't fix without the owner)

- The tooltip count updates when a peer leaves but not when one joins (a
  join restores the window anyway).
- Alt+F4 in the first instant after the CM appears can close it normally,
  because `setPreventClose` runs after `showCmWindow`.

## Workflow

- Work on `windowlog-cm-tray`. `git pull` before you start, and commit and
  push when done.
- Fix bugs in the files listed above. Keep diffs minimal, per `AGENTS.md`.
- When a bug is found, note it with steps to reproduce under "Status" here
  before fixing it.
