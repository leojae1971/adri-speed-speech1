#!/usr/bin/env bash
# ============================================================
# ADRI SPEED SPEECH — v14c (reemplaza a v14b)
# ============================================================
# v14b tenía un error en el patrón de búsqueda (un salto de línea de
# más) que hizo que no encontrara nada para corregir, y mi mensaje de
# esa vez fue impreciso -- terminó sin cambiar nada útil. Esta
# versión usa el texto exacto, verificado byte a byte contra el
# archivo real antes de escribir nada.
#
# Qué hace: el getter _lipColorForLanguage (que da el color real de
# labios de cada avatar) había quedado SOLO dentro de _FacePainter,
# una clase que no tiene acceso a `widget` -- de ahí el error de
# compilación "getter or field named 'widget'". Lo mueve a
# _AdriAvatarWidgetState (donde sí existe `widget`, y es donde ya se
# usa correctamente para pasárselo al painter).
#
# Ejecutar desde la raíz del proyecto:
#   chmod +x fix_adri_speed_speech_v14c.sh
#   ./fix_adri_speed_speech_v14c.sh
# ============================================================
set -euo pipefail

LIB="lib"
FILE="$LIB/core/services/avatar/adri_avatar_widget.dart"
BACKUP_SUFFIX=".bak14c_$(date +%Y%m%d_%H%M%S)"
cp "$FILE" "$FILE$BACKUP_SUFFIX"

python3 - "$FILE" << 'PYEOF'
import sys
path = sys.argv[1]
s = open(path, encoding='utf-8').read()

# Caso ya corregido: una sola copia, y está antes de _FacePainter.
idx_class = s.find("class _FacePainter")
idx_getter = s.find("Color get _lipColorForLanguage {")
if (idx_getter != -1 and idx_class != -1 and idx_getter < idx_class
        and s.count("Color get _lipColorForLanguage {") == 1):
    print("adri_avatar_widget.dart: ya está correcto (getter en el State). Sin cambios.")
    sys.exit(0)

GETTER_BLOCK = """  // Medido con reconocimiento facial sobre las 10 fotos reales
  // (color promedio de la zona rellena del labio de cada avatar).
  Color get _lipColorForLanguage {
    return switch (widget.language) {
      'en' => const Color(0xFF9A7361),
      'es' => const Color(0xFFAB7363),
      'sw' => const Color(0xFF7B5747),
      'zh' => const Color(0xFF926B58),
      'hi' => const Color(0xFF865350),
      'fr' => const Color(0xFF95635E),
      'ru' => const Color(0xFF9B6763),
      'pt' => const Color(0xFF97615D),
      'de' => const Color(0xFFAA6B65),
      'ar' => const Color(0xFF9B6763),
      _    => const Color(0xFF9A7361),
    };
  }
"""

# Texto exacto verificado byte a byte (repr()) contra el archivo real
# antes de escribir este script -- un solo \n entre el cierre del
# getter y el _getMouthHeight() de _FacePainter, no dos.
bad_full = GETTER_BLOCK + "\n    double _getMouthHeight() {\n    return switch (viseme) {"
fixed_suffix = "\n    double _getMouthHeight() {\n    return switch (viseme) {"

removed = False
if bad_full in s:
    assert s.count(bad_full) == 1, "más de una coincidencia del bloque a quitar; revisar a mano"
    s = s.replace(bad_full, fixed_suffix, 1)
    removed = True

inserted = False
if "Color get _lipColorForLanguage {" not in s:
    anchor = ("      _    => const Color(0xFF2A211C),\n    };\n  }\n\n"
              "    double _getMouthHeight() {\n    return switch (_currentViseme) {")
    assert anchor in s, "no se encontró el punto de inserción en el State (fin de _browColorForLanguage)"
    s = s.replace(
        anchor,
        ("      _    => const Color(0xFF2A211C),\n    };\n  }\n\n" + GETTER_BLOCK +
         "\n    double _getMouthHeight() {\n    return switch (_currentViseme) {"),
        1,
    )
    inserted = True

total = s.count("Color get _lipColorForLanguage {")
assert total == 1, f"debía quedar exactamente 1 copia, quedaron {total}"

idx_class2 = s.find("class _FacePainter")
idx_getter2 = s.find("Color get _lipColorForLanguage {")
assert idx_getter2 < idx_class2, "el getter quedó del lado equivocado; no se escribió el archivo"

open(path, 'w', encoding='utf-8').write(s)
print(f"adri_avatar_widget.dart corregido (removido de _FacePainter: {removed}, "
      f"agregado al State: {inserted}). Queda 1 sola copia, en el lugar correcto.")
PYEOF

echo ""
echo "============================================================"
echo " v14c aplicado. Backup: $FILE$BACKUP_SUFFIX"
echo " Siguiente paso: flutter run -d R9PT415VJQV"
echo "============================================================"
