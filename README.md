# MangaLens 🔍

> Translate manga and webtoon panels instantly using AI — directly in your browser.

MangaLens is a Chrome extension that adds a one-click translate button to manga and webtoon panels. It captures the panel, sends it to an AI vision model, and overlays the translated text directly on the page — no copy-pasting, no switching tabs.

---

## Features

- **One-click translation** — hover over any panel and click the purple 🌐 button
- **AI-powered** — uses vision models that understand manga layout, speech bubbles, sound effects, and captions
- **4 provider options** — Claude Sonnet, GPT-4o mini, GPT-4.1 Nano, or local Ollama
- **Overlay rendering** — translated text appears directly on top of the panel in rounded bubbles
- **Auto-translate on scroll** — panels translate automatically as you scroll down
- **Multi-section capture** — handles panels taller than your screen by stitching multiple screenshots
- **7-day cache** — translations are cached locally so you don't repeat API calls
- **Bubble detection** — detects speech bubble positions using canvas image analysis for accurate overlay placement
- **8 target languages** — English, Spanish, French, German, Portuguese, Italian, Simplified Chinese, Traditional Chinese

---

## Supported Sites

| Site | URL |
|------|-----|
| Naver Webtoon | comic.naver.com |
| Webtoons | webtoons.com |
| MangaDex | mangadex.org |
| Viz | viz.com |
| Tapas | tapas.io |
| Kakao Webtoon | webtoon.kakao.com |
| Toonily | toonily.com |
| Bato.to | bato.to |
| Manganato | manganato.com |
| Chapmanganato | chapmanganato.to |
| Reaper Scans | reaperscans.com |
| Flame Scans | flamescans.org |
| Asura Scans | asurascans.com |
| Manga Kakalot | mangakakalot.com |
| MangaHere | mangahere.cc |
| MangaPark | mangapark.net |
| MangaSee | mangasee123.com |
| + more | see manifest.json |

---

## AI Providers

MangaLens supports 4 AI providers. You choose which one to use in the popup.

