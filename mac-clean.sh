#!/usr/bin/env bash

set -u

# under sudo, the mkdir'd ~/Library/Caches and Logs become root-owned and apps can't write to them
if [[ $EUID -eq 0 ]]; then
  echo "Don't run this with sudo; it asks for sudo itself where needed." >&2
  exit 1
fi

DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

echo "mac-cleanup.sh"
echo "Dry run: $DRY_RUN"
echo

run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] $*"
  else
    echo "[run] $*"
    eval "$@"
  fi
}

size_of() {
  local path="$1"
  if [[ -e "$path" ]]; then
    du -sh "$path" 2>/dev/null || true
  fi
}

remove_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    size_of "$path"
    # no eval: paths (e.g. Trash entries) can contain quotes or $
    if [[ "$DRY_RUN" == true ]]; then
      echo "[dry-run] rm -rf $path"
    else
      echo "[run] rm -rf $path"
      rm -rf "$path"
    fi
  fi
}

echo "Before cleanup:"
df -h /
df -h /System/Volumes/Data 2>/dev/null || true
echo

echo "Closing apps that commonly hold cache files..."
# -x: exact process name, so 'Code' doesn't hit every process containing "Code"
run "pkill -x 'Google Chrome' 2>/dev/null || true"
run "pkill -x 'Brave Browser' 2>/dev/null || true"
run "pkill -x 'Notion' 2>/dev/null || true"
run "pkill -x 'Slack' 2>/dev/null || true"
run "pkill -x 'Discord' 2>/dev/null || true"
run "pkill -x 'Code' 2>/dev/null || true"
run "pkill -x 'Cursor' 2>/dev/null || true"
# JetBrains IDEs: their caches and logs get wiped below
for ide in rustrover idea pycharm clion goland webstorm datagrip rider phpstorm rubymine; do
  run "pkill -x '$ide' 2>/dev/null || true"
done

# Claude is opt-in: this script may be running inside Claude's own terminal
read -r -p "Quit Claude and clean its caches? [y/N] " CLEAN_CLAUDE
if [[ "$CLEAN_CLAUDE" =~ ^[Yy]$ ]]; then
  run "pkill -x 'Claude' 2>/dev/null || true"
fi
echo

