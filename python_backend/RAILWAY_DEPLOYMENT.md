# Deploy to Railway - $5 Free Credit Monthly

Railway gives you **$5 free credit every month** - enough to run your backend 24/7 for personal/hobby projects.

## Setup Steps

### 1. Create Railway Account
1. Go to [railway.app](https://railway.app)
2. Sign up with **GitHub** (easiest) or email
3. Verify your account

⚠️ **Note**: Railway requires a credit card for the free tier, but you get $5 free credit monthly and won't be charged beyond that unless you explicitly upgrade.

### 2. Deploy Your Backend

#### Option A: Deploy from GitHub (Recommended)
1. Click **"New Project"**
2. Select **"Deploy from GitHub repo"**
3. Choose your repository: `Sagarnp1/facerecog`
4. Railway will detect your Dockerfile automatically
5. Click **"Deploy"**

#### Option B: Deploy with Railway CLI
```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Link to new project
railway init

# Deploy
railway up
```

### 3. Configure Environment Variables

1. Go to your project → **Variables** tab
2. Click **"New Variable"**
3. Add the following:

```
PORT=8000
FIREBASE_CREDENTIALS=<your-single-line-json>
```

**To get single-line JSON:**
```bash
# On Windows (PowerShell)
(Get-Content serviceAccountKey.json -Raw) -replace '\r?\n', '' -replace ' ', ''

# Or manually copy from the file and remove all newlines/spaces
```

Your FIREBASE_CREDENTIALS should look like:
```
{"type":"service_account","project_id":"fir-fb641","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",...}
```

### 4. Set Root Directory (Important!)

Your Dockerfile is in the `python_backend` folder, so:

1. Go to **Settings** tab
2. Find **"Root Directory"**
3. Set it to: `python_backend`
4. Click **"Update"**
5. Railway will **redeploy automatically**

### 5. Generate Domain

1. Go to **Settings** tab
2. Scroll to **"Domains"**
3. Click **"Generate Domain"**
4. You'll get a URL like: `https://your-app.up.railway.app`

**Use this URL in your Flutter app!**

### 6. Test Your Deployment

Once deployed, test your endpoints:

```bash
# Health check
curl https://your-app.up.railway.app/

# API docs
https://your-app.up.railway.app/docs
```

## Cost Monitoring

### Free Tier Details
- **$5 credit/month** (resets monthly)
- Approximately **317 hours** of runtime with 512MB RAM
- More than enough for hobby/learning projects

### Check Usage
1. Go to **Project** → **Usage** tab
2. Monitor your credit consumption
3. Set up usage alerts if needed

### Tips to Stay Free
- Turn off service when not actively developing
- Use Railway's **"Sleep on Idle"** feature (project settings)
- Monitor usage regularly

## Troubleshooting

### Build Fails with "Out of Memory"
1. Go to **Settings** → **Service**
2. Increase memory (uses more credits)
3. Or optimize your dependencies

### Environment Variable Not Working
- Make sure `FIREBASE_CREDENTIALS` has NO newlines in the private key
- The entire JSON should be on ONE line
- Check for proper escaping of quotes

### Deployment Keeps Restarting
- Check **Logs** tab for errors
- Verify Firebase credentials are correct
- Ensure all required packages are in `requirements.txt`

### Wrong Directory Deployed
- Double-check Root Directory is set to `python_backend`
- Redeploy after changing root directory

## Update Deployment

Railway automatically redeploys when you push to GitHub:

```bash
# Make changes to your code
git add .
git commit -m "Update backend"
git push

# Railway will auto-deploy!
```

## vs Render Comparison

| Feature | Railway | Render |
|---------|---------|--------|
| Free Tier | $5/month credit | True free (512MB) |
| RAM | 512MB+ | 512MB |
| Credit Card | Required | Not required |
| Auto-deploy | ✅ Yes | ✅ Yes |
| Build Speed | Fast | Medium |

## Need Help?

- Railway Docs: https://docs.railway.app
- Railway Discord: https://discord.gg/railway
- Check deployment logs in Railway dashboard

---

Your Flutter app base URL will be:
```
https://your-app.up.railway.app
```

Update your Flutter app's API endpoint with this URL!
