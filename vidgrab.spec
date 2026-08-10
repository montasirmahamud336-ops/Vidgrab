# -*- mode: python ; coding: utf-8 -*-
"""
VidGrab PyInstaller Spec File
Build command (run from project root d:\Downloader):
    pyinstaller vidgrab.spec --clean
"""

import sys
import os
from PyInstaller.utils.hooks import collect_data_files, collect_submodules

block_cipher = None

# ── Collect hidden imports ────────────────────────────────────────────────────
hidden_imports = (
    collect_submodules("uvicorn")
    + collect_submodules("fastapi")
    + collect_submodules("starlette")
    + collect_submodules("anyio")
    + collect_submodules("httpx")
    + collect_submodules("yt_dlp")
    + collect_submodules("imageio_ffmpeg")
    + [
        "uvicorn.logging",
        "uvicorn.loops",
        "uvicorn.loops.auto",
        "uvicorn.loops.asyncio",
        "uvicorn.protocols",
        "uvicorn.protocols.http",
        "uvicorn.protocols.http.auto",
        "uvicorn.protocols.http.h11_impl",
        "uvicorn.protocols.http.httptools_impl",
        "uvicorn.protocols.websockets",
        "uvicorn.protocols.websockets.auto",
        "uvicorn.protocols.websockets.websockets_impl",
        "uvicorn.lifespan",
        "uvicorn.lifespan.on",
        "uvicorn.lifespan.off",
        "email.mime.text",
        "email.mime.multipart",
        "multiprocessing",
        "multiprocessing.util",
        "pkg_resources",
        "pydantic",
        "pydantic.v1",
    ]
)

# ── Data files to bundle ──────────────────────────────────────────────────────
datas = (
    collect_data_files("uvicorn")
    + collect_data_files("yt_dlp")
    + collect_data_files("imageio_ffmpeg")
    + collect_data_files("fastapi")
    + collect_data_files("starlette")
    + [
        # Bundle the frontend directory (HTML + assets)
        ("frontend", "frontend"),
        # Bundle ads_config.json at root
        ("ads_config.json", "."),
        # Bundle main.py alongside run.py in backend/
        ("backend/main.py", "backend"),
    ]
)

# ── Analysis ──────────────────────────────────────────────────────────────────
a = Analysis(
    ["backend/run.py"],        # Entry point
    pathex=[".", "backend"],   # Search paths
    binaries=[],
    datas=datas,
    hiddenimports=hidden_imports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=["tkinter", "matplotlib", "numpy", "pandas", "scipy"],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name="VidGrab",           # Output exe name
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,                 # Compress with UPX if available
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,            # No terminal window — browser opens automatically
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon="assets/icon.ico",   # App logo from frontend/assets/app-logo.png
)
