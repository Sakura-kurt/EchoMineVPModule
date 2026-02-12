# 🎛️ Editable Voice Configuration for visionOS

## ✅ What's New

Your voice interaction now has a **fully editable configuration page** where you can change server settings in real-time!

---

## 🎯 Features

### **Editable Fields:**
- ✅ **Server Host** (IP address) - Text field
- ✅ **Server Port** - Number field
- ✅ **Quick Presets** - One-tap configurations
- ✅ **Validation** - Checks for valid IP and port
- ✅ **Persistent Storage** - Settings saved via UserDefaults
- ✅ **Real-time Preview** - See full WebSocket URL

---

## 📱 How to Use

### **Step 1: Open Voice Interaction**

Tap the **"Voice Interaction"** button (cyan, brain icon) in main menu

### **Step 2: Open Settings**

Tap the **"Settings"** button at the bottom

### **Step 3: Edit Configuration**

```
┌──────────────────────────────────────┐
│  Voice Settings                      │
├──────────────────────────────────────┤
│                                      │
│  Server Configuration                │
│                                      │
│  Host IP Address                     │
│  [172.20.10.3        ]  ← Edit here! │
│                                      │
│  Port                                │
│  [8001               ]  ← Edit here! │
│                                      │
│  Endpoint: /ws/chat                  │
│                                      │
│  [💾 Save & Reconnect]               │
│                                      │
└──────────────────────────────────────┘
```

### **Step 4: Save Changes**

Tap **"Save & Reconnect"** button

- ✅ Validates IP and port
- ✅ Saves to UserDefaults
- ✅ Shows confirmation alert
- ✅ Updates ServerConfig

### **Step 5: Connect**

Close settings and tap **"Connect to Server"** - uses new configuration!

---

## 🚀 Quick Presets

### **One-Tap Configurations:**

```
┌──────────────────────────────────────┐
│  Quick Presets                       │
├──────────────────────────────────────┤
│                                      │
│  [📱 iPhone Hotspot (172.20.10.3)]  │
│  Sets: 172.20.10.3:8001             │
│                                      │
│  [🏠 Local Network (192.168.1.x)]   │
│  Sets: 192.168.1.64:8001            │
│                                      │
│  [💻 Localhost (127.0.0.1)]         │
│  Sets: 127.0.0.1:8001               │
│                                      │
└──────────────────────────────────────┘
```

**Just tap a preset** → **Save** → **Connect!**

---

## 🔧 Technical Details

### **Configuration System**

#### **1. ServerConfig (Persistent)**

```swift
class ServerConfig: ObservableObject {
    @Published static var host: String     // ← Editable!
    @Published static var port: Int        // ← Editable!
    
    static func update(host: String, port: Int) {
        Self.host = host
        Self.port = port
        // Saves to UserDefaults
    }
}
```

#### **2. VoiceSettingsView (UI)**

```swift
struct VoiceSettingsView: View {
    @State private var serverHost: String
    @State private var serverPort: String
    
    // Editable text fields
    TextField("192.168.1.64", text: $serverHost)
    TextField("8001", text: $serverPort)
    
    // Save button
    Button("Save & Reconnect") {
        ServerConfig.update(host: serverHost, port: port)
    }
}
```

#### **3. VoiceInteractionClient (Uses Config)**

```swift
class VoiceInteractionClient {
    init(serverHost: String = ServerConfig.host, 
         serverPort: Int = ServerConfig.port) {
        // Uses current config
    }
    
    func connect() async {
        let urlString = "ws://\(serverHost):\(serverPort)/ws/chat"
        // Connects to configured server
    }
}
```

---

## 📊 Data Flow

```
┌─────────────────────────────────────┐
│  User opens settings                │
└────────────┬────────────────────────┘
             ↓
┌─────────────────────────────────────┐
│  VoiceSettingsView                  │
│  • Shows current config from        │
│    ServerConfig.host & .port        │
│  • User edits fields                │
└────────────┬────────────────────────┘
             ↓
┌─────────────────────────────────────┐
│  User taps "Save & Reconnect"       │
└────────────┬────────────────────────┘
             ↓
┌─────────────────────────────────────┐
│  Validation                         │
│  • Check port: 1-65535              │
│  • Check host: not empty            │
└────────────┬────────────────────────┘
             ↓
┌─────────────────────────────────────┐
│  ServerConfig.update()              │
│  • Updates static properties        │
│  • Saves to UserDefaults            │
└────────────┬────────────────────────┘
             ↓
┌─────────────────────────────────────┐
│  Alert: "✅ Configuration saved!"   │
└────────────┬────────────────────────┘
             ↓
┌─────────────────────────────────────┐
│  User closes settings               │
│  Taps "Connect to Server"           │
└────────────┬────────────────────────┘
             ↓
┌─────────────────────────────────────┐
│  VoiceInteractionClient             │
│  • Reads ServerConfig.host & .port  │
│  • Connects to new address!         │
└─────────────────────────────────────┘
```

---

## 🎯 Example Scenarios

### **Scenario 1: Change from Hotspot to Local Network**

```
1. Current: 172.20.10.3:8001 (iPhone hotspot)
2. Open Settings
3. Tap "🏠 Local Network (192.168.1.x)"
4. Edit host: 192.168.1.100
5. Tap "Save & Reconnect"
6. Alert: "✅ Configuration saved!"
7. Close settings
8. Tap "Connect to Server"
9. Now connects to: ws://192.168.1.100:8001/ws/chat ✅
```

