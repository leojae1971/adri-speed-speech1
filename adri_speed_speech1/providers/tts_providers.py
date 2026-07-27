"""
Implementaciones concretas de TtsProvider: Azure, Google WaveNet, edge-tts.
"""
import io
import azure.cognitiveservices.speech as speechsdk
from google.cloud import texttospeech
import edge_tts

from config import settings
from providers.base import TtsProvider


class AzureTts(TtsProvider):
    name = "azure"

    async def synthesize(self, text: str, voice_id: str, lang: str, rate: int = -10) -> bytes:
        speech_config = speechsdk.SpeechConfig(
            subscription=settings.azure_speech_key,
            region=settings.azure_speech_region,
        )
        speech_config.speech_synthesis_voice_name = voice_id
        speech_config.set_speech_synthesis_output_format(
            speechsdk.SpeechSynthesisOutputFormat.Audio24Khz96KBitRateMonoMp3
        )
        synthesizer = speechsdk.SpeechSynthesizer(speech_config=speech_config, audio_config=None)
        result = synthesizer.speak_text_async(text).get()
        if result.reason != speechsdk.ResultReason.SynthesizingAudioCompleted:
            raise RuntimeError(f"Azure TTS falló: {result.reason}")
        return result.audio_data


class GoogleWavenetTts(TtsProvider):
    name = "google_wavenet"

    def __init__(self):
        self._client = None

    def _get_client(self):
        if self._client is None:
            self._client = texttospeech.TextToSpeechClient()
        return self._client

    async def synthesize(self, text: str, voice_id: str, lang: str, rate: int = -10) -> bytes:
        synthesis_input = texttospeech.SynthesisInput(text=text)
        voice = texttospeech.VoiceSelectionParams(language_code=lang, name=voice_id)
        audio_config = texttospeech.AudioConfig(audio_encoding=texttospeech.AudioEncoding.MP3)
        response = self._get_client().synthesize_speech(
            input=synthesis_input, voice=voice, audio_config=audio_config
        )
        return response.audio_content


class EdgeTts(TtsProvider):
    """
    No oficial — reverse-engineered del motor de voz de Microsoft Edge.
    Último respaldo antes de caer al TTS on-device. Puede romperse sin
    aviso si Microsoft cambia el mecanismo de autenticación interno.
    """
    name = "edge_tts"

    async def synthesize(self, text: str, voice_id: str, lang: str, rate: int = -10) -> bytes:
        rate_str = f"{rate:+d}%"
        communicate = edge_tts.Communicate(text, voice_id, rate=rate_str)
        buffer = io.BytesIO()
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                buffer.write(chunk["data"])
        return buffer.getvalue()
