// MangaLens — background.js v4.1
// Multi-provider: Claude + OpenAI GPT-4o mini
// Configurable concurrency (up to 9 parallel captures)

const CLAUDE_MODEL   = 'claude-sonnet-4-20250514';
const CLAUDE_API_URL = 'https://api.anthropic.com/v1/messages';
const OPENAI_MODEL      = 'gpt-4o-mini';
const OPENAI_NANO_MODEL = 'gpt-4.1-nano';
const OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions';
const CACHE_TTL_MS   = 7 * 24 * 60 * 60 * 1000;
const OLLAMA_API_URL = 'http://localhost:11434/api/chat'; // Ollama native API
const CAPTURE_GAP    = 700;

// ── Bubble detector ────────────────────────────────────────────────────────
function detectBubbles(bitmap) {
  const W = bitmap.width, H = bitmap.height;
  if (W < 10 || H < 10) return [];

  const S = 3, sw = Math.max(1,Math.floor(W/S)), sh = Math.max(1,Math.floor(H/S));
  const c = new OffscreenCanvas(sw, sh);
  c.getContext('2d').drawImage(bitmap, 0, 0, sw, sh);
  const { data } = c.getContext('2d').getImageData(0, 0, sw, sh);

  const mask = new Uint8Array(sw * sh);
  for (let i = 0, p = 0; i < data.length; i += 4, p++) {
    const r=data[i],g=data[i+1],b=data[i+2];
    mask[p] = ((r*299+g*587+b*114)/1000 > 205 && Math.max(r,g,b)-Math.min(r,g,b) < 50) ? 1 : 0;
  }

  const par=new Int32Array(sw*sh).fill(-1), sz=new Int32Array(sw*sh);
  const mnX=new Int32Array(sw*sh), mnY=new Int32Array(sw*sh);
  const mxX=new Int32Array(sw*sh), mxY=new Int32Array(sw*sh);

  function find(i){while(par[i]!==i){par[i]=par[par[i]];i=par[i];}return i;}
  function unite(a,b){
    a=find(a);b=find(b);if(a===b)return;
    if(sz[a]<sz[b]){const t=a;a=b;b=t;}
    par[b]=a;sz[a]+=sz[b];
    mnX[a]=Math.min(mnX[a],mnX[b]);mnY[a]=Math.min(mnY[a],mnY[b]);
    mxX[a]=Math.max(mxX[a],mxX[b]);mxY[a]=Math.max(mxY[a],mxY[b]);
  }

  for(let y=0;y<sh;y++) for(let x=0;x<sw;x++){
    const i=y*sw+x; if(!mask[i])continue;
    par[i]=i;sz[i]=1;mnX[i]=mxX[i]=x;mnY[i]=mxY[i]=y;
    if(x>0&&mask[i-1]&&par[i-1]>=0)unite(i,i-1);
    if(y>0&&mask[i-sw]&&par[i-sw]>=0)unite(i,i-sw);
  }

  const pxA=sw*sh, seen=new Set(), raw=[];
  for(let i=0;i<sw*sh;i++){
    if(par[i]<0)continue;const r=find(i);if(seen.has(r))continue;seen.add(r);
    const bw=mxX[r]-mnX[r]+1, bh=mxY[r]-mnY[r]+1, area=bw*bh;
    if(area<pxA*0.003||area>pxA*0.65||bw/bh<0.15||bw/bh>6||sz[r]/area<0.28)continue;
    raw.push({x_pct:((mnX[r]+mxX[r])/2/sw)*100, y_pct:((mnY[r]+mxY[r])/2/sh)*100, w:bw, h:bh});
  }

  const merged=[], used=new Set();
  for(let i=0;i<raw.length;i++){
    if(used.has(i))continue;
    let gx=raw[i].x_pct, gy=raw[i].y_pct, n=1;
    for(let j=i+1;j<raw.length;j++){
      if(used.has(j))continue;
      if(Math.abs(raw[i].x_pct-raw[j].x_pct)<raw[i].w*0.6/sw*100 &&
         Math.abs(raw[i].y_pct-raw[j].y_pct)<raw[i].h*0.6/sh*100){
        gx+=raw[j].x_pct; gy+=raw[j].y_pct; n++; used.add(j);
      }
    }
    used.add(i);
    merged.push({x_pct:gx/n, y_pct:gy/n});
  }
  return merged;
}

function snapPositions(translations, bubbles) {
  if(!bubbles.length) return translations;
  const usedBubbles = new Set();
  return translations.map(t => {
    let best=null, bestDist=Infinity;
    bubbles.forEach((b,i)=>{
      if(usedBubbles.has(i)) return;
      const d=Math.hypot(b.x_pct-(t.x_pct??50), b.y_pct-(t.y_pct??30));
      if(d<bestDist){bestDist=d;best=i;}
    });
    if(best!==null && bestDist<28){
      usedBubbles.add(best);
      return {...t, x_pct:bubbles[best].x_pct, y_pct:bubbles[best].y_pct};
    }
    return t;
  });
}

