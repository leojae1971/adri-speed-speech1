#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v6 (últimos 2 errores de chat_screen.dart)
# ============================================================
# Ejecutar desde la raíz del proyecto (la misma carpeta donde ya
# corriste v5):
#
#   chmod +x fix_adri_speed_speech_v6.sh
#   ./fix_adri_speed_speech_v6.sh
#
# Corrige los 2 errores que quedaron después de v5:
#
#  1. lib/features/vocabulary/presentation/screens/chat_screen.dart:17
#     final AppDatabase _db = AppDatabase();
#     Patrón distinto al que busqué en v5 (ese buscaba "late
#     AppDatabase _db;" + inicialización aparte; este archivo lo
#     tenía declarado E inicializado en la misma línea). Ya no se usa
#     en ningún lado (v5 quitó todas sus llamadas), así que se
#     elimina el campo completo.
#
#  2. chat_screen.dart:56 — falta el parámetro requerido
#     onLanguageDetected en _speechService.listen(...). Se agrega
#     automáticamente como no-op si aún no está presente.
# ============================================================
set -euo pipefail

LIB="lib"
FILE="$LIB/features/vocabulary/presentation/screens/chat_screen.dart"
BACKUP_SUFFIX=".bak6_$(date +%Y%m%d_%H%M%S)"
cp "$FILE" "$FILE$BACKUP_SUFFIX"

python3 - "$FILE" << 'PYEOF'
import re, sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()
changes = []

# 1) quitar el campo _db (declarado + inicializado en la misma línea)
new_s = re.sub(r"[ \t]*final AppDatabase _db = AppDatabase\(\);\n", "", s)
if new_s != s:
    changes.append("campo '_db' eliminado (ya no se usa)")
s = new_s

# Por si en tu copia quedó alguna otra variante de esa misma idea:
new_s = re.sub(r"[ \t]*late final AppDatabase _db;\n", "", s)
if new_s != s:
    changes.append("campo 'late final _db' eliminado")
s = new_s

# 2) agregar onLanguageDetected: (_) {}, si falta, al primer
#    _speechService.listen( que no lo tenga.
def add_param(m):
    call = m.group(0)
    if "onLanguageDetected" in call:
        return call
    return call.replace(
        "_speechService.listen(",
        "_speechService.listen(\n        onLanguageDetected: (_) {},",
        1,
    )

new_s, n = re.subn(
    r"_speechService\.listen\([^)]*\)\)?,?",
    add_param,
    s,
    count=1,
)
if n and "onLanguageDetected" not in s:
    changes.append("onLanguageDetected: (_) {} agregado a _speechService.listen(...)")
s = new_s

open(path, 'w', encoding='utf-8').write(s)
if changes:
    print("chat_screen.dart actualizado: " + "; ".join(changes) + ".")
else:
    print("AVISO: no se encontró ninguno de los 2 patrones esperados; puede que ya estén corregidos o el formato difiera. Revisar a mano.", file=sys.stderr)
PYEOF

echo ""
echo "============================================================"
echo " v6 aplicado. Backup: $FILE$BACKUP_SUFFIX"
echo " Siguiente paso: flutter run -d R9PT415VJQV"
echo "============================================================"
