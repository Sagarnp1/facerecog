# Deploy to Render - Setup Guide

## Files Ready for Deployment ✅

Your backend is now configured for Render deployment with:
- ✅ `Dockerfile` - Optimized for cloud deployment
- ✅ `.dockerignore` - Excludes unnecessary files
- ✅ `render.yaml` - Render service configuration
- ✅ `requirements.txt` - Updated to use `opencv-python-headless`
- ✅ Firebase credentials support via environment variables

## Deployment Steps

### 1. Push to GitHub
```bash
cd python_backend
git add .
git commit -m "Add Render deployment configuration"
git push
```

### 2. Create Render Account
1. Go to [render.com](https://render.com)
2. Sign up with GitHub (free)

### 3. Deploy to Render

#### Option A: Using Blueprint (Recommended)
1. Click **"New +"** → **"Blueprint"**
2. Connect your GitHub repository
3. Select your repository
4. Render will auto-detect `render.yaml`
5. Click **"Apply"**

#### Option B: Manual Web Service
1. Click **"New +"** → **"Web Service"**
2. Connect your GitHub repository
3. Configure:
   - **Name**: `ioe-face-recognition-backend`
   - **Region**: Oregon (or closest to you)
   - **Environment**: Docker
   - **Plan**: Free
   - **Build Command**: (leave empty - Docker handles this)
   - **Start Command**: (leave empty - uses Dockerfile CMD)

### 4. Set Environment Variable (IMPORTANT!)

After creating the service:

1. Go to your service **Dashboard**
2. Click **"Environment"** tab
3. Add environment variable:
   - **Key**: `FIREBASE_CREDENTIALS`
   - **Value**: Paste your entire `serviceAccountKey.json` content as a single line JSON

**To get single-line JSON:**
```bash
# Linux/Mac:
cat serviceAccountKey.json | jq -c

# Windows PowerShell:
Get-Content serviceAccountKey.json | ConvertFrom-Json | ConvertTo-Json -Compress

# Or manually: Copy content and remove all newlines
```

4. Click **"Save Changes"** - this will trigger a redeploy

### 5. Test Your Deployment

Once deployed, your API will be available at:
```
https://ioe-face-recognition-backend.onrender.com
```

Test endpoints:
```bash
# Health check
curl https://ioe-face-recognition-backend.onrender.com/

# API docs
https://ioe-face-recognition-backend.onrender.com/docs
```

## Important Notes for Render Free Tier

⚠️ **Free tier limitations:**
- Service spins down after 15 minutes of inactivity
- First request after spin-down takes ~30-60 seconds (cold start)
- 512 MB RAM limit
- Services are deleted after 90 days of inactivity

⚠️ **Face recognition model memory:**
- InsightFace models can be memory-intensive
- If you get memory errors, consider upgrading to paid tier ($7/month for 512MB → 2GB RAM)

## Troubleshooting

### Build fails due to memory
- Free tier might struggle with building large dependencies
- Solution: Upgrade to paid plan or optimize dependencies

### Firebase connection fails
- Verify `FIREBASE_CREDENTIALS` environment variable is set correctly
- Check the JSON is valid (no extra quotes or escaped characters)
- View logs: Dashboard → Logs tab

### Cold starts are slow
- Normal for free tier
- First request after 15min idle takes 30-60s
- Consider paid tier for always-on service

## Update Flutter App

After deployment, update your Flutter app's API endpoint:

```dart
// lib/services/api_service.dart
static const String baseUrl = 'https://ioe-face-recognition-backend.onrender.com';
```

## Next Steps

1. ✅ Push code to GitHub
2. ✅ Create Render account
3. ✅ Deploy service
4. ✅ Set FIREBASE_CREDENTIALS environment variable
5. ✅ Test endpoints
6. ✅ Update Flutter app URL
7. Monitor logs for any issues

---

**Need help?**
- Render Docs: https://render.com/docs
- Check service logs in Render dashboard
- Test locally first: `docker build -t backend . && docker run -p 8000:8000 backend`
