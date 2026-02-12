# 🔌 Connecting Vision Pro to Your Local Server

## Quick Setup Guide

This guide shows you how to connect your Vision Pro to the voice server running on your local computer.

---

## ✅ **Prerequisites**

1. ✅ Python server running on your computer
2. ✅ Vision Pro and computer on **same Wi-Fi network**
3. ✅ Firewall allows incoming connections on port 8001

---

## 📍 **Step 1: Find Your Computer's IP Address**

### **Option A: Using Terminal (Recommended)**

```bash
# Get your local IP address
ipconfig getifaddr en0
```

**Example output:**
```
192.168.1.123
```

### **Option B: Using System Settings**

1. Open **System Settings**
2. Click **Network**
3. Select your active connection (**Wi-Fi** or **Ethernet**)
4. Look for **IP Address**: `192.168.1.XXX`

### **Common IP Address Formats:**
- Local network: `192.168.1.XXX` or `192.168.0.XXX` or `10.0.0.XXX`
- **NOT** `127.0.0.1` (that's localhost only)

---

## 🖥️ **Step 2: Start Your Python Server**

```bash
cd /path/to/your/server
python server.py
```

**You should see:**
```
[startup] Loading Whisper model...
[startup] Loading LLM and embeddings...
[startup] Loading vector store...
[startup] Ready.
INFO:     Uvicorn running on http://0.0.0.0:8001 (Press CTRL+C to quit)
```

**Important:** Server should listen on `0.0.0.0` (all interfaces), not `127.0.0.1`!

---

## 🔧 **Step 3: Update Server Configuration**

### **Open `ServerConfig.swift` and update the IP:**

```swift
struct ServerConfig {
    // Replace with YOUR computer's IP address from Step 1
    static let host: String = "192.168.1.123" // ⬅️ UPDATE THIS!
    
    static let port: Int = 8001
    static let endpoint: String = "/ws/chat"
    
    // ...
}
```

### **Example Configurations:**

#### **Testing on Same Device (iOS Simulator):**
```swift
static let host: String = "127.0.0.1"
```

#### **Vision Pro on Local Network:**
```swift
static let host: String = "192.168.1.123"  // Your computer's IP
```

#### **Custom Port:**
```swift
static let port: Int = 8001  // Must match your server
```

---

## 🏗️ **Step 4: Build and Run**

1. **Open Xcode**
2. **Select target:** Vision Pro (Simulator or Device)
3. **Build:** ⌘B
4. **Run:** ⌘R

---

## 🎯 **Step 5: Test the Connection**

### **In the App:**

1. Tap **"Voice TestingV3"** button (cyan)
2. Tap **"Connect to Server"**
3. Watch status indicator:
   - 🔴 Red "Disconnected" → 🟢 Green "Connected"

### **Expected Console Output:**

```
🔌 Connecting to ws://192.168.1.123:8001/ws/chat...
📨 Server ready:
   Sample rate: 16000 Hz
   Frame: 20 ms (640 bytes)
   Silence cutoff: 700 ms
✅ Recording started
```

### **On Server Side:**

```
INFO:     ('192.168.1.XXX', XXXXX) - "WebSocket /ws/chat" [accepted]
[startup] Ready.
```

---

## 🐛 **Troubleshooting**

### **❌ Connection Failed / Timeout**

#### **Problem 1: Wrong IP Address**

**Symptom:** "Connection failed: timeout"

**Solution:**
1. Double-check IP from Step 1
2. Make sure you're using **local network IP** (192.168.x.x), not 127.0.0.1
3. Update `ServerConfig.host`

#### **Problem 2: Different Wi-Fi Networks**

**Symptom:** Can't connect at all

**Solution:**
1. Open **Settings** on Vision Pro → **Wi-Fi**
2. Open **System Settings** on Mac → **Network**
3. Verify both show **same network name**

#### **Problem 3: Firewall Blocking**

**Symptom:** Connection times out after server starts

**Solution on macOS:**
1. **System Settings** → **Network** → **Firewall**
2. Click **Options...**
3. Add Python to allowed apps, or:
   ```bash
   # Temporarily disable firewall (for testing)
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
   
   # Re-enable after testing
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
   ```

#### **Problem 4: Server Not Listening on All Interfaces**

**Symptom:** Works with `127.0.0.1` but not with local IP

**Solution:** Check your Python server code:
```python
# ❌ BAD - only localhost
uvicorn.run(app, host="127.0.0.1", port=8001)

# ✅ GOOD - all interfaces
uvicorn.run(app, host="0.0.0.0", port=8001)
```

Or start with:
```bash
uvicorn server:app --host 0.0.0.0 --port 8001
```

#### **Problem 5: Wrong Port**

**Symptom:** Connection refused

**Solution:**
1. Check server output: "running on http://0.0.0.0:**8001**"
2. Update `ServerConfig.port` to match

---

## 🔍 **Verification Checklist**

Before testing, verify:

- [ ] Server is running
- [ ] Server shows: `Uvicorn running on http://0.0.0.0:8001`
- [ ] Computer IP address is correct (not 127.0.0.1)
- [ ] `ServerConfig.host` matches computer IP
- [ ] `ServerConfig.port` matches server port (8001)
- [ ] Both devices on same Wi-Fi network
- [ ] Firewall allows port 8001

---

## 📊 **Network Configuration Examples**

### **Example 1: Home Network**
```
Computer IP: 192.168.1.123
Vision Pro IP: 192.168.1.456
Router: 192.168.1.1

ServerConfig.swift:
  static let host: String = "192.168.1.123"
  static let port: Int = 8001
```

### **Example 2: Office Network**
```
Computer IP: 10.0.0.45
Vision Pro IP: 10.0.0.89
Router: 10.0.0.1

ServerConfig.swift:
  static let host: String = "10.0.0.45"
  static let port: Int = 8001
```

### **Example 3: iOS Simulator (Same Device)**
```
Computer IP: 127.0.0.1 (localhost)

ServerConfig.swift:
  static let host: String = "127.0.0.1"
  static let port: Int = 8001
```

---

## 🧪 **Testing Connection from Terminal**

Before testing in the app, verify server is reachable:

```bash
# Test HTTP endpoint (if available)
curl http://192.168.1.123:8001/

# Test WebSocket connection (requires wscat)
npm install -g wscat
wscat -c ws://192.168.1.123:8001/ws/chat
```

---

## 📱 **Multiple Devices Setup**

### **If you want to test from multiple devices:**

1. **iOS Simulator:** Use `127.0.0.1`
2. **iPhone/iPad:** Use computer's local IP
3. **Vision Pro:** Use computer's local IP

### **Dynamic Configuration (Advanced):**

Edit `VoiceInteractionVisionView.swift` to add a settings field:

```swift
@State private var customServerHost = ServerConfig.host
@State private var customServerPort = ServerConfig.port
@State private var showServerConfig = false

// In the UI:
Button("Server Settings") {
    showServerConfig = true
}
.sheet(isPresented: $showServerConfig) {
    Form {
        TextField("Host", text: $customServerHost)
        TextField("Port", value: $customServerPort, format: .number)
        
        Button("Save") {
            // Create client with custom host/port
            showServerConfig = false
        }
    }
}
```

---

## ✅ **Success Indicators**

### **When connected successfully, you'll see:**

1. **In App:**
   - 🟢 Green "Connected" indicator
   - Server config displayed: "16000 Hz • 20ms"
   - "Start Listening" button becomes enabled

2. **In Xcode Console:**
   ```
   🔌 Connecting to ws://192.168.1.123:8001/ws/chat...
   📨 Server ready:
      Sample rate: 16000 Hz
      Frame: 20 ms (640 bytes)
      Silence cutoff: 700 ms
   ✅ Recording started
   ```

3. **In Server Console:**
   ```
   INFO:     ('192.168.1.XXX', XXXXX) - "WebSocket /ws/chat" [accepted]
   [server] client connected
   ```

---

## 🎉 **You're Ready!**

Once connected:
1. Tap **"Start Listening"**
2. Speak naturally
3. See 🟠 Orange "Speaking" indicator
4. Watch transcription appear in blue card
5. See AI response in green card

---

## 💡 **Pro Tips**

### **Tip 1: Use a Static IP**

Configure your computer to use a **static IP** on your router so it doesn't change:
1. Router settings → DHCP → Reserve IP for your computer's MAC address
2. Now you won't need to update `ServerConfig` every time

### **Tip 2: Test with Simple Server First**

Create a minimal test server:
```python
from fastapi import FastAPI, WebSocket

app = FastAPI()

@app.websocket("/ws/chat")
async def test_ws(websocket: WebSocket):
    await websocket.accept()
    await websocket.send_json({"type": "ready", "sample_rate": 16000, "frame_ms": 20, "frame_bytes": 640, "silence_cutoff_ms": 700})
    while True:
        data = await websocket.receive()
        print(f"Received: {len(data)} bytes")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
```

### **Tip 3: Use mDNS (Bonjour)**

Instead of IP addresses, use `.local` hostnames:
```swift
static let host: String = "your-macbook.local"
```

Find your hostname:
```bash
hostname
# Output: your-macbook.local
```

---

## 🆘 **Still Having Issues?**

Check:
1. **Xcode console** for error messages
2. **Server console** for connection logs
3. **Network activity** in Xcode → Debug Navigator → Network
4. **Ping test:** `ping 192.168.1.123` from Vision Pro (if possible)

---

**Happy coding! 🚀**
