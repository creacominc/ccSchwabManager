# Debugging ccSchwabManager in VS Code/Cursor

This guide explains how to debug your Swift macOS app directly in VS Code or Cursor.

## Prerequisites

1. **Xcode Command Line Tools** - Make sure you have Xcode installed
2. **LLDB** - Should be available with Xcode
3. **Swift Extension** - Install the Swift extension for VS Code/Cursor

## Setup

The project includes VS Code/Cursor configuration files:
- `.vscode/launch.json` - Debug configurations
- `.vscode/tasks.json` - Build and test tasks
- `.vscode/settings.json` - Swift development settings

## How to Debug

### Method 1: Debug with Breakpoints

1. **Set Breakpoints**: Click in the gutter next to line numbers in your Swift files
2. **Start Debugging**: 
   - Press `F5` or
   - Go to Run and Debug panel (Ctrl+Shift+D)
   - Select "Debug ccSchwabManager" from the dropdown
   - Click the green play button

3. **Debug Controls**:
   - `F5` - Continue
   - `F10` - Step Over
   - `F11` - Step Into
   - `Shift+F11` - Step Out
   - `Ctrl+Shift+F5` - Restart
   - `Shift+F5` - Stop

### Method 2: Debug Running App

1. **Launch the app first**: `make launch`
2. **Attach debugger**:
   - Select "Debug ccSchwabManager (Attach)" from debug configurations
   - Press `F5`

### Method 3: Debug with App Bundle

1. **Select "Debug ccSchwabManager (Launch App)"** from debug configurations
2. **Press `F5`** - This launches the full app bundle

## Available Debug Configurations

1. **Debug ccSchwabManager** - Direct executable debugging
2. **Debug ccSchwabManager (Attach)** - Attach to running process
3. **Debug ccSchwabManager (Launch App)** - Launch full app bundle

## Available Tasks

### Build Tasks
- `Ctrl+Shift+P` → "Tasks: Run Task" → "build-app"
- `Ctrl+Shift+P` → "Tasks: Run Task" → "build-debug"
- `Ctrl+Shift+P` → "Tasks: Run Task" → "clean"

### Test Tasks
- `Ctrl+Shift+P` → "Tasks: Run Task" → "run-tests"
- `Ctrl+Shift+P` → "Tasks: Run Task" → "run-ui-tests"
- `Ctrl+Shift+P` → "Tasks: Run Task" → "run-all-tests"

### Launch Tasks
- `Ctrl+Shift+P` → "Tasks: Run Task" → "launch-app"

## Debugging Features

### Breakpoints
- **Line Breakpoints**: Click in the gutter
- **Conditional Breakpoints**: Right-click breakpoint → Edit
- **Log Points**: Right-click breakpoint → Add Log Point

### Variables and Watch
- **Variables Panel**: View local variables and their values
- **Watch Panel**: Add expressions to monitor
- **Call Stack**: See the execution path

### Console
- **Debug Console**: View output and evaluate expressions
- **Integrated Terminal**: See app output in terminal

## Troubleshooting

### Common Issues

1. **"Program not found"**
   - Run `make build` first to build the app
   - Check that the build path is correct

2. **"LLDB not found"**
   - Make sure Xcode is installed
   - Verify LLDB path in settings

3. **"Cannot attach to process"**
   - Make sure the app is running
   - Check that you're using the correct debug configuration

4. **"Symbols not found"**
   - Clean and rebuild: `make clean && make build`
   - Check that you're debugging the Debug build

### Debug Commands

In the Debug Console, you can use LLDB commands:
```lldb
po variableName          # Print object description
p variableName          # Print variable value
bt                      # Show backtrace
frame variable          # Show all variables in current frame
```

## Tips

1. **Always build before debugging**: The debug configuration automatically runs `make build`
2. **Use conditional breakpoints**: For complex debugging scenarios
3. **Watch expressions**: Monitor specific values during execution
4. **Use the call stack**: Understand the execution flow
5. **Check the Debug Console**: For app output and LLDB commands

## Keyboard Shortcuts

- `F5` - Start/Continue debugging
- `F9` - Toggle breakpoint
- `F10` - Step over
- `F11` - Step into
- `Shift+F11` - Step out
- `Ctrl+Shift+F5` - Restart debugging
- `Shift+F5` - Stop debugging

## Integration with Makefile

The debug configurations integrate with your existing Makefile:
- **Pre-launch task**: Automatically runs `make build`
- **Build tasks**: Use your existing build system
- **Test tasks**: Run your test suite from VS Code/Cursor

This setup gives you full debugging capabilities while maintaining your existing build workflow! 