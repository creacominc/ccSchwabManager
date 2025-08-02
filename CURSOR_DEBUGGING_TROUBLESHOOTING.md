# Cursor Swift Debugging Troubleshooting

If you're seeing "Open a file which can be debugged or run" instead of debug configurations, follow these steps:

## Quick Fix Steps

### 1. Open with Workspace File
```bash
./open-with-cursor.sh
```

### 2. Manual Steps
1. **Close Cursor completely**
2. **Open the workspace file**: `code ccSchwabManager.code-workspace`
3. **Or reload the window**: Cmd+Shift+P → "Developer: Reload Window"

## If Still Not Working

### Check Extensions
1. Open Extensions panel (Cmd+Shift+X)
2. Search for "CodeLLDB"
3. Make sure it's installed and enabled

### Verify Configuration Files
The following files should exist and not be empty:
- `.vscode/launch.json` ✅ (restored)
- `.vscode/settings.json` ✅ (restored)
- `.vscode/tasks.json` ✅ (exists)
- `ccSchwabManager.code-workspace` ✅ (created)

### Force Recognition
1. Open any Swift file (e.g., `ccSchwabManager/ccSchwabManagerApp.swift`)
2. Wait for language server to load
3. Check Run and Debug panel (Cmd+Shift+D)

### Alternative Debug Method
If the UI doesn't work, you can debug via command line:
```bash
# Build the project
xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager build

# Run with LLDB
lldb build/Debug/ccSchwabManager.app/Contents/MacOS/ccSchwabManager
```

## Common Issues

### Issue: "Configured debug type 'swift' is not supported"
**Solution**: ✅ Fixed - Changed to `"type": "lldb"`

### Issue: No debug configurations appear
**Solution**: 
1. Use workspace file: `code ccSchwabManager.code-workspace`
2. Reload window: Cmd+Shift+P → "Developer: Reload Window"

### Issue: Build fails
**Solution**: 
```bash
xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager build
```

### Issue: LLDB extension not found
**Solution**: 
```bash
code --install-extension vadimcn.vscode-lldb
```

## Verification Commands

```bash
# Check if files exist
ls -la .vscode/
ls -la ccSchwabManager.code-workspace

# Check if LLDB extension is installed
code --list-extensions | grep lldb

# Test build
xcodebuild -project ccSchwabManager.xcodeproj -scheme ccSchwabManager build
```

## Next Steps

1. Run `./open-with-cursor.sh`
2. Open Run and Debug panel (Cmd+Shift+D)
3. Select "Debug ccSchwabManager" from dropdown
4. Press F5 or click the green play button 