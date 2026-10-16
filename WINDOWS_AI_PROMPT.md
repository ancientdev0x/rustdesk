# Prompt for the AI agent on the Windows laptop

Copy everything below the line into the AI agent (Claude Code, agy, ...),
opened in the repo folder (e.g. `C:\src\windowlog`).

---

You are continuing work on **windowlog**, a RustDesk fork, on a Windows laptop.
Read `AGENTS.md` and `HANDOFF.md` in the repo root before doing anything. They
define the rules, the feature, the decisions already made, and the test matrix.
Don't re-open decisions listed there.

## Environment: already set up, don't reinstall

This laptop has already built the project once. The following are in place:
- the toolchain (VS Build Tools, LLVM 15.0.6, Rust 1.75, Flutter 3.24.5);
- vcpkg (`VCPKG_ROOT`) with libraries installed;
- the generated bridge files (`src/bridge_generated*.rs`,
  `flutter/lib/generated_bridge*.dart`). These are gitignored, so `git pull`
  leaves them alone.

Check this quickly instead of reinstalling: `rustc --version` (1.75.x),
`flutter --version` (3.24.5), `echo $env:VCPKG_ROOT`,
`Test-Path src\bridge_generated.rs`. Fix only what's actually missing, using
the commands in `HANDOFF.md`. Do NOT run `flutter_rust_bridge_codegen`.

## Step 1: get the latest code

The earlier build may be from an older commit of branch `windowlog-cm-tray`.
1. Run `git status`. The earlier build probably modified `flutter/pubspec.lock`
   (`flutter pub get` rewrites it). Discard that with
   `git checkout -- flutter/pubspec.lock`. If anything else is modified, list
   it and ask me before discarding.
2. Run `git checkout windowlog-cm-tray`, then `git pull`, then
   `git submodule update --init --recursive`.
3. Run `git log --oneline -8` and tell me which commits are new compared to
   what was built before, if you can tell (e.g. from the build output's
   timestamp versus commit dates).

## Step 2: rebuild (incremental, so it should be much faster than the first time)

```powershell
python build.py --portable --flutter --skip-portable-pack --hwcodec
```
- Output: `flutter\build\windows\x64\runner\Release\` (`windowlog.exe` plus
  `librustdesk.dll`).
- If it fails, show me the error (last ~60 lines). Then fix it ONLY if the
  cause is clearly in this branch's changes (see the file list in
  `HANDOFF.md`). Environment problems: fix the environment, not the code.
- For later Dart-only iterations, use the faster loop from `HANDOFF.md`
  (`cargo build --features flutter --lib`, then
  `cd flutter; flutter run -d windows`).
- After building, run `git checkout -- flutter/pubspec.lock` again, so the
  rewritten lock is never committed.

## Step 3: test with me

Run `windowlog.exe` from the Release folder. I will connect from another
machine using its ID. Walk me through the **manual test matrix** in
`HANDOFF.md` one case at a time: tell me what to do, then ask what I saw.
Record the results as a pass/fail table.

## Step 4: fix bugs

For each failing case:
1. Add it to the "Status" section of `HANDOFF.md`, with the reproduction
   steps, before changing code.
2. Find the cause, and fix it with the smallest diff in the files that
   belong to the feature (`cm_tray.dart`, `server_page.dart`, `main.dart`)
   or the rename (`src/common.rs` `init_app_name`, etc.).
3. Follow `AGENTS.md`:
   - no refactors;
   - no fixes for unrelated pre-existing bugs;
   - no new state or complexity for rare cosmetic corner cases (list those
     under "Known limits" instead);
   - Linux/macOS behavior must stay unchanged.
4. Rebuild, retest that case, and also retest cases 1, 3 and 4 to catch
   regressions.

## Step 5: commit and push

- Use one commit per logical fix, with clear messages. Never commit
  `flutter/pubspec.lock` changes, build output, or the bridge files.
- Update `HANDOFF.md`: tick the checklist items that are now done, refresh
  the status, and add any new known limits.
- Run `git push` to `windowlog-cm-tray`. If the push is rejected for
  permissions, tell me; don't change remotes.

## Final report

1. The commit that was built.
2. Whether the build succeeded, and how long it took.
3. The test matrix results.
4. The bugs fixed (commit list).
5. Anything still open.
