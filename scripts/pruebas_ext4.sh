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

OUT="$DIR/ext4_resultados.txt"

echo "=============== RESULTADOS EXT4 + LVM ===============" > $OUT

# ---- Rendimiento ----
W=$( (dd if=/dev/zero of=/testfile bs=1G count=1 oflag=direct 2>&1) | grep -o '[0-9.]\+ MB/s' | head -1 )
sync
R=$( (dd if=/testfile of=/dev/null bs=1G count=1 iflag=direct 2>&1) | grep -o '[0-9.]\+ MB/s' | head -1 )
rm -f /testfile

# ---- Snapshot LVM ----
LV=$(lvdisplay 2>/dev/null | grep "LV Path" | awk '{print $3}' | head -1)
lvcreate -s -n snap_test -L 1G $LV &>/dev/null
SNAP=$([ $? -eq 0 ] && echo "OK" || echo "FALLÓ")
lvremove -f /dev/*/snap_test &>/dev/null

# ---- Recursos ----
RAM=$(free -m | awk '/Mem:/ {print $3}')

# ---- Integridad ----
dd if=/dev/urandom of=/integrity bs=10M count=1 &>/dev/null
H1=$(sha256sum /integrity | awk '{print $1}')
cp /integrity /integrity2
H2=$(sha256sum /integrity2 | awk '{print $1}')
rm -f /integrity /integrity2
INT=$([ "$H1" = "$H2" ] && echo "OK" || echo "FALLO")

# ---- Volcar resultados ----
echo "Escritura (MB/s): $W" >> $OUT
echo "Lectura  (MB/s): $R" >> $OUT
echo "Snapshot: $SNAP" >> $OUT
echo "Integridad: $INT" >> $OUT
echo "Consumo RAM (MB): $RAM" >> $OUT
echo "Funciones avanzadas: Ninguna" >> $OUT
echo "Tolerancia a fallos: Depende del RAID externo" >> $OUT

echo "======================================================" >> $OUT
echo "Archivo generado en: $OUT"
