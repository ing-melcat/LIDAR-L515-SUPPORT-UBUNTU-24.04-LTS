#!/usr/bin/env bash
# Uso: freeze_image.sh <imagen:tag> [carpeta_salida]
set -euo pipefail
IMG="${1:?uso: freeze_image.sh <imagen:tag> [carpeta]}"
OUT="${2:-./freeze}"
mkdir -p "$OUT"
FILE="$OUT/$(echo "$IMG" | tr '/:' '__').tar.gz"
docker image inspect "$IMG" >/dev/null
docker save "$IMG" | gzip > "$FILE"
( cd "$OUT" && sha256sum "$(basename "$FILE")" >> SHA256SUMS )
docker image inspect "$IMG" --format 'ID: {{.Id}}' | tee -a "$OUT/image_id.txt"
echo "Imagen exportada: $FILE"
echo "Checksum guardado en $OUT/SHA256SUMS"
echo "Guarda la carpeta en un disco o registro propio: sin ella no se puede reconstruir sin internet."