echo "Cleaning user Trash..."
# delete contents only: ~/.Trash itself has 700 perms + ACL that mkdir can't restore
shopt -s dotglob nullglob
for item in "$HOME/.Trash"/*; do
  remove_path "$item"
done
shopt -u dotglob nullglob
echo

echo "Cleaning general user caches..."
remove_path "$HOME/Library/Caches"
mkdir -p "$HOME/Library/Caches"

remove_path "$HOME/.cache"
mkdir -p "$HOME/.cache"
echo

echo "Cleaning npm cache..."
if command -v npm >/dev/null 2>&1; then
  run "npm cache clean --force"
else
  echo "npm not found, skipping."
fi
echo

echo "Cleaning Cargo registry/git cache..."
remove_path "$HOME/.cargo/registry"
remove_path "$HOME/.cargo/git"
echo

echo "Cleaning Xcode derived data and unavailable simulators..."
remove_path "$HOME/Library/Developer/Xcode/DerivedData"

if command -v xcrun >/dev/null 2>&1; then
  run "xcrun simctl delete unavailable 2>/dev/null || true"
else
  echo "xcrun not found, skipping simulator cleanup."
fi
echo

echo "Cleaning JetBrains old app support folders..."
JETBRAINS="$HOME/Library/Application Support/JetBrains"

remove_path "$JETBRAINS/RustRover2026.1-backup"
remove_path "$JETBRAINS/CLion2025.2"
remove_path "$JETBRAINS/GoLand2025.3"
remove_path "$JETBRAINS/IntelliJIdea2025.2"
remove_path "$JETBRAINS/PyCharm2025.2"
remove_path "$JETBRAINS/PyCharm2025.3"
remove_path "$JETBRAINS/RustRover2025.3"

remove_path "$HOME/Library/Caches/JetBrains"
remove_path "$HOME/Library/Logs/JetBrains"
echo

echo "Cleaning Notion cache..."
NOTION="$HOME/Library/Application Support/Notion"

remove_path "$NOTION/Cache"
remove_path "$NOTION/Code Cache"
remove_path "$NOTION/GPUCache"
remove_path "$NOTION/Service Worker/CacheStorage"
echo

CLAUDE="$HOME/Library/Application Support/Claude"
if [[ "$CLEAN_CLAUDE" =~ ^[Yy]$ ]]; then
  echo "Cleaning Claude cache..."
  remove_path "$CLAUDE/Cache"
  remove_path "$CLAUDE/Code Cache"
  remove_path "$CLAUDE/GPUCache"

  echo
  echo "Claude vm_bundles can be huge."
  echo "It is usually re-downloadable, but it may reset local Claude runtime/tooling data."
  echo "Current size:"
  size_of "$CLAUDE/vm_bundles"

  read -r -p "Delete Claude vm_bundles? [y/N] " DELETE_CLAUDE_VM
  if [[ "$DELETE_CLAUDE_VM" =~ ^[Yy]$ ]]; then
    remove_path "$CLAUDE/vm_bundles"
  else
    echo "Skipping Claude vm_bundles."
  fi
else
  echo "Skipping Claude (still running)."
fi
echo

echo "Cleaning Chrome model/cache data without deleting profiles..."
CHROME="$HOME/Library/Application Support/Google/Chrome"

remove_path "$CHROME/OptGuideOnDeviceModel"
remove_path "$CHROME/optimization_guide_model_store"
remove_path "$CHROME/OptGuideOnDeviceClassifierModel"
remove_path "$CHROME/GrShaderCache"
remove_path "$CHROME/ShaderCache"
remove_path "$CHROME/GraphiteDawnCache"
remove_path "$CHROME/extensions_crx_cache"
remove_path "$CHROME/component_crx_cache"

for profile in "Default" "Profile 1" "Profile 2" "Profile 3" "Profile 4" "Profile 5" "Profile 6"; do
  remove_path "$CHROME/$profile/Cache"
  remove_path "$CHROME/$profile/Code Cache"
  remove_path "$CHROME/$profile/GPUCache"
  remove_path "$CHROME/$profile/Service Worker/CacheStorage"
done
echo

echo "Cleaning Brave model/cache data without deleting profiles..."
BRAVE="$HOME/Library/Application Support/BraveSoftware/Brave-Browser"

remove_path "$BRAVE/OptGuideOnDeviceModel"
remove_path "$BRAVE/optimization_guide_model_store"
remove_path "$BRAVE/OptGuideOnDeviceClassifierModel"
remove_path "$BRAVE/GrShaderCache"
remove_path "$BRAVE/ShaderCache"
remove_path "$BRAVE/GraphiteDawnCache"
remove_path "$BRAVE/extensions_crx_cache"
remove_path "$BRAVE/component_crx_cache"

for profile in "Default" "Profile 1" "Profile 2" "Profile 3" "Profile 4" "Profile 5" "Profile 6"; do
  remove_path "$BRAVE/$profile/Cache"
  remove_path "$BRAVE/$profile/Code Cache"
  remove_path "$BRAVE/$profile/GPUCache"
  remove_path "$BRAVE/$profile/Service Worker/CacheStorage"
done
echo

echo "Cleaning Slack and Discord caches..."
SLACK="$HOME/Library/Application Support/Slack"
DISCORD="$HOME/Library/Application Support/discord"

remove_path "$SLACK/Cache"
remove_path "$SLACK/Code Cache"
remove_path "$SLACK/GPUCache"
remove_path "$SLACK/Service Worker/CacheStorage"

remove_path "$DISCORD/Cache"
remove_path "$DISCORD/Code Cache"
remove_path "$DISCORD/GPUCache"
remove_path "$DISCORD/Service Worker/CacheStorage"
echo

echo "Cleaning Docker installer leftovers..."
remove_path "$HOME/Library/Application Support/com.docker.install"
echo

echo "Cleaning common log folders..."
remove_path "$HOME/Library/Logs"
mkdir -p "$HOME/Library/Logs"
echo

echo "Checking local Time Machine snapshots..."
if command -v tmutil >/dev/null 2>&1; then
  tmutil listlocalsnapshots / || true
  echo
  read -r -p "Ask macOS to thin local snapshots by 50GB? [y/N] " THIN_SNAPSHOTS
  if [[ "$THIN_SNAPSHOTS" =~ ^[Yy]$ ]]; then
    run "sudo tmutil thinlocalsnapshots / 50000000000 4"
  else
    echo "Skipping snapshot thinning."
  fi
else
  echo "tmutil not found, skipping snapshots."
fi
echo

echo "Post-cleanup fixes..."
# an earlier sudo run left these root-owned, which breaks Claude, JetBrains, etc.
for dir in "$HOME/Library/Caches" "$HOME/Library/Logs" "$HOME/.cache"; do
  if [[ -e "$dir" && ! -O "$dir" ]]; then
    run "sudo chown -R '$USER':staff '$dir'"
  fi
done

# stale marker from a failed settings reset blocks every JetBrains IDE launch
shopt -s nullglob
for marker in "$JETBRAINS"/*/migrate.config; do
  remove_path "$marker"
done
shopt -u nullglob
echo

echo "After cleanup:"
df -h /
df -h /System/Volumes/Data 2>/dev/null || true
echo

echo "Current large folders:"
du -sh "$HOME" 2>/dev/null || true
du -sh "$HOME/Library" 2>/dev/null || true
du -sh "$HOME/Library/Application Support" 2>/dev/null || true
du -sh "$HOME/Library/Application Support/JetBrains" 2>/dev/null || true
du -sh "$HOME/Library/Application Support/Claude" 2>/dev/null || true
du -sh "$HOME/Library/Application Support/Google/Chrome" 2>/dev/null || true
du -sh "$HOME/Library/Application Support/Notion" 2>/dev/null || true

echo
echo "Done."