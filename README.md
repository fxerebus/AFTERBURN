# AFTERBURN HUB — Stage 1 (shell + scaffold)

> Beyond Speed. Beyond Limits.

Stage 1 delivers the project structure, the design-token layer, the mobile-first layout
engine, and the branded shell: window chrome, collapsible sidebar, nine-tab navigation
rail, and a dark/light theme pair. Pages are mountable stubs on purpose. **No live data,
no gameplay automation.**

---

## 1. What exists right now

| Area | State |
| --- | --- |
| `src/Config.lua` | Brand strings, layout thresholds, theme default, PlaceId plugin registry, `live.enabled = false` |
| `src/Core/Theme.lua` | Two complete token sets (dark default, light variant), one accessor, no colour literals anywhere else |
| `src/Core/Layout.lua` | Breakpoints, scale clamping, 44 px targets computed *after* scale, reflow decisions |
| `src/Core/UIManager.lua` | ScreenGui mount, safe inset, scaling, theme broadcast, teardown |
| `src/Core/Shell.lua` | Header, drag, collapse, content host, status bar |
| `src/Core/Navigation.lua` | Registry, selection, history, mount/unmount, teardown |
| `src/Core/NotificationManager.lua` | Bounded toast queue with severity |
| `src/Components/` | `Buttons`, `Toggles`, `Cards` — only the controls the shell itself uses |
| `src/Pages/` | Nine descriptors; each loads standalone, mounts a placeholder card |
| `src/main.lua` | Contained boot plus in-UI fault banner |
| `Build.lua` | `ORDER` bundler, aborts on any drift between disk and list |
| `tests/` | Roblox mock, self-testing linter, suite runner |

Not in Stage 1: real page content, persistence, auth, the Luarmor path, any HTTP.

---

## 2. Windows + VS Code setup

1. Install **Lua 5.4** for Windows (`winget install DEVCOM.Lua`, or build from lua.org) and
   confirm `lua -v` prints `Lua 5.4` in a **new** terminal — a stale terminal keeps the old PATH.
2. Open the `afterburn/` folder itself in VS Code, so `${workspaceFolder}` resolves here.
3. Install the **Lua** extension (sumneko) for diagnostics, or **Lua Debug** (actboy168) to
   run the launch configs in `.vscode/launch.json`.
4. `git init` and commit before you start editing; the scaffold is the baseline.

The suite needs only the Lua binary. Roblox APIs are mocked at `tests/harness.lua`, so
nothing here requires Studio.

---

## 3. How to run and test

```bat
:: full suite — lint, theme, layout, nav, page isolation, build guard
lua tests\run_all.lua

:: linter alone (self-tests against broken fixtures first)
lua tests\lint.lua

:: rebuild the single-file bundle into dist\Afterburn.lua
lua Build.lua
```

`run_all.lua` prints one `PASS`/`FAIL` line per check and exits `1` if anything fails.
Read the exit code, not just the scrollback — a failing line in a long log is easy to miss.

### In Roblox Studio (Stage 1 visual check)

There is no runtime in the dev loop, so this is the only place layout becomes real:

1. New Baseplate, **View → Explorer**.
2. `StarterPlayerScripts` → insert **LocalScript**.
3. `lua Build.lua`, paste all of `dist/Afterburn.lua` into the script.
4. **Test → Device** → pick *iPhone 14* or *Pixel 6*; leave `Device Emulator` on.
5. Press **F5**. The shell should mount inset, rail in icon mode, nothing clipped.
6. Drag the header, collapse the sidebar, cycle every tab, toggle dark/light in Settings.
7. In Device Emulator, rotate and switch to *Desktop* mid-session: layout must reflow, not scale down.

Expected warnings under Studio: `getgenv` / `gethui` / `identifyexecutor` absent. Those are
feature-detected, not errors, and Stage 1 must survive all three being nil.

---

## 4. Architecture rules

- **One module, one job.** `AB.Require("Core.Theme")` is the only cross-module access.
- **No colour literals** outside `Theme.lua`. The linter fails a hex or `Color3` call anywhere else.
- **Touch sizing is derived, not typed.** Ask `Layout` for a target; never hardcode 44.
- **Reflow beats shrink.** Under `compact`, the rail drops labels and the drawer overlays.
- **Privileged calls are probed**, never assumed: `getgenv`, `gethui`, `writefile`, `task`.
- `ORDER` in `Build.lua` is authoritative. Add a module → add it to `ORDER`, or the build refuses.

---

## 5. Adding a module

1. Create the file under `src/`.
2. `local AB = AB or _G.AFTERBURN`, then `local Theme = AB.Require("Core.Theme")` (or `"Core.X"` / `"Pages.X"`).
3. `return` one table. Prefix internals with the module name; expose only the public surface.
4. Append the path to `ORDER` in `Build.lua`, after anything it requires.
5. `lua tests\run_all.lua && lua Build.lua`.

---

## 6. Stage 1 limits

Geometry is verified as arithmetic, not pixels — the layout math is unit-tested, but the
first true confirmation comes from step 5 above. Iconography is placeholder glyph text,
so any real icon sheet is a swap in `Shell.lua`. Privileged behaviour is inert under
Studio by design; a green run does not prove executor behaviour.

---

## 7. Install from GitHub

The hub installs the way QuantumOnyx does: one line, fetched from a raw URL. Publish
the repo once (`docs/GITHUB.md`) and the line is:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_GITHUB_USER/AFTERBURN/main/Loader.lua?v=" .. os.time()))()
```

`Loader.lua` is the only stable address, so an update never invalidates a shared
one-liner. It refuses a stale executor, refuses its own stale copy against the
published version, and shows any failure on screen rather than in a collapsed
console. Users never touch `dist/Afterburn.lua` directly — it is generated.

**Uploading a LocalScript instead?** That path still works for local testing: the
bundle is ordinary Lua with no `HttpGet`. But it pins the bytes at the moment you
paste, so a hosted loader is the better default for anything you hand to someone else.

**Never point a loader at `src/main.lua`.** It is the source entry, not the bundle;
there is no module loader over raw, so it stalls on its first `Require`.

Repo requirements that bite if missed: the repo must be **public** (raw URLs on
private repos need a token header, which `game:HttpGet` does not send), and the
`YOUR_GITHUB_USER` placeholder in `Loader.lua` must be replaced.

<!-- build:begin -->
## 8. Last build

`dist/Afterburn.lua` at **v1.0.0** — 25 modules, 110408 bytes. Regenerate with `lua Build.lua`; never edit the bundle.
<!-- build:end -->
