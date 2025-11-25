#!/bin/bash

PROJECT_DIR=$(find / -type d -name "proxmox-storage-analysis" 2>/dev/null | head -1)

# Si no se encuentra, abortar
if [ -z "$PROJECT_DIR" ]; then
    echo "ERROR: No se encontró la carpeta proxmox-storage-analysis en el sistema."
    exit 1
fi

# Ruta final de resultados
DIR="$PROJECT_DIR/resultados"

# Crear carpeta resultados si no existe
mkdir -p "$DIR"

OUT="$DIR/btrfs_resultados.txt"
echo "==================== RESULTADOS BTRFS ====================" > $OUT

# ---- Rendimiento ----
W=$( (dd if=/dev/zero of=/testfile bs=1G count=1 oflag=direct 2>&1) | grep -o '[0-9.]\+ MB/s' | head -1 )
sync
R=$( (dd if=/testfile of=/dev/null bs=1G count=1 iflag=direct 2>&1) | grep -o '[0-9.]\+ MB/s' | head -1 )
rm -f /testfile

# ---- Snapshot ----
btrfs subvolume create /svtest &>/dev/null
btrfs subvolume snapshot /svtest /svsnap &>/dev/null
SNAP=$([ $? -eq 0 ] && echo "OK" || echo "FALLO")
btrfs subvolume delete /svsnap &>/dev/null
btrfs subvolume delete /svtest &>/dev/null

# ---- Recursos ----
RAM=$(free -m | awk '/Mem:/ {print $3}')

# ---- Integridad ----
dd if=/dev/urandom of=/integrity bs=10M count=1 &>/dev/null
H1=$(sha256sum /integrity | awk '{print $1}')
cp /integrity /integrity2
H2=$(sha256sum /integrity2 | awk '{print $1}')
rm -f /integrity /integrity2
INT=$([ "$H1" = "$H2" ] && echo "OK" || echo "FALLO")

# ---- Volcar ----
echo "Escritura (MB/s): $W" >> $OUT
echo "Lectura  (MB/s): $R" >> $OUT
echo "Snapshot: $SNAP" >> $OUT
echo "Integridad: $INT" >> $OUT
echo "Consumo RAM (MB): $RAM" >> $OUT
echo "Funciones avanzadas: Snapshots, Subvolúmenes, Compresión (opcional)" >> $OUT
echo "Tolerancia a fallos: Media (según config RAID)" >> $OUT

echo "==========================================================" >> $OUT
echo "Archivo generado en: $OUT"
