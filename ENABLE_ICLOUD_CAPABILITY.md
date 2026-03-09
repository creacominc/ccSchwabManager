# How to Enable iCloud Drive Capability in Xcode

## Step-by-Step Instructions

### 1. Open Your Project in Xcode
- Open `ccSchwabManager.xcodeproj` in Xcode

### 2. Select the Project Target
- In the Project Navigator (left sidebar), click on **ccSchwabManager** (the blue project icon at the top)
- In the main editor area, make sure the **ccSchwabManager** target is selected (not the project)

### 3. Go to Signing & Capabilities Tab
- Click on the **"Signing & Capabilities"** tab at the top of the editor
- You should see sections for:
  - Signing
  - App Sandbox (macOS)
  - Other capabilities

### 4. Add iCloud Capability
- Click the **"+ Capability"** button (usually at the top left of the capabilities section)
- In the dialog that appears, search for **"iCloud"**
- Select **"iCloud"** and click **"Add"**

### 5. Configure iCloud Container
After adding iCloud capability, you'll see:
- **iCloud** section with checkboxes
- Check **"iCloud Documents"** (this enables CloudDocuments service)
- Under **"Containers"**, you should see:
  - `iCloud.com.creacom.ccSchwabManager` (this should already be listed if entitlements are correct)
  
If the container doesn't appear automatically:
- Click the **"+"** button next to Containers
- Enter: `iCloud.com.creacom.ccSchwabManager`
- Click **"OK"**

### 6. Verify Entitlements
- The entitlements file (`ccSchwabManager.entitlements`) should already have:
  ```xml
  <key>com.apple.developer.icloud-container-identifiers</key>
  <array>
      <string>iCloud.com.creacom.ccSchwabManager</string>
  </array>
  <key>com.apple.developer.icloud-services</key>
  <array>
      <string>CloudDocuments</string>
  </array>
  ```

### 7. Build and Test
- Build the project (`Cmd+B`)
- If you see any errors about iCloud, Xcode will prompt you to:
  - Sign in with your Apple ID (if not already signed in)
  - Enable iCloud capability in your Apple Developer account (if you have one)

## Important Notes

### For Development/Testing:
- **You can test iCloud Drive even without a paid Apple Developer account**
- The app will use iCloud Drive if:
  1. You're signed into iCloud on your Mac/iPhone
  2. iCloud Drive is enabled in System Settings/Preferences
  3. The capability is enabled in Xcode

### If You Don't Have a Developer Account:
- The app will still work with iCloud Drive for testing
- You may see warnings, but it should function
- For App Store distribution, you'll need a paid developer account

### Troubleshooting:

**If you don't see "+ Capability" button:**
- Make sure you selected the **target** (ccSchwabManager), not the project
- Try clicking on the target name in the left sidebar under "TARGETS"

**If iCloud container doesn't appear:**
- The container identifier must match: `iCloud.com.creacom.ccSchwabManager`
- Make sure there are no typos
- The format is: `iCloud.` + your bundle identifier

**If you see "No iCloud containers available":**
- This is normal if you don't have a developer account
- The app will still work, it just won't sync to iCloud Drive
- It will fall back to local storage automatically

## What Happens After Enabling:

1. **On Build**: Xcode will configure the app with iCloud capability
2. **On First Run**: The app will try to access iCloud Drive
3. **If Available**: Benchmark data will be stored in iCloud Drive
4. **If Not Available**: App automatically falls back to local storage

## Verification:

After enabling and building, check the app logs:
- Look for: `"📊 Using iCloud Drive for performance benchmark storage"`
- Or: `"📊 Using local storage for performance benchmark (iCloud not available)"`

The app will automatically choose the best option available!
