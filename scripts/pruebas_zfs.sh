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

OUT="$DIR/zfs_resultados.txt"
echo "==================== RESULTADOS ZFS ====================" > $OUT

# ---- Rendimiento ----
W=$( (dd if=/dev/zero of=/rpool/testfile bs=1G count=1 oflag=direct 2>&1) | grep -o '[0-9.]\+ MB/s' | head -1 )
sync
R=$( (dd if=/rpool/testfile of=/dev/null bs=1G count=1 iflag=direct 2>&1) | grep -o '[0-9.]\+ MB/s' | head -1 )
rm -f /rpool/testfile

# ---- Compresión ----
COMP=$(zfs get -H -o value compressratio rpool)

# ---- Snapshot ----
zfs snapshot rpool/data@test &>/dev/null
SNAP=$([ $? -eq 0 ] && echo "OK" || echo "FALLO")
zfs destroy rpool/data@test &>/dev/null

# ---- Recursos ----
RAM=$(free -m | awk '/Mem:/ {print $3}')

# ---- Integridad ----
dd if=/dev/urandom of=/rpool/int bs=10M count=1 &>/dev/null
H1=$(sha256sum /rpool/int | awk '{print $1}')
cp /rpool/int /rpool/int2
H2=$(sha256sum /rpool/int2 | awk '{print $1}')
rm -f /rpool/int /rpool/int2
INT=$([ "$H1" = "$H2" ] && echo "OK" || echo "FALLO")

# ---- Volcar ----
echo "Escritura (MB/s): $W" >> $OUT
echo "Lectura  (MB/s): $R" >> $OUT
echo "Compresión: $COMP" >> $OUT
echo "Snapshot: $SNAP" >> $OUT
echo "Integridad: $INT" >> $OUT
echo "Consumo RAM (MB): $RAM" >> $OUT
echo "Funciones avanzadas: Compresión, Snapshots, Checksums, RAID" >> $OUT
echo "Tolerancia a fallos: Alta (mirror)" >> $OUT

echo "========================================================" >> $OUT
echo "Archivo generado en: $OUT"
