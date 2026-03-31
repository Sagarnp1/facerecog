# Deploy to Hugging Face Spaces - Completely FREE!

Hugging Face Spaces is **perfect for your face recognition app** with:
- ✅ **16GB RAM** (vs 512MB on other platforms)
- ✅ **2 vCPU cores**
- ✅ **Completely FREE** - No credit card required
- ✅ **Always-on** - Doesn't spin down
- ✅ **Built for ML/AI apps** like face recognition

## Setup Steps

### 1. Create Hugging Face Account
1. Go to [huggingface.co](https://huggingface.co)
2. Click **Sign Up** (free, no credit card needed)
3. Verify your email

### 2. Create New Space

1. Click your profile → **New Space**
2. Fill in the details:
   - **Space name**: `ioe-face-recognition` (or any name you want)
   - **License**: Apache 2.0
   - **Select SDK**: Choose **Docker**
   - **Space hardware**: CPU basic (free) - 16GB RAM!
   - **Set to Public** (required for free tier)
3. Click **Create Space**

### 3. Prepare Your Repository

Your code needs a special `README.md` file for Hugging Face. I'll help you create it below.

#### Option A: Push from Your GitHub Repo (Easiest)

1. **Clone your HF Space locally:**
   ```bash
   # Install git-lfs first (if not installed)
   # Windows: Download from https://git-lfs.github.com/

   git lfs install
   git clone https://huggingface.co/spaces/YOUR_USERNAME/ioe-face-recognition
   cd ioe-face-recognition
   ```

2. **Copy your backend files:**
   ```bash
   # Copy everything from python_backend folder
   cp -r /path/to/your/python_backend/* .
   ```

3. **Create the special README.md:**
   Create a file named `README.md` in the root with this content:

   ```markdown
   ---
   title: IOE Face Recognition Backend
   emoji: 👤
   colorFrom: blue
   colorTo: green
   sdk: docker
   pinned: false
   app_port: 8000
   ---

   # IOE Face Recognition Attendance System

   FastAPI backend for face recognition attendance system using InsightFace.

   ## Features
   - Face recognition with InsightFace ArcFace
   - Real-time attendance tracking via WebSocket
   - Firebase Firestore integration
   - Student registration and management

   ## API Documentation
   Visit `/docs` for interactive API documentation.
   ```

4. **Commit and push:**
   ```bash
   git add .
   git commit -m "Add face recognition backend"
   git push
   ```

#### Option B: Upload Files Directly (No Git)

1. In your Space, click **Files** tab
2. Click **Add file** → **Upload files**
3. Upload ALL files from your `python_backend` folder:
   - Dockerfile
   - requirements.txt
   - main.py
   - config.py
   - README.md (the special one from above)
   - .dockerignore
4. Click **Commit changes to main**

### 4. Add Firebase Credentials (Secret)

This is **critical** for your app to work!

1. In your Space, click **Settings** tab
2. Scroll down to **Repository secrets**
3. Click **New secret**
4. Add:
   - **Name**: `FIREBASE_CREDENTIALS`
   - **Value**: Your serviceAccountKey.json as **single-line JSON**

**To get single-line JSON:**

Open your `serviceAccountKey.json` and copy this exact format (all on ONE line):

```json
{"type":"service_account","project_id":"your-project-id","private_key_id":"your-key-id","private_key":"-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----\n","client_email":"firebase-adminsdk-fbsvc@your-project-id.iam.gserviceaccount.com","client_id":"your-client-id"}
```

⚠️ **Important**: The `\n` in the private_key field must stay as `\n` (literal backslash-n), not actual newlines!

5. Click **Save**

### 5. Update Dockerfile for Hugging Face

Your current Dockerfile should work, but make sure the `CMD` line uses the PORT environment variable:

```dockerfile
CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}
```

Hugging Face sets the `PORT` environment variable automatically.

### 6. Deploy!

Once you push your code or upload files:
1. Hugging Face will **automatically build** your Docker image
2. Watch the **Build logs** in the **Logs** tab
3. Build takes 5-10 minutes (compiling face recognition libraries)
4. Once done, your app will be live at:
   ```
   https://huggingface.co/spaces/YOUR_USERNAME/ioe-face-recognition
   ```

### 7. Get Your API URL

Your API will be available at:
```
https://YOUR_USERNAME-ioe-face-recognition.hf.space
```

Or check the **App** tab in your Space for the exact URL.

### 8. Test Your Deployment

```bash
# Health check
curl https://YOUR_USERNAME-ioe-face-recognition.hf.space/

# API documentation
# Visit in browser:
https://YOUR_USERNAME-ioe-face-recognition.hf.space/docs
```

## Update Your Flutter App

Update your Flutter app's base URL:

```dart
// In your API service file
final String baseUrl = 'https://YOUR_USERNAME-ioe-face-recognition.hf.space';
```

## File Structure for HF Spaces

Your HF Space repository should look like this:

```
ioe-face-recognition/
├── README.md          # Special HF metadata file (required!)
├── Dockerfile         # Your Docker configuration
├── requirements.txt   # Python dependencies
├── main.py           # FastAPI application
├── config.py         # Configuration
├── .dockerignore     # Files to exclude from Docker
└── (other backend files)
```

## Troubleshooting

### Build Fails
- Check **Logs** tab for error details
- Most common: Missing files or incorrect Dockerfile
- Make sure README.md has the HF metadata header

### App Shows "Building"
- First build takes 5-10 minutes
- Check **Logs** tab for progress
- If stuck, try restarting the Space (Settings → Restart)

### Firebase Connection Errors
- Verify `FIREBASE_CREDENTIALS` secret is set correctly
- Check that private_key has `\n` (not actual newlines)
- Look at **Logs** tab for Firebase error messages

### Can't Access API
- Make sure Space is set to **Public** (required for free tier)
- Check if Space is running (should show green dot)
- Test the URL in browser first

### "Space is sleeping"
- Free tier Spaces may sleep after inactivity
- They wake up automatically when accessed (takes ~30 seconds)
- First request after sleep may be slow

## Advantages of Hugging Face Spaces

| Feature | HF Spaces | Render | Railway |
|---------|-----------|--------|---------|
| RAM | **16GB** | 512MB | 512MB |
| Credit Card | ❌ No | ❌ No | ✅ Yes |
| Price | **FREE** | FREE | $5 credit/mo |
| ML-optimized | ✅ Yes | No | No |
| Auto-deploy | ✅ Yes | ✅ Yes | ✅ Yes |

## Keeping Space Active

Free Spaces may sleep after inactivity. To keep it active:
1. Your Flutter app's first request will wake it (30s delay)
2. Or upgrade to persistent hardware (paid, but cheaper than other platforms)

## Need Help?

- HF Spaces Docs: https://huggingface.co/docs/hub/spaces
- Community Forum: https://discuss.huggingface.co/
- Check your Space's **Community** tab for discussions

---

**Your app will be live at:**
```
https://YOUR_USERNAME-ioe-face-recognition.hf.space
```

Use this URL in your Flutter app! 🚀

