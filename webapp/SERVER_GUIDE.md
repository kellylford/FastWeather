# Local Web Server Guide

## Why You Need a Server

This web application requires a local web server to run properly. Opening the HTML file directly (`file:///...`) won't work because browsers block JavaScript from loading local JSON files for security reasons (CORS policy).

## Starting the Server

### Option 1: Python (Recommended)

**Python 3:**
```bash
cd C:\Users\kelly\GitHub\FastWeather\webapp\testing
python -m http.server 8000
```

**Python 2:** (if you have older Python)
```bash
cd C:\Users\kelly\GitHub\FastWeather\webapp\testing
python -m SimpleHTTPServer 8000
```

You should see:
```
Serving HTTP on :: port 8000 (http://[::]:8000/) ...
```

### Option 2: Node.js

If you have Node.js installed:
```bash
cd C:\Users\kelly\GitHub\FastWeather\webapp\testing
npx http-server -p 8000
```

### Option 3: PHP

If you have PHP installed:
```bash
cd C:\Users\kelly\GitHub\FastWeather\webapp\testing
php -S localhost:8000
```

### Option 4: VS Code Live Server Extension

1. Install the "Live Server" extension by Ritwick Dey in VS Code
2. Right-click on `index.html` → "Open with Live Server"
3. Automatically refreshes when you save files!

## Accessing the Application

Once the server is running, open your browser and go to:

**http://localhost:8000/index.html**

⚠️ **Important:** Always use `http://localhost:8000` - do NOT open the file directly by double-clicking!

## Stopping the Server

Press **`Ctrl+C`** in the terminal window where the server is running.

The terminal will show:
```
Keyboard interrupt received, exiting.
```

## Tips

- **Keep the terminal open** while testing the application
- The server runs from the current directory, so make sure you `cd` to the testing folder first
- You can use any port number (8000, 8080, 3000, etc.) - just make sure it's not already in use
- If port 8000 is busy, try: `python -m http.server 8080` and use `http://localhost:8080`

## Troubleshooting

**"Address already in use" error:**
- Another program is using port 8000
- Try a different port: `python -m http.server 8080`
- Or stop the other server first

**Can't connect to http://localhost:8000:**
- Make sure the server is still running in the terminal
- Check that you're using `http://` not `https://`
- Try `http://127.0.0.1:8000` instead

**Changes not showing up:**
- Hard refresh the browser: `Ctrl+F5` or `Ctrl+Shift+R`
- Clear browser cache
- Check that you saved the file