### Claude (Anthropic) — Recommended
Best translation quality. Understands manga context, slang, and tone naturally.
- Model: `claude-sonnet-4-20250514`
- Requires: Anthropic API key — [console.anthropic.com](https://console.anthropic.com/keys)
- Cost: ~$0.003 per panel

### GPT-4o mini (OpenAI)
Great quality at a much lower cost. Fast and reliable.
- Model: `gpt-4o-mini`
- Requires: OpenAI API key — [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
- Cost: ~$0.0003 per panel

### GPT-4.1 Nano (OpenAI)
Fastest and cheapest OpenAI option. Good for casual reading.
- Model: `gpt-4.1-nano`
- Requires: Same OpenAI API key as GPT-4o mini
- Cost: ~$0.00004 per panel

### Ollama (Local / Free)
Runs entirely on your machine — no API key, no cost, no data sent anywhere.
- Model: `minicpm-v:latest` (recommended)
- Requires: [Ollama](https://ollama.com) installed and running
- Cost: Free

---

## Installation

### From Chrome Web Store
Search for **MangaLens** on the [Chrome Web Store](https://chrome.google.com/webstore) and click Install.

### Manual (Developer Mode)
1. Download and unzip the extension
2. Open Chrome and go to `chrome://extensions`
3. Enable **Developer mode** (top right toggle)
4. Click **Load unpacked** and select the unzipped folder
5. The purple M icon will appear in your toolbar

---

## Setup

### Claude or OpenAI
1. Click the MangaLens icon (purple M) in the Chrome toolbar
2. Select your preferred provider tab (Claude / GPT-4o / 4.1 Nano)
3. Enter your API key and click **Save**

### Ollama (Local AI)
1. Install Ollama from [ollama.com](https://ollama.com)
2. Pull the vision model:
   ```
   ollama pull minicpm-v:latest
   ```
3. Fix CORS so the extension can reach Ollama (run PowerShell as Administrator):
   ```powershell
   [System.Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS", "*", "Machine")
   taskkill /F /IM ollama.exe
   ```
   Then reopen Ollama from the Start menu.
4. In the MangaLens popup, select the **Ollama** tab and click **Check connection**

---

## How to Use

1. Go to any supported manga or webtoon site
2. Open an episode/chapter
3. Hover over a panel — a purple **🌐 Translate** button appears
4. Click it — the translation overlays directly on the panel within a few seconds
5. Click anywhere on the overlay to dismiss it

### Auto-translate
Toggle **⚡ Auto-translate on scroll** in the popup to automatically translate panels as they enter the viewport. Useful for binge-reading.

### Translate All
Click **🌐 Translate all visible panels** in the popup to queue all panels on the current page at once.

### Clear Cache
Click **🗑 Clear cache** in the popup footer to remove all cached translations (useful if you switch providers or languages).

---

## How It Works

```
User clicks Translate
  → content.js captures panel position
  → Scrolls panel into view in 80% viewport slices (for tall panels)
  → background.js takes screenshot via captureVisibleTab
  → Crops screenshot to panel bounds using OffscreenCanvas
  → Detects speech bubble positions using canvas connected-components
  → Sends image to selected AI provider (Claude / OpenAI / Ollama)
  → AI returns JSON: [{original, translation, x_pct, y_pct, type}]
  → content.js renders translation bubbles as absolute-positioned overlays
  → Results cached for 7 days keyed by URL + panel position
```

### Image Formats
- **Claude / OpenAI** — WebP (smallest size, cheaper API cost) → JPEG → PNG fallback
- **Ollama** — JPEG → PNG (WebP skipped as local vision models don't support it)

---

## File Structure

```
mangalens/
├── manifest.json       — MV3 manifest, permissions, site list
├── background.js       — Screenshot capture, AI API calls, cache, bubble detection
├── content.js          — Panel detection, scroll capture, overlay rendering, FAB button
├── overlay.css         — Translation bubble styles
├── popup.html          — Extension popup UI (4 provider tabs)
├── popup.js            — Popup logic, settings save/load, Ollama connection check
└── icons/
    ├── icon-16.png
    ├── icon-48.png
    └── icon-128.png
```

---

## Permissions

| Permission | Why it's needed |
|-----------|----------------|
| `activeTab` | Capture a screenshot of the current tab when the user clicks Translate |
| `storage` | Save API keys and preferences locally on your device |

No other permissions are requested. Your API keys are stored locally and never sent to the developer.

---

## Privacy

MangaLens does not collect any data. The developer receives nothing.

- **API keys** are stored locally on your device using Chrome's storage API
- **Panel screenshots** are sent directly to your chosen AI provider (Anthropic, OpenAI, or local Ollama)
- **No analytics**, no crash reports, no usage tracking

See the full [Privacy Policy](https://deepak-glitch.github.io/Mangalens/privacy-policy.html).

---

## Troubleshooting

**Translate button doesn't appear**
- Make sure you're on a supported site and inside an actual episode/reader page
- Try refreshing the page after installing the extension

**Translation returns empty**
- Check your API key is valid in the popup
- Open DevTools (F12) → Console and look for MangaLens error messages
- Try clearing the cache from the popup

**Ollama not connecting**
- Make sure Ollama is running (you should see it in the system tray)
- Verify CORS is set correctly — run the PowerShell command above and restart Ollama
- Click **Check connection** in the Ollama tab to diagnose

**Ollama CUDA crashes**
- This usually happens after a bad image format is sent. Restart Ollama fully:
  ```powershell
  taskkill /F /IM ollama.exe
  ```
  Then reopen from Start menu and try again.

**Bubbles appear in wrong position**
- This can happen on very tall panels. Try scrolling so the panel is fully visible before translating.

---

## Contributing

Found a bug or want a new site added? Open an issue on GitHub.

When reporting a bug, please include:
- The URL of the page where it happened
- Which AI provider you were using
- The error shown in DevTools Console (F12)

---

## License

MIT License — free to use, modify, and distribute.

---

*Built with ❤️ for the manga community*
