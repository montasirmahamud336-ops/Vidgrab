/* =============================================
       VidGrab — Robust Thumbnail Loading
       Multiple fallback sources for any network
    ============================================= */

    let quality = '720';
    let audioOnly = false;
    let platform = null;
    let videoData = null;
    let adsConfig = null;
    let currentPage = 'home';
    const API_STORAGE_KEY = 'vidgrab-api-base-url';
    const BUILT_IN_API_BASE = (((window.VIDGRAB_CONFIG || {}).apiBaseUrl) || '').trim().replace(/\/+$/, '');
    const DEFAULT_API_BASE = BUILT_IN_API_BASE || window.location.origin;
    const PENDING_SHARE_TEXT_KEY = 'vidgrab-pending-share';

    const $ = id => document.getElementById(id);
    const urlIn = $('urlIn'), checkB = $('checkB'), badge = $('badge'), badgeTxt = $('badgeTxt');
    const vInfo = $('vInfo'), thImg = $('thImg'), thPh = $('thPh'), thLd = $('thLd'), thErr = $('thErr');
    const vTitle = $('vTitle'), vPlat = $('vPlat'), qChips = $('qChips');
    const audioTog = $('audioTog'), dlB = $('dlB');
    const prog = $('prog');
    const toasts = $('toasts');

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

    function getApiBaseUrl() {
      return loadApiBaseUrl();
    }

    const isMobile = /Android|iPhone|iPad|iPod|webOS|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);

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

    function isMobileDevice() {
      return isMobile || isNativeAndroidApp();
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
    const activeToasts = [];

    function toast(msg, type='i', persist=false) {
      const t = document.createElement('div');
      t.className = `toast ${type}`;
      const icons = {
        s:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>',
        e:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>',
        i:'<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>'
      };
      t.innerHTML = `${icons[type]||icons.i}<span>${msg}</span>`;
      toasts.appendChild(t);
      activeToasts.push(t);
      if (!persist) {
        setTimeout(() => { t.classList.add('out'); setTimeout(() => t.remove(), 300); }, 4500);
      }
    }

    function clearToasts() {
      activeToasts.forEach(t => { t.classList.add('out'); setTimeout(() => t.remove(), 300); });
      activeToasts.length = 0;
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

    function renderAdCode(container, code) {
      if (!container || !code) return;
      container.innerHTML = code;
      container.style.display = 'block';
      container.querySelectorAll('script').forEach(oldScript => {
        const newScript = document.createElement('script');
        Array.from(oldScript.attributes).forEach(attr => {
          newScript.setAttribute(attr.name, attr.value);
        });
        newScript.textContent = oldScript.textContent;
        oldScript.parentNode.replaceChild(newScript, oldScript);
      });
    }

    function renderAds(cfg) {
      if (!cfg) return;
      const topBanner = $('adTopBanner');
      if (topBanner && cfg.top_banner && cfg.top_banner.enabled && cfg.top_banner.code) {
        renderAdCode(topBanner, cfg.top_banner.code);
      }
      const bottomBanner = $('adBottomBanner');
      if (bottomBanner && cfg.bottom_banner && cfg.bottom_banner.enabled && cfg.bottom_banner.code) {
        renderAdCode(bottomBanner, cfg.bottom_banner.code);
      }
      const leftBanner = $('adLeftBanner');
      const leftAd = cfg.side_banner_left || null;
      if (leftBanner && leftAd && leftAd.enabled && leftAd.code) {
        renderAdCode(leftBanner, leftAd.code);
      }
      const rightBanner = $('adRightBanner');
      const rightAd = cfg.side_banner_right || null;
      if (rightBanner && rightAd && rightAd.enabled && rightAd.code) {
        renderAdCode(rightBanner, rightAd.code);
      }
    }

    function handleRedirectAds() {
      if (!adsConfig || !adsConfig.redirect_ads || !adsConfig.redirect_ads.enabled) return [];
      const urls = adsConfig.redirect_ads.urls || [];
      const count = adsConfig.redirect_ads.redirects_before_download || 3;
      const shuffled = [...urls].sort(() => Math.random() - 0.5);
      const picked = shuffled.slice(0, Math.min(count, urls.length));
      picked.forEach((adUrl) => {
        if (adUrl && adUrl.trim()) {
          window.open(adUrl.trim(), '_blank');
        }
      });
      return picked;
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

    function isRealPlaylistUrl(url) {
      if (!/youtu\.?be|youtube\.com/.test(url)) return false;
      if (/\/playlist\?/.test(url)) return true;
      const m = url.match(/list=([a-zA-Z0-9_-]+)/);
      if (m) return !/^(RD|LL|WL|LM|SE|OLAK5uy_)/.test(m[1]);
      return false;
    }

    function getUrlTypeInfo(url) {
      const isYTpl = isRealPlaylistUrl(url);
      const p = detectPlatform(url);
      return { isPlaylist: isYTpl, platform: p ? p.name.toLowerCase() : 'other' };
    }

    function validatePageUrl(url) {
      const info = getUrlTypeInfo(url);
      const page = currentPage;

      if (page === 'home') return null;

      if (page === 'playlist') {
        if (!info.isPlaylist) {
          return 'This is a single video link. Use <b>Home</b> or the matching platform tab.';
        }
        if (info.platform !== 'youtube') {
          return 'Only YouTube playlists are supported. Use the <b>Home</b> tab for other platforms.';
        }
        return null;
      }

      if (page === 'youtube') {
        if (info.isPlaylist) {
          return 'This is a playlist link. Switch to the <b>Playlist</b> tab to download.';
        }
        if (info.platform !== 'youtube') {
          return `This looks like a ${info.platform} link. Use the <b>${info.platform.charAt(0).toUpperCase() + info.platform.slice(1)}</b> tab or <b>Home</b>.`;
        }
        return null;
      }

      if (page === info.platform) return null;

      const pageNames = { youtube:'YouTube', facebook:'Facebook', instagram:'Instagram', tiktok:'TikTok', others:'Others' };
      return `This looks like a <b>${info.platform}</b> link. Use the <b>${pageNames[info.platform] || info.platform}</b> tab or <b>Home</b>.`;
    }

    async function checkVideo() {
      const url = urlIn.value.trim();
      if (!url) { toast('Please paste a video link first', 'e'); urlIn.focus(); return; }
      try { new URL(url); } catch(e) { toast('Invalid URL format', 'e'); return; }

      const pageErr = validatePageUrl(url);
      if (pageErr) toast(pageErr, 'w');

      platform = detectPlatform(url);
      checkB.disabled = true;
      checkB.innerHTML = '<div class="spinner"></div> Searching';
      vInfo.classList.add('vis');
      setThumbState('loading');
      vTitle.textContent = 'Searching...';
      vPlat.textContent = platform.name;
      clearToasts();
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
        videoData = data;

        const singleOpts = document.getElementById('singleOpts');
        const plSection = document.getElementById('plSection');
        const dlBtn = document.getElementById('dlB');

        if (data.is_playlist) {
          singleOpts.style.display = 'none';
          plSection.style.display = 'block';
          vTitle.textContent = data.title || 'Playlist';
          vPlat.textContent = platform.name + ' Playlist';
          setThumbState('placeholder');
          document.getElementById('thPh').querySelector('span').textContent = `${data.playlist_count} videos`;
          document.getElementById('plTitle').textContent = data.title || 'Playlist';
          document.getElementById('plMeta').textContent = `${data.playlist_count} videos`;

          const list = document.getElementById('plList');
          list.innerHTML = '';
          data.entries.forEach((entry, i) => {
            const item = document.createElement('div');
            item.className = 'pl-item';
            const dur = entry.duration ? `${Math.floor(entry.duration / 60)}:${String(entry.duration % 60).padStart(2, '0')}` : '';
            item.innerHTML = `
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="5 3 19 12 5 21 5 3"/></svg>
              <span class="pl-idx">${i + 1}</span>
              <span class="pl-ttl">${entry.title}</span>
              <span class="pl-dur">${dur}</span>
            `;
            list.appendChild(item);
          });

          dlBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> Download Playlist (ZIP)';
          quality = 'best';
          toast(`Playlist found: ${data.playlist_count} videos`, 's');
        } else {
          singleOpts.style.display = 'block';
          plSection.style.display = 'none';
          vTitle.textContent = data.title || 'Video';
          dlBtn.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg> Download Now';
          document.getElementById('thPh').querySelector('span').textContent = 'No preview';

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

          toast('Video found successfully', 's');
        }

      } catch(err) {
        toast(err.message || 'Failed to find video', 'e');
        vInfo.classList.remove('vis');
      } finally {
        checkB.disabled = false;
        checkB.innerHTML = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg> Search';
      }
    }

    // ─── Progress Bar Helpers ───
    const STEP_IDS = ['ps1','ps2','ps3','ps4'];
    const LABEL_IDS = ['pl1','pl2','pl3','pl4'];

    function setProgress(step, pct, label) {
      const fill = $('progFill');
      const pctEl = $('progPct');
      const lblEl = $('progLabel');

      if (fill) fill.style.width = Math.min(pct, 100) + '%';
      if (pctEl) pctEl.textContent = Math.min(pct, 100) + '%';
      if (lblEl && label) lblEl.textContent = label;

      for (let i = 0; i < 4; i++) {
        const s = $(STEP_IDS[i]);
        const l = $(LABEL_IDS[i]);
        if (s) {
          s.classList.remove('done', 'active');
          if (i + 1 < step) s.classList.add('done');
          else if (i + 1 === step) s.classList.add('active');
        }
        if (l) {
          l.classList.remove('done', 'active');
          if (i + 1 < step) l.classList.add('done');
          else if (i + 1 === step) l.classList.add('active');
        }
      }
    }

    // ─── DOWNLOAD VIDEO ───
    dlB.addEventListener('click', downloadVideo);

    async function downloadVideo() {
      const url = urlIn.value.trim();
      if (!url) return;

      clearToasts();
      dlB.disabled = true;
      prog.classList.add('vis');
      setProgress(1, 0, 'Connecting...');
      try {
        const q = audioOnly ? 'mp3_best' : quality;

        setProgress(1, 15, 'Checking status...');

        let needsAds = adsConfig?.redirect_ads?.enabled;
        if (needsAds && adsConfig?.redirect_ads?.daily_free_download) {
          try {
            const fr = await fetch(`${getApiBaseUrl()}/api/admin/free-status`);
            if (fr.ok) {
              const fs = await fr.json();
              if (fs.free_available) needsAds = false;
            }
          } catch(e) {}
        }

        setProgress(2, 30, 'Extracting...');

        const delay = (adsConfig?.redirect_ads?.delay_ms || 1000);
        let hasAds = false;
        if (needsAds) {
          const adResults = handleRedirectAds();
          hasAds = adResults.length > 0;
        }

        if (hasAds) {
          await new Promise(r => setTimeout(r, delay));
        }

        setProgress(3, 60, 'Processing...');

        if (videoData?.is_playlist) {
          const plUrl = `${getApiBaseUrl()}/download-playlist?url=${encodeURIComponent(url)}&quality=${encodeURIComponent(q)}`;
          if (isMobileDevice()) {
            window.location.href = plUrl;
          } else {
            const a = document.createElement('a');
            a.href = plUrl;
            a.style.display = 'none';
            document.body.appendChild(a);
            a.click();
            a.remove();
          }
          setProgress(4, 100, 'Download started');
          setTimeout(() => prog.classList.remove('vis'), 1500);
          toast('Playlist download started.', 's');
          dlB.disabled = false;
          return;
        }

        const params = new URLSearchParams({ url, quality: q });
        if (videoData?.title) params.set('title', videoData.title);
        const downloadUrl = `${getApiBaseUrl()}/download-file?${params.toString()}`;

        if (isMobileDevice()) {
          window.location.href = downloadUrl;
          setProgress(4, 100, 'Download started');
          setTimeout(() => prog.classList.remove('vis'), 1500);
          toast('Download started.', 's');
          return;
        }

        setProgress(3, 80, 'Preparing file...');

        toast('Please wait — server is preparing your download. Don\'t leave the page.', 'i', true);

        const resp = await fetch(downloadUrl);
        if (!resp.ok) {
          const errData = await resp.json().catch(()=>({}));
          throw new Error(errData.detail || 'Server refused download');
        }

        // Server responded — download is starting
        clearToasts();
        setProgress(4, 100, 'Download complete');

        const blob = await resp.blob();
        const disp = resp.headers.get('Content-Disposition') || '';
        const fnMatch = disp.match(/filename\*?=(?:UTF-8'')?([^;\s]+)/i);
        const filename = fnMatch ? decodeURIComponent(fnMatch[1]) : 'video.mp4';
        triggerBlob(blob, filename);

        setTimeout(() => prog.classList.remove('vis'), 1500);

      } catch(err) {
        clearToasts();
        prog.classList.remove('vis');
        toast(err.message || 'Download failed', 'e');
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

    // ─── Multi-page Routing ───
    const PAGES = {
      home:    { title: 'VidGrab Video Downloader',   desc: 'Paste a link, preview the video, and download directly in your browser.',                    bg: '#06080f', acc: '#38bdf8', orb1: 'rgba(56,189,248,.3)', orb2: 'rgba(139,92,246,.22)', plat: null },
      youtube: { title: 'YouTube Video Downloader',   desc: 'Download any YouTube video in HD quality. Paste the link and start downloading.',            bg: '#0f0808', acc: '#ff4444', orb1: 'rgba(255,0,0,.25)', orb2: 'rgba(255,0,0,.15)', plat: 'platYoutube' },
      facebook:{ title: 'Facebook Video Downloader',  desc: 'Download Facebook videos in high quality. Paste a Facebook video link to get started.',     bg: '#081018', acc: '#1877f2', orb1: 'rgba(24,119,242,.25)', orb2: 'rgba(24,119,242,.15)', plat: 'platFacebook' },
      instagram:{title: 'Instagram Video Downloader', desc: 'Download Instagram videos, reels & stories. Paste the link and download instantly.',          bg: '#0f0808', acc: '#e1306c', orb1: 'rgba(225,48,108,.25)', orb2: 'rgba(188,42,141,.18)', plat: 'platInstagram' },
      tiktok:  { title: 'TikTok Video Downloader',    desc: 'Download TikTok videos without watermark. Paste a TikTok link and download free.',           bg: '#050505', acc: '#00f2ea', orb1: 'rgba(0,242,234,.2)', orb2: 'rgba(255,0,80,.2)', plat: 'platTiktok' },
      others:  { title: 'Universal Video Downloader', desc: 'Download videos from any website. Paste the video link and start downloading.',              bg: '#06080f', acc: '#38bdf8', orb1: 'rgba(56,189,248,.3)', orb2: 'rgba(139,92,246,.22)', plat: null },
      playlist:{ title: 'Playlist Downloader',      desc: 'Download entire YouTube playlists as a ZIP. Paste any playlist link and start.', bg: '#0f0a14', acc: '#a855f7', orb1: 'rgba(168,85,247,.25)', orb2: 'rgba(139,92,246,.18)', plat: null },
    };

    function navigateTo(page) {
      currentPage = page === 'home' ? 'home' : page;
      document.querySelectorAll('.nav a').forEach(a => a.classList.toggle('on', a.dataset.page === page));
      const info = PAGES[page] || PAGES.home;
      document.title = info.title + ' — VidGrab';
      $('heroTitle').textContent = info.title;
      $('heroDesc').textContent = info.desc;

      document.documentElement.style.setProperty('--bg', info.bg);
      document.documentElement.style.setProperty('--acc', info.acc);
      document.querySelector('.orb-1').style.background = `radial-gradient(circle,${info.orb1},transparent 70%)`;
      document.querySelector('.orb-2').style.background = `radial-gradient(circle,${info.orb2},transparent 70%)`;

      document.querySelectorAll('.plat-ic').forEach(el => el.classList.remove('on'));
      if (info.plat) $(info.plat).classList.add('on');
    }

    function handleHash() {
      const page = location.hash.replace('#', '') || 'home';
      currentPage = PAGES[page] ? page : 'home';
      navigateTo(currentPage);
    }

    window.addEventListener('hashchange', handleHash);

    const nav = document.querySelector('.nav');
    const hamB = document.getElementById('hamB');

    function closeNav() { nav.classList.remove('mobile-open'); }
    function toggleNav() { nav.classList.toggle('mobile-open'); }

    if (hamB) hamB.addEventListener('click', toggleNav);

    nav.addEventListener('click', e => {
      const link = e.target.closest('a[data-page]');
      if (link) {
        e.preventDefault();
        closeNav();
        const page = link.dataset.page;
        if (page === 'home') {
          history.replaceState(null, '', window.location.pathname);
        } else {
          location.hash = page;
        }
        navigateTo(page);
      }
    });

    // ─── PWA Install Prompt ───
    let deferredPrompt = null;
    const PWA_KEY = 'vidgrab-pwa-dismissed';
    const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;

    function showInstallBanner(text, btnHtml) {
      if (localStorage.getItem(PWA_KEY)) return;
      const existing = document.getElementById('pwaBanner');
      if (existing) existing.remove();

      const banner = document.createElement('div');
      banner.id = 'pwaBanner';
      banner.style.cssText =
        'position:fixed;bottom:0;left:0;right:0;z-index:9999;background:#0f172a;border-top:1px solid #334155;padding:12px 16px;display:flex;align-items:center;gap:12px;font-family:Inter,sans-serif;';

      banner.innerHTML = `
        <div style="flex:1;color:#e2e8f0;font-size:14px;line-height:1.4">
          <div style="font-weight:600;font-size:15px">Install VidGrab</div>
          <div style="color:#94a3b8;font-size:13px">${text}</div>
        </div>
        ${btnHtml}
        <button id="pwaDismissBtn" style="background:transparent;color:#64748b;border:none;font-size:22px;cursor:pointer;line-height:1">&times;</button>
      `;

      document.body.appendChild(banner);
      document.getElementById('pwaDismissBtn').onclick = () => {
        localStorage.setItem(PWA_KEY, '1');
        banner.remove();
      };
    }

    if (!window.matchMedia('(display-mode: standalone)').matches) {
      localStorage.removeItem(PWA_KEY);
    }

    if (isIOS) {
      setTimeout(() => {
        showInstallBanner(
          'Tap Share <span style="display:inline-block;vertical-align:middle;font-size:18px">⎋</span> then "Add to Home Screen"',
          '<button id="pwaIosOk" style="background:#38bdf8;color:#0f172a;border:none;border-radius:8px;padding:8px 20px;font-weight:600;font-size:14px;cursor:pointer">Got it</button>'
        );
        const ok = document.getElementById('pwaIosOk');
        if (ok) ok.onclick = () => { localStorage.setItem(PWA_KEY, '1'); document.getElementById('pwaBanner').remove(); };
      }, 3000);
    } else {
      window.addEventListener('beforeinstallprompt', (e) => {
        e.preventDefault();
        deferredPrompt = e;
        setTimeout(() => {
          if (!deferredPrompt) return;
          showInstallBanner(
            'Add to your Home Screen for a faster experience',
            '<button id="pwaInstallBtn" style="background:#38bdf8;color:#0f172a;border:none;border-radius:8px;padding:8px 20px;font-weight:600;font-size:14px;cursor:pointer">Install</button>'
          );
          const btn = document.getElementById('pwaInstallBtn');
          if (btn) btn.onclick = () => {
            deferredPrompt.prompt();
            deferredPrompt.userChoice.then((result) => {
              deferredPrompt = null;
              const b = document.getElementById('pwaBanner');
              if (b) b.remove();
              if (result.outcome === 'dismissed') {
                localStorage.setItem(PWA_KEY, '1');
              }
            });
          };
        }, 2000);
      });
    }

    window.addEventListener('appinstalled', () => {
      deferredPrompt = null;
      localStorage.removeItem(PWA_KEY);
      const b = document.getElementById('pwaBanner');
      if (b) b.remove();
    });

    // ─── Init ───
    updateBadge();
    loadAds();
    consumePendingSharedText();
    handleHash();
