#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — fix de build (R8 / release)
# ============================================================
# Causa exacta confirmada en tu log: R8 encuentra que el plugin
# google_mlkit_text_recognition hace referencia (para poder soportar
# chino/devanagari/japonés/coreano SI se usaran) a 4 clases que tu
# proyecto no trae instaladas — porque solo usas reconocimiento de
# texto latino para la traducción por cámara, no esos 4 alfabetos
# adicionales (cada uno es un paquete Gradle aparte que no
# declaraste, correctamente, ya que no lo necesitas).
#
# R8 por defecto trata cualquier clase referenciada-pero-ausente
# como error fatal en release. La solución oficial de Google ML Kit
# para este caso exacto es decirle a R8 "no pasa nada, no las vas a
# necesitar en tiempo de ejecución" con -dontwarn.
#
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_build_r8.sh
#   ./fix_build_r8.sh
# ============================================================
set -euo pipefail

FILE="android/app/proguard-rules.pro"
mkdir -p android/app
touch "$FILE"

if ! grep -q "google.mlkit.vision.text.chinese" "$FILE" 2>/dev/null; then
  cat >> "$FILE" << 'EOF'

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
EOF
  echo "proguard-rules.pro: reglas agregadas."
else
  echo "proguard-rules.pro: las reglas ya estaban, sin cambios."
fi

echo ""
echo "============================================================"
echo " Listo. Verifica UNA vez (no lo puedo confirmar sin ver el"
echo " archivo) que android/app/build.gradle.kts tenga, dentro del"
echo " buildType 'release', algo como:"
echo ""
echo "   proguardFiles("
echo "       getDefaultProguardFile(\"proguard-android-optimize.txt\"),"
echo "       \"proguard-rules.pro\""
echo "   )"
echo ""
echo " (Si el proyecto ya minificaba antes con reglas propias, esto"
echo " ya está — es el default del template de Flutter. Si nunca"
echo " habías tocado proguard-rules.pro, probablemente ya está bien"
echo " igual, porque si NO estuviera referenciado, R8 habría fallado"
echo " antes con un error distinto, no con 'Missing class'.)"
echo ""
echo " Siguiente paso:"
echo "   flutter clean && flutter build apk --release"
echo "============================================================"
