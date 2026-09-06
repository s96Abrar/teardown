# 🔥 Teardown — Reclaim Your Mac's Disk Space

Two dead-simple, interactive bash tools that hunt down the gigabytes macOS silently hides away.

| Tool | What it does |
|------|--------------|
| **`app-cleanup.sh`** 🗑️ | Fully uninstalls apps — bundle, caches, configs, sandbox containers, receipts & privacy permissions |
| **`dev-cleanup.sh`** 🧪 | Cleans your developer toolchain — Homebrew, Node, Python, Rust, Android, Gradle, Xcode & Simulators |

No dependencies. No install. Just plain bash on a stock macOS.

---

## 🗑️ `app-cleanup.sh` — The App Uninstaller

Dragging an app to the Trash doesn't remove it. **Teardown does.** It finds and wipes every trace — caches, preferences, containers, launch agents, install receipts, even the app's privacy permissions.

```bash
chmod +x app-cleanup.sh && ./app-cleanup.sh
```

### ⚡ 3 steps

1. **Point at the app** — pick one from `/Applications` (or type a bundle ID; works for apps you've *already* removed 🕵️).
2. **Preview** — a dry run shows every matching file & folder with sizes. Nothing touched yet.
3. **Choose your tier**:

| Tier | Removes |
|------|---------|
| ✅ **Normal** | The app bundle only |
| ⚙️ **Advanced** | Bundle + caches, prefs, containers, launch agents, group containers |
| ☢️ **Complete** | Advanced + install receipts & TCC privacy grants (double-warned ⚠️⚠️) |

### 🛡️ Built-in safety

- **Dry run first** — you always see the full footprint before anything is deleted.
- **Least-privilege** — removes as *you* first, only escalates to `sudo` when it must.
- **Surprise-proof** — detects running apps and quits them gracefully first; never touches a `(null)` bundle ID or deletes a shared parent folder.
- **Accountable** — every removal is logged to `./Logs/appcleaner.log` (user vs sudo, timestamped).

### 🔍 Where it looks

| Area | Paths |
|------|-------|
| App bundle | the selected `.app` |
| By display name | `~/Library/{Application Support, Caches, Logs}/AppName`, `/Library/Application Support/AppName` |
| By bundle ID | `Caches/<bid>`, `Preferences/<bid>.plist`, `Saved Application State/<bid>.savedState`, `Containers/<bid>`, `HTTPStorages/<bid>`, `WebKit/<bid>`, `LaunchAgents/<bid>.plist` (+`/Library/...`), `LaunchDaemons/<bid>.plist` |
| Group Containers | `~/Library/Group Containers/*<bid>` — suffix-matched, confirmed separately |
| Receipts & TCC | `pkgutil --forget` and `tccutil reset All <bid>` (Complete only) |

> 💡 **Tip:** reading privacy (TCC) entries needs **Full Disk Access** on your terminal (System Settings → Privacy & Security). Empty result ≠ no permissions.

> 🧪 **First run?** Test on a low-value app before hitting Complete.

---

## 🧪 `dev-cleanup.sh` — The Dev Tools Cache Manager

Your toolchain hides gigabytes in `~/Library` and dot-folders. **Teardown surfaces every byte and lets you clean it, guided.**

```bash
chmod +x dev-cleanup.sh && ./dev-cleanup.sh
```

### 🎛️ What's inside

| Key | Menu | Actions |
|-----|------|---------|
| **1** 🍺 | Homebrew | `cleanup --prune=all`, `autoremove`, `upgrade` |
| **2** 📦 | Node / NPM | clear npm / yarn / pnpm caches, list globals |
| **3** 🐍 | pip3 | `pip3 cache purge`, list packages |
| **4** 🦀 | Rustup / Cargo | uninstall toolchains, clean registry + git caches |
| **5** 🤖 | Android SDK | remove build-tools, clean `~/.android/cache` |
| **6** 🐘 | Gradle | clean `caches` / `daemon` / `wrapper` |
| **7** 🔨 | Xcode | DerivedData, DeviceSupport, caches, Archives ⚠️ |
| **8** 📱 | iOS Simulator | remove unavailable sims, caches, erase all ⚠️ |
| **s** 📊 | **Summary** | version table + full disk-usage breakdown |
| **c** 🧹 | **Clean All** | one-shot sweep, `✓ done / skipped` per step |
| **q** 🚪 | Quit | |

Every menu shows **live disk usage**, loops until you press `b`, and auto-refreshes sizes after a cleanup so you can see space freed. Always confirms before deleting — messy extras like **Archives** (`.ipa` + `.dSYM`) and **Erase All** get an extra ⚠️ warning. `Clean All` never touches Archives, AVDs, or Simulator app data.

Zen paths it can modify: `~/.rustup`, `~/.cargo/{registry/cache,git}`, `~/.gradle/{caches,daemon,wrapper}`, `~/Library/Developer/Xcode/{DerivedData,Archives,iOS DeviceSupport}`, `~/Library/Caches/{com.apple.dt.Xcode,org.swift.swiftpm}`, `~/Library/Developer/CoreSimulator/Caches`, brew cache, npm/pip caches, and `${ANDROID_HOME:-~/Library/Android/sdk}`.

---

## 🧰 Requirements

- **macOS** with a terminal (uses `mdls`, `mdfind`, `pkgutil`, `launchctl`, `tccutil`, `osascript`, `xcrun`, …)
- Grant **Full Disk Access** to your terminal for full TCC visibility
- `chmod +x` the scripts

## 🧪 Verification

No test suite — syntax-check after edits:

```bash
bash -n app-cleanup.sh dev-cleanup.sh
```

Both scripts are interactive and loop, so real testing needs a live macOS session. **Try destructive flows on a throwaway app/tool first.**