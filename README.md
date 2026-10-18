# mac-cleaner

A bash script that frees disk space on macOS by deleting caches, logs, and other re-downloadable data.

## Usage

Preview what would be deleted (nothing is removed):

```bash
./mac-clean.sh --dry-run
```

Run the cleanup:

```bash
./mac-clean.sh
```

If the script isn't executable yet:

```bash
chmod +x mac-clean.sh
```

The script asks before it does any of these:

- Quit Claude and clean its caches
- Delete Claude `vm_bundles`
- Thin local Time Machine snapshots by 50GB (needs `sudo`)

## What it does

1. Quits Chrome, Brave, Notion, Slack, Discord, VS Code, and Cursor. Save your work first.
2. Empties the Trash. This is permanent.
3. Deletes `~/Library/Caches`, `~/.cache`, and `~/Library/Logs`.
4. Clears the npm cache and the Cargo registry/git caches.
5. Deletes Xcode DerivedData and unavailable simulators.
6. Removes old JetBrains settings folders (the versions are hardcoded in the script).
7. Clears the cache folders of Chrome, Brave, Notion, Slack, Discord, and optionally Claude. Browser profiles, bookmarks, and logins are kept.
8. Removes Docker installer leftovers.
9. Shows free disk space before and after.

Everything it deletes gets rebuilt or re-downloaded as needed. Expect slower app launches and fresh downloads after a run.

## Requirements

- macOS with bash
- Full Disk Access for your terminal, to empty the Trash (System Settings → Privacy & Security → Full Disk Access)