function deduplicate(results) {
  const seen = new Set();
  const out = [];
  for (const item of results) {
    const key = (item.original || '').trim().toLowerCase();
    if (key && seen.has(key)) continue;
    if (key) seen.add(key);
    out.push(item);
  }
  return out;
}

// ── Screenshot + crop ──────────────────────────────────────────────────────
let lastCapture = 0;

async function screenshotAndCrop(rect, forceJpeg=false) {
  const wait = Math.max(0, CAPTURE_GAP-(Date.now()-lastCapture));
  if(wait>0) await new Promise(r=>setTimeout(r,wait));
  lastCapture = Date.now();

  let dataUrl;
  try { dataUrl = await chrome.tabs.captureVisibleTab(null,{format:'jpeg',quality:96}); }
  catch { dataUrl = await chrome.tabs.captureVisibleTab(null,{format:'png'}); }

  const bitmap = await createImageBitmap(await (await fetch(dataUrl)).blob());
  const x=Math.max(0,rect.x), y=Math.max(0,rect.y);
  const w=Math.max(1,Math.min(rect.width, bitmap.width-x));
  const h=Math.max(1,Math.min(rect.height,bitmap.height-y));

  const canvas = new OffscreenCanvas(w,h);
  canvas.getContext('2d').drawImage(bitmap,x,y,w,h,0,0,w,h);

  let blob, mediaType;
  const formats = forceJpeg
    ? [['image/jpeg','image/jpeg'],['image/png','image/png']]          // Ollama: skip WebP
    : [['image/webp','image/webp'],['image/jpeg','image/jpeg'],['image/png','image/png']]; // Claude/OpenAI: WebP ok
  for(const [type,mime] of formats) {
    try{blob=await canvas.convertToBlob({type,quality:0.95});mediaType=mime;break;}catch{}
  }
  const bytes=new Uint8Array(await blob.arrayBuffer());
  let bin='';
  for(let i=0;i<bytes.length;i+=8192) bin+=String.fromCharCode(...bytes.subarray(i,i+8192));

  const bmp2 = await createImageBitmap(canvas);
  const bubbles = detectBubbles(bmp2);
  console.log(`[MangaLens] Captured ${w}×${h} ${mediaType} — ${bubbles.length} bubble(s)`);

  return { base64:btoa(bin), mediaType, bubbles };
}

// ── Shared prompt ──────────────────────────────────────────────────────────
// Prompt for Claude and OpenAI — detailed, handles complex instructions well
const TRANSLATE_PROMPT = lang => `You are an expert manga and webtoon translator.

This is a manga/webtoon panel screenshot. Find and translate EVERY piece of text.

FIND:
- Every speech bubble (round, oval, jagged/spiky)
- Every thought bubble (cloud-like, dashed)
- Every sound effect / SFX (even single characters like 퍽, 쾅, ドン)
- Every narration box or caption
- Every sign or background text

RULES:
- One JSON entry per bubble — never merge two bubbles into one entry
- Never repeat the same bubble twice
- x_pct = center of bubble, left=0, right=100
- y_pct = center of bubble, top=0, bottom=100
- Translate to ${lang}

Return ONLY valid JSON, nothing else:
[{"original":"...","translation":"...","x_pct":45,"y_pct":28,"type":"speech|thought|sfx|narration|sign"}]

Zero text → []`;

// Simplified prompt for Ollama local models — smaller models follow simpler instructions better
const OLLAMA_TRANSLATE_PROMPT = lang => `Look at this manga/webtoon image. Find all text in speech bubbles, thought bubbles, sound effects, and captions.

For each piece of text you find:
1. Read the original text exactly
2. Translate it to ${lang}
3. Estimate its position (x_pct: 0=left to 100=right, y_pct: 0=top to 100=bottom)

Output ONLY a JSON array, no explanation:
[{"original":"Korean/Japanese text here","translation":"${lang} translation here","x_pct":50,"y_pct":30,"type":"speech"}]

Types: speech, thought, sfx, narration, sign
If no text visible: []`;

