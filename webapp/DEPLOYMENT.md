# Deployment Checklist

Quick reference for uploading to fastweather.online

## 📦 Files to Upload

Upload these files from `webapp/` folder to your server:

### Required Files (Always Upload)
- [ ] `.htaccess` ⭐ **CRITICAL - Security & HTTPS**
- [ ] `index.html`
- [ ] `styles.css`
- [ ] `app.js`
- [ ] `service-worker.js`
- [ ] `manifest.json`
- [ ] `robots.txt`
- [ ] `404.html`

### Data Files
- [ ] `us-cities-cached.json`
- [ ] `international-cities-cached.json`

### Images
- [ ] `WeatherIcon-192.png`
- [ ] `WeatherIcon-512.png`

### Documentation (Optional but Recommended)
- [ ] `PRIVACY.md`
- [ ] `SECURITY.md`
- [ ] `user-guide.html` (if you want it accessible online)

### DO NOT Upload
- ❌ `build-city-cache.py` (development only)
- ❌ `build-international-cache.py` (development only)
- ❌ `debug.html` (development only)
- ❌ `table-test.html` (development only)
- ❌ `clear-cache.html` (can upload, but robots.txt blocks it)

## ✅ Post-Deployment Verification

### 1. HTTPS & Security (Most Important!)
```bash
# Test HTTPS redirect
curl -I http://fastweather.online

# Should show:
# HTTP/1.1 301 Moved Permanently
# Location: https://fastweather.online/
```

### 2. Security Headers Check
Visit: https://securityheaders.com/
- Enter: `https://fastweather.online`
- Should get **A** or **A+** rating

### 3. Browser Testing
- [ ] Open https://fastweather.online in browser
- [ ] Click "Use My Current Location" - should prompt for permission
- [ ] Add a city manually - should work
- [ ] Refresh page - cities should persist
- [ ] Test offline (disconnect network) - should still load
- [ ] Check browser console for errors (F12 → Console tab)

### 4. PWA Functionality
Open Chrome DevTools (F12):
- [ ] **Application → Manifest** - Should show FastWeather icon/details
- [ ] **Application → Service Workers** - Should show active service worker
- [ ] **Lighthouse** - Run PWA audit (should score 90+)

### 5. Mobile Testing
- [ ] Open on phone: https://fastweather.online
- [ ] Test "Add to Home Screen" feature
- [ ] Verify responsive layout
- [ ] Test geolocation on mobile

### 6. Performance Testing
Visit: https://pagespeed.web.dev/
- Enter: `https://fastweather.online`
- Should get 90+ on mobile and desktop

## 🔧 Troubleshooting

### "Location access blocked" error
✅ **Fixed!** - .htaccess forces HTTPS now

### Service worker not updating
1. Clear browser cache (Ctrl+Shift+Delete)
2. Hard refresh (Ctrl+Shift+R)
3. Or increment `CACHE_NAME` version in service-worker.js

### Cities not loading
1. Check browser console for errors
2. Verify `us-cities-cached.json` and `international-cities-cached.json` uploaded
3. Check file permissions on server (should be readable)

### 404 errors
1. Verify all files uploaded
2. Check file names are exact (case-sensitive on Linux servers)
3. Check `.htaccess` uploaded and active

## 📊 Monitoring Recommendations

### Set Up (Free Tools)
1. **UptimeRobot** (https://uptimerobot.com)
   - Monitor if site goes down
   - Email/SMS alerts

2. **Google Search Console** (https://search.google.com/search-console)
   - Submit sitemap (when you create one)
   - Monitor search performance

3. **SSL Certificate Monitor**
   - Set calendar reminder for 30 days before expiration
   - Most providers auto-renew, but verify

### Regular Checks (Monthly)
- [ ] Test geolocation still works
- [ ] Check security headers: https://securityheaders.com
- [ ] Verify HTTPS certificate valid
- [ ] Test on new browser/device

## 🚀 Future Enhancements

When you're ready to optimize further:

1. **Create sitemap.xml** for SEO
2. **Add analytics** (privacy-respecting: Plausible or Simple Analytics)
3. **Set up CDN** (Cloudflare free tier)
4. **Submit to HSTS preload** (https://hstspreload.org)
5. **Minify CSS/JS** (reduces file sizes)
6. **Convert images to WebP** (better compression)

---

**Last Deployment:** [Date]  
**Next Review:** [Date + 1 month]
