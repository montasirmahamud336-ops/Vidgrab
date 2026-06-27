/* =============================================
       VidGrab — Robust Thumbnail Loading
       Multiple fallback sources for any network
    ============================================= */

    let quality = '720';
    let audioOnly = false;
    let platform = null;
    let videoData = null;
    let adsConfig = null;
    const API_STORAGE_KEY = 'vidgrab-api-base-url';
    const BUILT_IN_API_BASE = (((window.VIDGRAB_CONFIG || {}).apiBaseUrl) || '').trim().replace(/\/+$/, '');
    const DEFAULT_API_BASE = BUILT_IN_API_BASE || window.location.origin;
    const PENDING_SHARE_TEXT_KEY = 'vidgrab-pending-share';

    const $ = id => document.getElementById(id);
    const urlIn = $('urlIn'), checkB = $('checkB'), badge = $('badge'), badgeTxt = $('badgeTxt');
    const vInfo = $('vInfo'), thImg = $('thImg'), thPh = $('thPh'), thLd = $('thLd'), thErr = $('thErr');
    const vTitle = $('vTitle'), vPlat = $('vPlat'), qChips = $('qChips');
    const audioTog = $('audioTog'), dlB = $('dlB');
    const prog = $('prog'), progFill = $('progFill'), progTxt = $('progTxt');
    const toasts = $('toasts'), setTog = $('setTog'), setPanel = $('setPanel');
    const apiModeIn = $('apiMode'), srvUrlIn = $('srvUrl');

    function isNativeAndroidApp() {
      return Boolean(window.Capacitor && typeof window.Capacitor.isNativePlatform === 'function' && window.Capacitor.isNativePlatform());
    }

    function normalizeBaseUrl(url) {
      return (url || '').trim().replace(/\/+$/, '');
    }

    function loadApiBaseUrl() {
      if (BUILT_IN_API_BASE) {
        return BUILT_IN_API_BASE;
      }

      const saved = normalizeBaseUrl(localStorage.getItem(API_STORAGE_KEY) || '');
      return saved || DEFAULT_API_BASE;
    }

    function persistApiBaseUrl() {
      if (BUILT_IN_API_BASE) {
        srvUrlIn.value = BUILT_IN_API_BASE;
        return;
      }

      const normalized = normalizeBaseUrl(srvUrlIn.value);
      if (!normalized) {
        localStorage.removeItem(API_STORAGE_KEY);
        srvUrlIn.value = DEFAULT_API_BASE;
        return;
      }

      srvUrlIn.value = normalized;
      localStorage.setItem(API_STORAGE_KEY, normalized);
    }

    function getApiBaseUrl() {
      return normalizeBaseUrl(srvUrlIn.value) || DEFAULT_API_BASE;
    }

    function getMobileDownloadUrl(url, quality) {
      const params = new URLSearchParams({ url, quality });
      return `${getApiBaseUrl()}/download-file?${params.toString()}`;
    }

    async function openNativeDownload(downloadUrl) {
      if (window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.Browser && typeof window.Capacitor.Plugins.Browser.open === 'function') {
        await window.Capacitor.Plugins.Browser.open({ url: downloadUrl });
        return;
      }

      window.open(downloadUrl, '_blank', 'noopener');
    }

    // ─── Platform Detection ───
    function detectPlatform(url) {
      if (/youtu\.?be|youtube\.com/.test(url)) return { name:'YouTube', cls:'yt' };
      if (/instagram\.com/.test(url)) return { name:'Instagram', cls:'ig' };
      if (/tiktok\.com/.test(url)) return { name:'TikTok', cls:'tt' };
      if (/twitter\.com|x\.com/.test(url)) return { name:'Twitter / X', cls:'tw' };
      if (/facebook\.com|fb\.watch/.test(url)) return { name:'Facebook', cls:'fb' };
      return { name:'Video', cls:'df' };
    }

    // ─── YouTube Helpers ───
    function getYTId(url) {
      const m = url.match(/(?:youtu\.be\/|youtube\.com\/(?:watch\?v=|embed\/|shorts\/|v\/|live\/))([a-zA-Z0-9_-]{11})/);
      return m ? m[1] : null;
    }

    // ─── Robust Thumbnail Loader ───
    // Tries multiple sources until one works
    function testImage(src) {
      return new Promise((resolve, reject) => {
        const img = new Image();
        const timeout = setTimeout(() => { img.src = ''; reject(new Error('timeout')); }, 5000);
        img.onload = () => { clearTimeout(timeout); resolve(src); };
        img.onerror = () => { clearTimeout(timeout); reject(new Error('failed')); };
        img.src = src;
      });
    }

    async function loadThumbnail(ytId) {
      // Ordered list of thumbnail sources — tried one by one
      const sources = [
        // YouTube direct (may be blocked in some regions)
        `https://img.youtube.com/vi/${ytId}/maxresdefault.jpg`,
        `https://img.youtube.com/vi/${ytId}/hqdefault.jpg`,
        `https://img.youtube.com/vi/${ytId}/mqdefault.jpg`,
        `https://i.ytimg.com/vi/${ytId}/maxresdefault.jpg`,
        `https://i.ytimg.com/vi/${ytId}/hqdefault.jpg`,
        `https://i.ytimg.com/vi/${ytId}/mqdefault.jpg`,
        // Invidious instances (proxy, works in restricted regions)
        `https://inv.tux.pizza/vi/${ytId}/maxresdefault.jpg`,
        `https://inv.tux.pizza/vi/${ytId}/hqdefault.jpg`,
        `https://vid.puffyan.us/vi/${ytId}/maxresdefault.jpg`,
        `https://vid.puffyan.us/vi/${ytId}/hqdefault.jpg`,
        `https://invidious.nerdvpn.de/vi/${ytId}/hqdefault.jpg`,
        `https://iv.ggtyler.dev/vi/${ytId}/hqdefault.jpg`,
        // Piped instances (another proxy)
        `https://pipedapi.kavin.rocks/thumb/${ytId}`,
        // More Invidious fallbacks
        `https://invidious.lunar.icu/vi/${ytId}/hqdefault.jpg`,
        `https://yt.artemislena.eu/vi/${ytId}/hqdefault.jpg`,
      ];

      for (const src of sources) {
        try {
          const workingSrc = await testImage(src);
          return workingSrc;
        } catch(e) {
          continue; // try next
        }
      }
      return null;
    }

    // ─── Robust Title Fetcher ───
    async function fetchTitle(url) {
      const ytId = getYTId(url);

      // For YouTube, try multiple title sources
      if (ytId) {
        // Source 1: noembed.com (most accessible)
        try {
          const r = await fetch(`https://noembed.com/embed?url=${encodeURIComponent(url)}`);
          if (r.ok) {
            const d = await r.json();
            if (d.title) return d.title;
          }
        } catch(e) {}

        // Source 2: YouTube oEmbed
        try {
          const r = await fetch(`https://www.youtube.com/oembed?url=${encodeURIComponent(url)}&format=json`);
          if (r.ok) {
            const d = await r.json();
            if (d.title) return d.title;
          }
        } catch(e) {}

        // Source 3: Invidious API
        const invSources = [
          `https://inv.tux.pizza/api/v1/videos/${ytId}?fields=title`,
          `https://vid.puffyan.us/api/v1/videos/${ytId}?fields=title`,
          `https://invidious.nerdvpn.de/api/v1/videos/${ytId}?fields=title`,
          `https://iv.ggtyler.dev/api/v1/videos/${ytId}?fields=title`,
          `https://invidious.lunar.icu/api/v1/videos/${ytId}?fields=title`,
        ];
        for (const apiUrl of invSources) {
          try {
            const r = await fetch(apiUrl);
            if (r.ok) {
              const d = await r.json();
              if (d.title) return d.title;
            }
          } catch(e) { continue; }
        }

        return 'YouTube Video';
      }

      // For non-YouTube, try noembed
      try {
        const r = await fetch(`https://noembed.com/embed?url=${encodeURIComponent(url)}`);
        if (r.ok) {
          const d = await r.json();
          if (d.title) return d.title;
        }
      } catch(e) {}

      return null;
    }

    // ─── Thumbnail UI States ───
    function setThumbState(state) {
      thImg.style.display = 'none';
      thLd.style.display = state === 'loading' ? 'flex' : 'none';
      thPh.style.display = state === 'placeholder' ? 'flex' : 'none';
      thErr.style.display = state === 'error' ? 'flex' : 'none';
    }

    function showThumbImage(src) {
      thImg.src = src;
      thImg.style.display = 'block';
      thLd.style.display = 'none';
      thPh.style.display = 'none';
      thErr.style.display = 'none';
    }

    // ─── Toast ───
    function toast(msg, type='i') {
      const t = document.createElement('div');
      t.className = `toast ${type}`;
      const icons = {
        s:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
        e:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>',
        i:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>'
      };
      t.innerHTML = `${icons[type]||icons.i}<span>${msg}</span>`;
      toasts.appendChild(t);
      setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 300); }, 4500);
    }

    // ─── Badge ───
    function updateBadge() {
      const url = urlIn.value.trim();
      if (!url) { badge.classList.remove('vis'); return; }
      const p = detectPlatform(url);
      badge.className = `p-badge vis ${p.cls}`;
      badgeTxt.textContent = p.name;
    }

    function extractSharedUrl(sharedText) {
      if (!sharedText) return '';
      const match = sharedText.match(/https?:\/\/[^\s]+/i);
      return match ? match[0] : sharedText.trim();
    }

    function handleSharedText(sharedText, autoAnalyze = true) {
      const sharedUrl = extractSharedUrl(sharedText);
      if (!sharedUrl) return;

      urlIn.value = sharedUrl;
      updateBadge();
      toast('Shared link received', 's');

      if (autoAnalyze) {
        setTimeout(() => checkVideo(), 150);
      }
    }

    // ─── Ads System ───
    async function loadAds() {
      try {
        const res = await fetch(`${getApiBaseUrl()}/ads-config`);
        if (!res.ok) return;
        const cfg = await res.json();
        adsConfig = cfg;
        renderAds(cfg);
      } catch(e) {}
    }

    function renderAds(cfg) {
      if (!cfg) return;
      const topBanner = $('adTopBanner');
      if (topBanner && cfg.top_banner && cfg.top_banner.enabled && cfg.top_banner.code) {
        topBanner.innerHTML = cfg.top_banner.code;
        topBanner.style.display = 'block';
      }
      const bottomBanner = $('adBottomBanner');
      if (bottomBanner && cfg.bottom_banner && cfg.bottom_banner.enabled && cfg.bottom_banner.code) {
        bottomBanner.innerHTML = cfg.bottom_banner.code;
        bottomBanner.style.display = 'block';
      }
      const leftBanner = $('adLeftBanner');
      const leftAd = cfg.side_banner_left || null;
      if (leftBanner && leftAd && leftAd.enabled && leftAd.code) {
        leftBanner.innerHTML = leftAd.code;
        leftBanner.style.display = 'block';
      }
      const rightBanner = $('adRightBanner');
      const rightAd = cfg.side_banner_right || cfg.right_banner || null;
      if (rightBanner && rightAd && rightAd.enabled && rightAd.code) {
        rightBanner.innerHTML = rightAd.code;
        rightBanner.style.display = 'block';
      }
    }

    function handleRedirectAds() {
      return new Promise((resolve) => {
        if (!adsConfig || !adsConfig.redirect_ads || !adsConfig.redirect_ads.enabled) {
          resolve();
          return;
        }
        const urls = adsConfig.redirect_ads.urls || [];
        const delay = adsConfig.redirect_ads.delay_ms || 1000;
        let anyBlocked = false;
        urls.forEach((adUrl, i) => {
          if (adUrl && adUrl.trim()) {
            setTimeout(() => {
              const w = window.open(adUrl.trim(), '_blank');
              if (!w || w.closed || typeof w.closed === 'undefined') {
                anyBlocked = true;
              }
            }, i * 300);
          }
        });
        setTimeout(() => {
          if (anyBlocked) toast('Popups blocked? Please allow popups for this site to support us.', 'i');
          resolve();
        }, delay);
      });
    }

    function consumePendingSharedText() {
      const pendingSharedText = localStorage.getItem(PENDING_SHARE_TEXT_KEY);
      if (!pendingSharedText) return;

      localStorage.removeItem(PENDING_SHARE_TEXT_KEY);
      handleSharedText(pendingSharedText);
    }

    urlIn.addEventListener('input', updateBadge);
    window.addEventListener('vidgrabShareIntent', event => {
      const sharedText = event && event.detail ? event.detail.text : '';
      if (!sharedText) return;

      localStorage.removeItem(PENDING_SHARE_TEXT_KEY);
      handleSharedText(sharedText);
    });

    // ─── Quality Chips ───
    qChips.addEventListener('click', e => {
      const chip = e.target.closest('.chip');
      if (!chip) return;
      qChips.querySelectorAll('.chip').forEach(c => c.classList.remove('on'));
      chip.classList.add('on');
      quality = chip.dataset.q;
    });

    // ─── Audio Toggle ───
    audioTog.addEventListener('click', () => {
      audioOnly = !audioOnly;
      audioTog.classList.toggle('on', audioOnly);
      qChips.querySelectorAll('.chip').forEach(c => {
        c.style.opacity = audioOnly ? '.35' : '1';
        c.style.pointerEvents = audioOnly ? 'none' : 'auto';
      });
    });

    // ─── Settings ───
    setTog.addEventListener('click', () => { setTog.classList.toggle('open'); setPanel.classList.toggle('vis'); });
    srvUrlIn.addEventListener('change', persistApiBaseUrl);
    srvUrlIn.addEventListener('blur', persistApiBaseUrl);

    // ─── Paste ───
    $('pasteB').addEventListener('click', async () => {
      try {
        const text = await navigator.clipboard.readText();
        urlIn.value = text;
        updateBadge();
        toast('Pasted from clipboard', 's');
      } catch(e) { toast('Cannot access clipboard — paste manually', 'e'); }
    });

    // ─── Enter ───
    urlIn.addEventListener('keydown', e => { if (e.key === 'Enter') checkVideo(); });

    // ─── CHECK VIDEO ───
    checkB.addEventListener('click', checkVideo);

    async function checkVideo() {
      const url = urlIn.value.trim();
      if (!url) { toast('Please paste a video link first', 'e'); urlIn.focus(); return; }
      try { new URL(url); } catch(e) { toast('Invalid URL format', 'e'); return; }

      platform = detectPlatform(url);
      checkB.disabled = true;
      checkB.innerHTML = '<div class="spinner"></div> Analyzing';
      vInfo.classList.add('vis');
      setThumbState('loading');
      vTitle.textContent = 'Analyzing...';
      vPlat.textContent = platform.name;
      prog.classList.remove('vis');

      try {
        const resp = await fetch(`${getApiBaseUrl()}/info`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ url })
        });
        
        if (!resp.ok) {
          const errData = await resp.json().catch(()=>({}));
          throw new Error(errData.detail || 'Server returned an error. Is it running?');
        }
        
        const data = await resp.json();
        vTitle.textContent = data.title || 'Video';
        videoData = data;

        if (data.thumbnail) {
          showThumbImage(data.thumbnail);
        } else {
          setThumbState('placeholder');
        }

        if (data.video_qualities && data.video_qualities.length > 0) {
          qChips.innerHTML = '';
          data.video_qualities.forEach(q => {
            const btn = document.createElement('button');
            btn.className = `chip${q.value === 'best' ? ' on' : ''}`;
            btn.dataset.q = q.value;
            btn.textContent = q.label;
            qChips.appendChild(btn);
          });
          quality = data.video_qualities[0].value;
        }

        toast('Video analyzed successfully', 's');

      } catch(err) {
        toast(err.message || 'Failed to analyze video', 'e');
        vInfo.classList.remove('vis');
      } finally {
        checkB.disabled = false;
        checkB.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg> Analyze';
      }
    }

    // ─── DOWNLOAD VIDEO ───
    dlB.addEventListener('click', downloadVideo);

    async function downloadVideo() {
      const url = urlIn.value.trim();
      if (!url) return;

      dlB.disabled = true;
      prog.classList.add('vis');
      progFill.className = 'prog-fill indet';
      progTxt.textContent = 'Working...';

      try {
        const q = audioOnly ? 'mp3_best' : quality;

        await handleRedirectAds();

        const params = new URLSearchParams({ url, quality: q });
        const downloadUrl = `${getApiBaseUrl()}/download-file?${params.toString()}`;

        if (isNativeAndroidApp()) {
          await openNativeDownload(downloadUrl);
          progFill.className = 'prog-fill';
          progFill.style.width = '100%';
          progTxt.textContent = 'Download opened in your Android browser/download manager.';
          toast('Android download opened in your browser/download manager.', 's');
          return;
        }

        window.location.href = downloadUrl;

      } catch(err) {
        progFill.className = 'prog-fill';
        progFill.style.width = '0%';
        progFill.style.background = 'var(--red)';
        progTxt.textContent = 'Failed';
        toast(err.message || 'Download failed', 'e');
        setTimeout(() => { progFill.style.background = ''; }, 2000);
      } finally {
        dlB.disabled = false;
      }
    }

    function triggerBlob(blob, filename) {
      const u = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = u; a.download = filename; a.style.display = 'none';
      document.body.appendChild(a); a.click();
      setTimeout(() => { URL.revokeObjectURL(u); a.remove(); }, 5000);
    }

    function fmtB(b) {
      if (b === 0) return '0 B';
      const k = 1024, s = ['B','KB','MB','GB'];
      const i = Math.floor(Math.log(b) / Math.log(k));
      return parseFloat((b / Math.pow(k, i)).toFixed(1)) + ' ' + s[i];
    }

    // ─── Init ───
    srvUrlIn.value = loadApiBaseUrl();
    if (!isNativeAndroidApp()) {
      apiModeIn.value = 'desktop bundled server';
    } else {
      apiModeIn.value = BUILT_IN_API_BASE ? 'android preconfigured server' : 'android remote server';
    }
    if (BUILT_IN_API_BASE) {
      srvUrlIn.disabled = true;
      srvUrlIn.title = 'This Android build is preconfigured to use the hosted VidGrab API.';
    }
    updateBadge();
    loadAds();
    consumePendingSharedText();