### **Scenario 2: Custom Server**

```
1. Open Settings
2. Manually enter:
   Host: 10.0.0.45
   Port: 9000
3. Tap "Save & Reconnect"
4. Close and connect
5. Connects to: ws://10.0.0.45:9000/ws/chat ✅
```

### **Scenario 3: Quick Switch Between Servers**

```
1. Testing on hotspot:
   Tap "📱 iPhone Hotspot" → Save → Connect ✅

2. Switch to home network:
   Tap "🏠 Local Network" → Edit IP → Save → Connect ✅

3. Test locally:
   Tap "💻 Localhost" → Save → Connect ✅
```

---

## 🔒 Validation Rules

### **Host Validation:**
- ❌ Cannot be empty
- ✅ Accepts IP addresses (e.g., `192.168.1.100`)
- ✅ Accepts hostnames (e.g., `macbook.local`)
- ✅ Trims whitespace automatically

### **Port Validation:**
- ❌ Must be numeric
- ❌ Must be between 1-65535
- ✅ Common ports: 8000, 8001, 8080, 9000

---

## 💾 Persistent Storage

### **Settings are Saved:**
- ✅ Stored in `UserDefaults`
- ✅ Persist across app launches
- ✅ Survive app updates
- ✅ Can be reset by deleting app

### **Default Values (First Launch):**
```swift
Host: "172.20.10.3"  // iPhone hotspot
Port: 8001           // Default server port
```

---

## 🎛️ Settings Page Sections

### **1. Server Configuration**
- Editable host field
- Editable port field
- Endpoint display (read-only)
- Save button

### **2. Current Connection**
- Shows full WebSocket URL
- Updates as you type
- Preview before saving

### **3. Server Settings (from server)**
- Sample rate
- Frame duration
- Frame size
- Silence cutoff
- *(Only shown after connecting)*

### **4. Client Audio**
- Sample rate: 16000 Hz
- Frame duration: 20 ms
- Format: PCM16
- Channels: Mono

### **5. Status**
- Connection status
- Recording status
- Voice activity status

### **6. Features**
- VAD, STT, LLM, RAG info
- Memory gating status
- Language

### **7. Quick Presets**
- iPhone Hotspot
- Local Network
- Localhost

---

## 🐛 Troubleshooting

### **"Cannot change settings while connected"**

**Problem:** Settings are locked when connected

**Solution:**
1. Tap "Disconnect" first
2. Then open settings and edit
3. Save changes
4. Reconnect

### **"Invalid port number"**

**Problem:** Port validation failed

**Solution:**
- Use numbers only
- Range: 1-65535
- Common: 8000, 8001, 8080, 9000

### **Settings not applying**

**Problem:** Changed settings but connects to old server

**Solution:**
1. Make sure you tapped "Save & Reconnect"
2. Check for confirmation alert
3. Close settings
4. Tap "Disconnect" (if connected)
5. Tap "Connect to Server" again

---

## 📱 UI Screenshots (Text Representation)

### **Main View:**
```
┌──────────────────────────────────────┐
│  Voice Interaction                   │
├──────────────────────────────────────┤
│  🔴 Disconnected                     │
│                                      │
│  Your Speech: [...]                  │
│  AI Response: [...]                  │
│                                      │
│  [Connect to Server]                 │
│  [Settings]  ← Click here!           │
└──────────────────────────────────────┘
```

### **Settings View:**
```
┌──────────────────────────────────────┐
│  Voice Settings              [Done]  │
├──────────────────────────────────────┤
│                                      │
│  ▼ Server Configuration              │
│    Host IP Address                   │
│    ┌──────────────────────────────┐ │
│    │ 172.20.10.3                  │ │ ← Type here
│    └──────────────────────────────┘ │
│                                      │
│    Port                              │
│    ┌──────────────────────────────┐ │
│    │ 8001                         │ │ ← Type here
│    └──────────────────────────────┘ │
│                                      │
│    Endpoint: /ws/chat                │
│                                      │
│    ┌──────────────────────────────┐ │
│    │ ✓ Save & Reconnect           │ │ ← Click to save
│    └──────────────────────────────┘ │
│                                      │
│  ▼ Current Connection                │
│    ws://172.20.10.3:8001/ws/chat    │
│                                      │
│  ▼ Quick Presets                     │
│    [📱 iPhone Hotspot]               │
│    [🏠 Local Network]                │
│    [💻 Localhost]                    │
│                                      │
└──────────────────────────────────────┘
```

---

## ✅ Summary

Your voice interaction now has:

1. ✅ **Fully editable configuration** (IP + port)
2. ✅ **Quick presets** for common setups
3. ✅ **Real-time validation** (catches errors)
4. ✅ **Persistent storage** (survives app restarts)
5. ✅ **User-friendly UI** (native visionOS style)
6. ✅ **Preview before saving** (see full URL)
7. ✅ **Safety** (can't edit while connected)

**No more hardcoded IPs!** Change servers anytime! 🎉

---

## 🚀 Quick Start

1. Open app
2. Tap "Voice Interaction"
3. Tap "Settings"
4. Choose a preset OR enter custom server
5. Tap "Save & Reconnect"
6. Close settings
7. Tap "Connect to Server"
8. Start talking! 🎤

**Perfect for visionOS testing!** ✨
