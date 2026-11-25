# Publishing AFTERBURN from GitHub

This is the QuantumOnyx install pattern without the parts you don't need. Someone
pastes one line into an executor, the line fetches a file, the file runs. That is
all `loadstring(game:HttpGet(...))()` ever was — the rest of QuantumOnyx's package
services its commercial side (Luarmor key checks, two ad gateways, tiered script
editing) and none of it is required for a public hub.

---

## 1. Why a public repo

`raw.githubusercontent.com` serves public files to anyone, with `text/plain` and a
wildcard CORS header, which is exactly what `game:HttpGet` in an executor accepts.

A **private** repo breaks it. Raw URLs on private repos return `401` unless the
request carries an `Authorization: Bearer <token>` header, and `game:HttpGet(url)`
does not send one. There is no URL shape that fixes this, so:

- **Public** — required for the plain one-liner.
- **Private** — possible only if you later add a token fetch and a header-capable
  HTTP call, which some executors do not expose.

The trade: public means anyone can read `src/`. QuantumOnyx has it both ways — its
free file is readable and its real logic sits behind a hashed Luarmor CDN object.
Gate it that way at Stage 7 if it starts to matter.

---

## 2. Branch split

Source and artefact never share a branch.

| Branch | Holds | Written by |
| --- | --- | --- |
| `main` | `src/`, `tests/`, `Build.lua`, `Loader.lua`, docs. **Not** `dist/` | you |
| `dist` | `Afterburn.lua` and `VERSION`, at the branch root. Nothing else | `publish.yml` only, by force-push |

`dist/` stays in `.gitignore` on purpose, so a local build can't be committed by
accident on `main` and a source change can never be mistaken for a release. The
`dist` branch is force-pushed every time, so it always has exactly one commit of
current output.

The consequence worth internalising: **`main` is never what the loader fetches.**
If you edit `src/` and push, users get the old hub until the publish workflow runs.
That is deliberate — the suite has to pass first.

---

## 3. Creating the repo

1. Create the repo on GitHub, **Public**, no README template (`main` already exists).
2. In the `afterburn/` folder: `git init`, `git add .`, `git commit -m "initial"`.
3. `git remote add origin https://github.com/YOUR_GITHUB_USER/AFTERBURN.git`
4. `git branch -M main` then `git push -u origin main`, then push `Loader.lua` if it
   was missed.
5. Open `Loader.lua` and replace both occurrences of `YOUR_GITHUB_USER` with your
   account. `REPO` must match the repo name exactly. If either is wrong the loader
   fetches a 404 and says so on screen.

Workflow permissions: **Settings → Actions → General → Workflow permissions** must be
*Read and write*, or `publish.yml` cannot push to `dist`.

---

## 4. The one-liner

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_GITHUB_USER/AFTERBURN/main/Loader.lua?v=" .. os.time()))()
```

`main`, not `dist` — the loader is source. The loader itself then fetches
`.../dist/Afterburn.lua` with its own cache buster.

The `?v=` parameter matters. `raw.githubusercontent.com` ignores it, but the CDN keys
on the full URL, so a changing value is what forces a re-fetch instead of a cached
body. Without it a fix can appear not to have landed for minutes at a time.

**Quoting.** If you paste this into a Discord message or a README, keep it inside a
code fence: Discord turns `_` into italics and the URL dies.

---

## 5. Latency and rate limits

Raw GitHub is fast, not instant, and not a CDN you control:

- Cached for roughly **5 minutes**, sometimes longer under load.
- Rate limited **per IP**. Repeated reloads in a session can start returning `429`.
- Serving is best-effort. There is no SLA and no versioning beyond the branch.

The loader's own gate covers the stale case: it reads `dist/VERSION` first and
refuses with *"This loader is stale"* when the published version is ahead of the
loader's `LOADER_VERSION`. So a cached loader copy fails loudly rather than driving a
newer bundle under older rules. Bump `LOADER_VERSION` in `Loader.lua` whenever the
loader's own logic changes, in the same commit that bumps `VERSION`.

---

## 6. Publishing

You never publish by hand.

1. Edit `src/`. Run `lua tests\run_all.lua` and `lua Build.lua` locally.
2. Bump `VERSION`.
3. Commit and push to `main`.
4. `ci.yml` runs. Red → nothing publishes.
5. Green → `publish.yml` starts: it refuses a non-increasing `VERSION`, builds,
   checks the bundle compiles standalone, confirms the header carries the version and
   commit, then force-pushes `Afterburn.lua` and `VERSION` to `dist`.

The header stamp is how a stale copy is *proved* rather than guessed: every bundle
opens with its version, commit and build time, so a user reporting a bug can be
asked which version they have.

---

## 7. Rolling back

`dist` is generated, so rollback is republishing an older tree.

```bat
git revert <bad-commit>          :: the honest path; leaves history readable
git push origin main
```

`VERSION` must still increase for the workflow to publish, so a revert also bumps
`VERSION` (e.g. `1.4.2` → `1.4.3`). If the release is actively breaking people, point
`BRANCH` in `Loader.lua` at `main` temporarily and fetch `dist/Afterburn.lua` from an
earlier tag instead — slower to get right, but it stops the bleeding.

Emergency hotfix: `git push --force origin <good-sha>:dist` with the token, then set
`VERSION` on `main` to match so the next publish isn't refused.

---

## 8. What CI actually protects

`ci.yml` runs `tests/run_all.lua` on `ubuntu-latest` with Lua 5.4 and exit code
enforcement, so any red check stops the pipeline. `publish.yml` triggers on
`workflow_run` with `conclusion == 'success'` — not on `push` — so the gate cannot be
reordered by editing the publish file.

Both workflows also compile-check `dist/Afterburn.lua` standalone and assert the
header stamp. A bundle that would blow up in someone's executor never reaches `dist`.

Note what CI does **not** prove: the suite runs against a Roblox mock, so a green run
says the logic and structure are intact, not that the UI renders or that a real
executor tolerates the code. That stays a Studio F5 and an Android paste.

---

## 9. Checks before every push

```bat
lua tests\run_all.lua
lua Build.lua
```

The second command restores `dist/` locally even though it is ignored, so you can
paste-test the exact bytes CI will judge.