function parseJsonResponse(raw) {
  // Strip thinking tokens — some models output <think>...</think> before JSON
  let text = raw.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();

  // Strip markdown fences
  text = text.replace(/^```json\s*/i,'').replace(/^```\s*/i,'').replace(/\s*```$/i,'').trim();

  // Try direct parse first
  try { const p = JSON.parse(text); return Array.isArray(p) ? p : []; }
  catch {}

  // Extract first JSON array from anywhere in the text (handles preamble/postamble)
  const match = text.match(/\[[\s\S]*\]/);
  if (match) {
    try { const p = JSON.parse(match[0]); return Array.isArray(p) ? p : []; }
    catch {}
  }

  console.error('[MangaLens] JSON parse failed. Raw (first 300):', raw.slice(0, 300));
  return [];
}

// ── Claude Vision ──────────────────────────────────────────────────────────
async function callClaude(base64, mediaType, targetLanguage, attempt=0) {
  const { apiKey } = await chrome.storage.local.get('apiKey');
  if (!apiKey) throw new Error('No Claude API key — click the MangaLens icon.');

  const res = await fetch(CLAUDE_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'anthropic-dangerous-direct-browser-access': 'true'
    },
    body: JSON.stringify({
      model: CLAUDE_MODEL,
      max_tokens: 8192,
      messages: [{ role: 'user', content: [
        { type: 'image', source: { type: 'base64', media_type: mediaType, data: base64 } },
        { type: 'text', text: TRANSLATE_PROMPT(targetLanguage) }
      ]}]
    })
  });

  if ((res.status===529||res.status===500) && attempt<2) {
    await new Promise(r=>setTimeout(r,1500*(attempt+1)));
    return callClaude(base64, mediaType, targetLanguage, attempt+1);
  }
  if (!res.ok) {
    const e = await res.json().catch(()=>({}));
    throw new Error(`Claude ${res.status}: ${e.error?.message||res.statusText}`);
  }

  const data = await res.json();
  const raw  = data.content?.find(b=>b.type==='text')?.text || '[]';
  console.log('[MangaLens] Claude raw (first 200):', raw.slice(0,200));
  return parseJsonResponse(raw);
}

// ── OpenAI GPT-4o mini Vision ──────────────────────────────────────────────
async function callOpenAI(base64, mediaType, targetLanguage, attempt=0) {
  const { openaiKey } = await chrome.storage.local.get('openaiKey');
  if (!openaiKey) throw new Error('No OpenAI API key — click the MangaLens icon.');

  const res = await fetch(OPENAI_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${openaiKey}`
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      max_tokens: 4096,
      messages: [{ role: 'user', content: [
        {
          type: 'image_url',
          image_url: { url: `data:${mediaType};base64,${base64}`, detail: 'high' }
        },
        { type: 'text', text: TRANSLATE_PROMPT(targetLanguage) }
      ]}]
    })
  });

  if ((res.status===429||res.status===500) && attempt<2) {
    await new Promise(r=>setTimeout(r,1500*(attempt+1)));
    return callOpenAI(base64, mediaType, targetLanguage, attempt+1);
  }
  if (!res.ok) {
    const e = await res.json().catch(()=>({}));
    throw new Error(`OpenAI ${res.status}: ${e.error?.message||res.statusText}`);
  }

  const data = await res.json();
  const raw  = data.choices?.[0]?.message?.content || '[]';
  console.log('[MangaLens] OpenAI raw (first 200):', raw.slice(0,200));
  return parseJsonResponse(raw);
}

