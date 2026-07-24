
# ============================================================
# Fix R8/release: google_mlkit_text_recognition referencia estas
# clases (soporte opcional para chino/devanagari/japonés/coreano)
# pero el proyecto solo usa el recognizer latino por defecto para
# la traducción por cámara — estos 4 paquetes no están instalados
# a propósito. Sin este bloque, R8 falla el build de release con
# "Missing class ...ChineseTextRecognizerOptions" (y equivalentes).
# ============================================================
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
