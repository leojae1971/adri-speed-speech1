"""
Caché de audio TTS con expiración (30 días).
"""
import hashlib
import time
from pathlib import Path

from config import settings

Path(settings.audio_cache_dir).mkdir(parents=True, exist_ok=True)
CACHE_TTL_DAYS = 30

def _cache_key(text: str, voice_id: str, lang: str) -> str:
    raw = f"{text}:{voice_id}:{lang}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()

def get_cached_audio(text: str, voice_id: str, lang: str) -> bytes | None:
    path = Path(settings.audio_cache_dir) / f"{_cache_key(text, voice_id, lang)}.mp3"
    if not path.exists():
        return None
    if time.time() - path.stat().st_mtime > CACHE_TTL_DAYS * 24 * 3600:
        path.unlink(missing_ok=True)
        return None
    return path.read_bytes()

def store_cached_audio(text: str, voice_id: str, lang: str, audio_bytes: bytes):
    path = Path(settings.audio_cache_dir) / f"{_cache_key(text, voice_id, lang)}.mp3"
    path.write_bytes(audio_bytes)