// ── OpenAI GPT-4.1 Nano ───────────────────────────────────────────────────
async function callOpenAINano(base64, mediaType, targetLanguage, attempt=0) {
  const { openaiKey } = await chrome.storage.local.get('openaiKey');
  if (!openaiKey) throw new Error('No OpenAI API key — click the MangaLens icon.');

  const res = await fetch(OPENAI_API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${openaiKey}`
    },
    body: JSON.stringify({
      model: OPENAI_NANO_MODEL,
      max_tokens: 4096,
      messages: [{ role: 'user', content: [
        {
          type: 'image_url',
          image_url: { url: `data:${mediaType};base64,${base64}`, detail: 'high' }
        },
        { type: 'text', text: TRANSLATE_PROMPT(targetLanguage) }
      ]}]
    })
  });

  if ((res.status===429||res.status===500) && attempt<2) {
    await new Promise(r=>setTimeout(r,1500*(attempt+1)));
    return callOpenAINano(base64, mediaType, targetLanguage, attempt+1);
  }
  if (!res.ok) {
    const e = await res.json().catch(()=>({}));
    throw new Error(`OpenAI Nano ${res.status}: ${e.error?.message||res.statusText}`);
  }

  const data = await res.json();
  const raw  = data.choices?.[0]?.message?.content || '[]';
  console.log('[MangaLens] GPT-4.1 Nano raw (first 200):', raw.slice(0,200));
  return parseJsonResponse(raw);
}

// ── Ollama (local, free) ──────────────────────────────────────────────────
async function callOllama(base64, mediaType, targetLanguage, attempt=0) {
  const { ollamaModel } = await chrome.storage.local.get({ ollamaModel: 'minicpm-v:latest' });
  const prompt = OLLAMA_TRANSLATE_PROMPT(targetLanguage);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 120000); // 2 min timeout

  let res;
  try {
    res = await fetch('http://localhost:11434/api/chat', {
      method: 'POST',
      signal: controller.signal,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: ollamaModel,
        stream: false,
        options: { temperature: 0.1, num_predict: 2048 },
        messages: [{
          role: 'user',
          content: prompt,
          images: [base64]   // Ollama native API uses images array with raw base64
        }]
      })
    });
  } catch (err) {
    clearTimeout(timer);
    if (err.name === 'AbortError') throw new Error(`Ollama timed out (120s) — model may be too slow`);
    throw new Error('Ollama not reachable. Run: OLLAMA_ORIGINS="*" ollama serve');
  }
  clearTimeout(timer);

  if (res.status === 403) throw new Error('Ollama CORS blocked. Set OLLAMA_ORIGINS=* and restart Ollama');
  if (res.status === 404) throw new Error(`Model not found. Run: ollama pull ${ollamaModel}`);
  if (res.status === 500 && attempt < 2) {
    await new Promise(r => setTimeout(r, 2000 * (attempt + 1)));
    return callOllama(base64, mediaType, targetLanguage, attempt + 1);
  }
  if (!res.ok) {
    const e = await res.json().catch(() => ({}));
    throw new Error(`Ollama ${res.status}: ${e.error || res.statusText}`);
  }

  const data = await res.json();
  // Native API returns: { message: { content: "..." } }
  const raw = data.message?.content || '';
  console.log('[MangaLens] Ollama raw (first 300):', raw.slice(0, 300));

  if (!raw.trim()) throw new Error('Ollama returned empty — model may not support vision');
  return parseJsonResponse(raw);
}


// ── Provider router ────────────────────────────────────────────────────────
async function callProvider(base64, mediaType, targetLanguage) {
  const { provider } = await chrome.storage.local.get({ provider: 'claude' });
  if (provider === 'openai')  return callOpenAI(base64, mediaType, targetLanguage);
  if (provider === 'nano')    return callOpenAINano(base64, mediaType, targetLanguage);
  if (provider === 'ollama')  return callOllama(base64, mediaType, targetLanguage);
  return callClaude(base64, mediaType, targetLanguage);
}

// ── Cache ──────────────────────────────────────────────────────────────────
function hashUrl(url){let h=0;for(let i=0;i<url.length;i++)h=((h<<5)-h+url.charCodeAt(i))|0;return'cache_'+(h>>>0).toString(16);}
async function getCached(url){
  try{const k=hashUrl(url),{[k]:e}=await chrome.storage.local.get(k);
    if(!e||Date.now()-e.timestamp>CACHE_TTL_MS){if(e)chrome.storage.local.remove(k);return null;}
    return e.translations;}catch{return null;}
}
function setCache(url,t){
  if(!t?.length)return;
  chrome.storage.local.set({[hashUrl(url)]:{translations:t,timestamp:Date.now()}});
}

// ── Serial queue (up to 9 concurrent in settings) ─────────────────────────
const queue=[];
let running=false;

async function runQueue(){
  if(running)return; running=true;
  while(queue.length>0){
    const {msg,sendResponse}=queue.shift();
    const cached=await getCached(msg.imageUrl);
    if(cached){sendResponse({success:true,translations:cached,fromCache:true});continue;}
    try{
      console.log('[MangaLens] Processing:', msg.imageUrl.slice(-40), 'rect:', JSON.stringify(msg.rect));
      const isOllama = (await chrome.storage.local.get({provider:'claude'})).provider === 'ollama';
      const {base64,mediaType,bubbles}=await screenshotAndCrop(msg.rect, isOllama);
      const raw          = await callProvider(base64,mediaType,msg.targetLanguage||'English');
      const deduped      = deduplicate(raw);
      const translations = snapPositions(deduped,bubbles);
      console.log('[MangaLens] Final:', translations.length, 'translation(s)');
      setCache(msg.imageUrl,translations);
      sendResponse({success:true,translations,bubbleCount:bubbles.length,fromCache:false});
    }catch(err){
      console.error('[MangaLens] Error:', err.message);
      sendResponse({success:false,error:err.message});
    }
  }
  running=false;
}

// ── Message router ─────────────────────────────────────────────────────────
chrome.runtime.onMessage.addListener((msg,sender,sendResponse)=>{
  if(msg.action==='translatePanel'){queue.push({msg,sendResponse});runQueue();return true;}
  if(msg.action==='checkKey'){
    chrome.storage.local.get(['apiKey','openaiKey','provider']).then(r=>sendResponse(r));
    return true;
  }
  if(msg.action==='clearCache'){
    chrome.storage.local.get(null).then(all=>{
      const keys=Object.keys(all).filter(k=>k.startsWith('cache_'));
      chrome.storage.local.remove(keys).then(()=>sendResponse({cleared:keys.length}));
    });return true;
  }
});
