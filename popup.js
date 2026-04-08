// MangaLens — popup.js v4.3

const statusEl = document.getElementById('status');
const statsEl  = document.getElementById('stats');
let statusTimer = null;
let currentProvider = 'claude';

function setStatus(msg, type='') {
  statusEl.textContent = msg;
  statusEl.className   = `status ${type}`;
  clearTimeout(statusTimer);
  if (msg) statusTimer = setTimeout(() => { statusEl.textContent=''; statusEl.className='status'; }, 3500);
}

// ── Provider tab switching ─────────────────────────────────────────────────
function switchTab(provider) {
  currentProvider = provider;
  ['claude','openai','nano','ollama'].forEach(p => {
    document.getElementById(`tab-${p}`).classList.toggle('active', p === provider);
    document.getElementById(`section-${p}`).classList.toggle('active', p === provider);
  });
}

document.getElementById('tab-claude').addEventListener('click', () => switchTab('claude'));
document.getElementById('tab-openai').addEventListener('click', () => switchTab('openai'));
document.getElementById('tab-nano').addEventListener('click',   () => switchTab('nano'));
document.getElementById('tab-ollama').addEventListener('click', () => switchTab('ollama'));

// ── Check Ollama connection ────────────────────────────────────────────────
document.getElementById('checkOllama').addEventListener('click', async () => {
  const statusDiv = document.getElementById('ollamaStatus');
  statusDiv.textContent = '⏳ Checking…';
  statusDiv.className   = 'ollama-status';
  try {
    const model = document.getElementById('ollamaModel').value.trim() || 'minicpm-v:latest';
    const res   = await fetch('http://localhost:11434/api/tags');
    if (res.status === 403) {
      statusDiv.innerHTML = '❌ CORS blocked. Run in PowerShell as Admin:<br><code>[System.Environment]::SetEnvironmentVariable("OLLAMA_ORIGINS","*","Machine")</code><br>Then restart Ollama.';
      statusDiv.className = 'ollama-status err'; return;
    }
    if (!res.ok) throw new Error('status ' + res.status);
    const data   = await res.json();
    const models = data.models?.map(m => m.name) || [];
    const found  = models.some(m => m.startsWith(model.split(':')[0]));
    if (found) {
      statusDiv.textContent = `✅ Ollama running · ${model} ready`;
      statusDiv.className   = 'ollama-status ok';
    } else {
      const available = models.slice(0,3).join(', ') || 'none';
      statusDiv.innerHTML = `⚠ Ollama running but <b>${model}</b> not found.<br>Run: <code>ollama pull ${model}</code><br>Available: ${available}`;
      statusDiv.className = 'ollama-status err';
    }
  } catch {
    statusDiv.innerHTML = '❌ Ollama not running.<br>Run: <code>ollama serve</code>';
    statusDiv.className = 'ollama-status err';
  }
});

// ── Load saved settings ────────────────────────────────────────────────────
chrome.storage.local.get(
  { apiKey:'', openaiKey:'', ollamaModel:'minicpm-v:latest', provider:'claude', targetLanguage:'English', autoTranslate:false },
  ({ apiKey, openaiKey, ollamaModel, provider, targetLanguage, autoTranslate }) => {
    if (apiKey)    document.getElementById('claudeKey').value    = apiKey;
    if (openaiKey) {
      document.getElementById('openaiKey').value     = openaiKey;
      document.getElementById('openaiKeyNano').value = openaiKey;
    }
    document.getElementById('ollamaModel').value = ollamaModel || 'minicpm-v:latest';
    document.getElementById('lang').value = targetLanguage;
    switchTab(provider || 'claude');
    setToggle(autoTranslate);
    if (apiKey || openaiKey || provider === 'ollama') setStatus('✓ Settings loaded', 'ok');
  }
);

// Cache stats
chrome.storage.local.get(null, all => {
  const count = Object.keys(all).filter(k => k.startsWith('cache_')).length;
  if (count > 0) statsEl.textContent = `${count} panel(s) cached`;
});

// ── Save ───────────────────────────────────────────────────────────────────
document.getElementById('save').addEventListener('click', async () => {
  const provider    = currentProvider;
  const claudeKey   = document.getElementById('claudeKey').value.trim();
  const openaiKey   = (document.getElementById('openaiKey').value || document.getElementById('openaiKeyNano').value).trim();
  const ollamaModel = document.getElementById('ollamaModel').value.trim() || 'minicpm-v:latest';
  const lang        = document.getElementById('lang').value;

  if (provider === 'claude' && !claudeKey)              { setStatus('Enter your Claude API key', 'err'); return; }
  if ((provider === 'openai' || provider === 'nano') && !openaiKey) { setStatus('Enter your OpenAI API key', 'err'); return; }

  await chrome.storage.local.set({ apiKey: claudeKey, openaiKey, ollamaModel, provider, targetLanguage: lang });

  const labels = { claude: 'Claude Sonnet', openai: 'GPT-4o mini', nano: 'GPT-4.1 Nano', ollama: `Ollama (${ollamaModel})` };
  setStatus(`✓ Saved — using ${labels[provider]}`, 'ok');
});

// ── Auto-translate toggle ──────────────────────────────────────────────────
const autoToggle = document.getElementById('autoToggle');
let autoState = false;
function setToggle(on) { autoState = on; autoToggle.classList.toggle('on', on); }
autoToggle.addEventListener('click', async () => {
  const next = !autoState;
  setToggle(next);
  await chrome.storage.local.set({ autoTranslate: next });
  setStatus(next ? '⚡ Auto-translate ON' : 'Auto-translate off', next ? 'ok' : '');
});

// ── Translate all ──────────────────────────────────────────────────────────
document.getElementById('translateAll').addEventListener('click', async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id) return;
  setStatus('Queuing panels…');
  try {
    const result = await chrome.tabs.sendMessage(tab.id, { action: 'translateAll' });
    setStatus(result.count > 0 ? `⏳ Translating ${result.count} panel(s)…` : 'No panels found', result.count > 0 ? 'ok' : '');
  } catch { setStatus('Extension not active — refresh the page', 'err'); }
});

// ── Clear cache ────────────────────────────────────────────────────────────
document.getElementById('clearCache').addEventListener('click', async () => {
  const r = await chrome.runtime.sendMessage({ action: 'clearCache' });
  setStatus(`Cleared ${r.cleared} cached translation(s)`, 'ok');
  statsEl.textContent = '';
});

// ── Links ──────────────────────────────────────────────────────────────────
document.getElementById('link-claude').addEventListener('click', e => { e.preventDefault(); chrome.tabs.create({ url: 'https://console.anthropic.com/keys' }); });
document.getElementById('link-openai').addEventListener('click', e => { e.preventDefault(); chrome.tabs.create({ url: 'https://platform.openai.com/api-keys' }); });
document.getElementById('link-nano').addEventListener('click',   e => { e.preventDefault(); chrome.tabs.create({ url: 'https://platform.openai.com/api-keys' }); });
document.getElementById('link-ollama').addEventListener('click', e => { e.preventDefault(); chrome.tabs.create({ url: 'https://ollama.com/library/minicpm-v' }); });
document.getElementById('openDocs').addEventListener('click', () => {
  const urls = { claude: 'https://console.anthropic.com/keys', openai: 'https://platform.openai.com/api-keys', nano: 'https://platform.openai.com/api-keys', ollama: 'https://ollama.com' };
  chrome.tabs.create({ url: urls[currentProvider] });
});
