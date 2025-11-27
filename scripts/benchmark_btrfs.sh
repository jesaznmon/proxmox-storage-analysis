#!/bin/bash

# Benchmark mejorado para BTRFS en Proxmox
# Enfocado en métricas críticas para virtualización

PROJECT_DIR=$(find / -type d -name "proxmox-storage-analysis" 2>/dev/null | head -1)
if [ -z "$PROJECT_DIR" ]; then
    echo "ERROR: No se encontró proxmox-storage-analysis"
    exit 1
fi

RESULTS_DIR="$PROJECT_DIR/resultados"
mkdir -p "$RESULTS_DIR"
OUT="$RESULTS_DIR/btrfs_mejorado.txt"

# Detección automática del punto de montaje BTRFS
MOUNT_POINT=$(df -t btrfs | grep -v "tmpfs" | awk 'NR==2 {print $6}')
if [ -z "$MOUNT_POINT" ]; then
    echo "❌ ERROR: No se detectó sistema de archivos BTRFS"
    echo ""
    echo "Este script debe ejecutarse en una instalación con BTRFS."
    echo "Sistema actual: $(df -T / | tail -1 | awk '{print $2}')"
    echo ""
    echo "Ejecuta 'df -T' para ver tus sistemas de archivos."
    exit 1
fi

echo "==========================================" | tee $OUT
echo "  BENCHMARK BTRFS - PROXMOX" | tee -a $OUT
echo "  Punto de montaje: $MOUNT_POINT" | tee -a $OUT
echo "  Fecha: $(date)" | tee -a $OUT
echo "==========================================" | tee -a $OUT
echo "" | tee -a $OUT

# Verificar fio
USE_FIO=true
if ! command -v fio &> /dev/null; then
    echo "⚠️  fio no instalado. Ejecutar: apt install fio" | tee -a $OUT
    USE_FIO=false
fi

TEST_FILE="$MOUNT_POINT/benchmark_test_$$"

# ============================================
# 1. RENDIMIENTO SECUENCIAL
# ============================================
echo "=== 1. RENDIMIENTO SECUENCIAL ===" | tee -a $OUT
sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null

WRITE=$( (dd if=/dev/zero of=$TEST_FILE bs=1M count=1024 oflag=direct 2>&1) | grep -oP '\d+\.?\d* [MG]B/s' | tail -1)
sync
READ=$( (dd if=$TEST_FILE of=/dev/null bs=1M count=1024 iflag=direct 2>&1) | grep -oP '\d+\.?\d* [MG]B/s' | tail -1)

echo "Escritura: $WRITE" | tee -a $OUT
echo "Lectura:   $READ" | tee -a $OUT
echo "" | tee -a $OUT

# ============================================
# 2. IOPS (CRÍTICO para VMs)
# ============================================
echo "=== 2. IOPS 4K Random (VMs y BBDD) ===" | tee -a $OUT

if [ "$USE_FIO" = true ]; then
    # Random Read
    READ_IOPS=$(fio --name=rr --ioengine=libaio --iodepth=32 --rw=randread \
        --bs=4k --direct=1 --size=512M --numjobs=1 --runtime=30 --time_based \
        --group_reporting --filename=$TEST_FILE 2>/dev/null | \
        grep "read:" | grep -oP 'IOPS=\K[0-9.k]+')

    # Random Write
    WRITE_IOPS=$(fio --name=rw --ioengine=libaio --iodepth=32 --rw=randwrite \
        --bs=4k --direct=1 --size=512M --numjobs=1 --runtime=30 --time_based \
        --group_reporting --filename=$TEST_FILE 2>/dev/null | \
        grep "write:" | grep -oP 'IOPS=\K[0-9.k]+')

    echo "Read IOPS:  $READ_IOPS" | tee -a $OUT
    echo "Write IOPS: $WRITE_IOPS" | tee -a $OUT
else
    echo "No disponible sin fio" | tee -a $OUT
fi
echo "" | tee -a $OUT

# ============================================
# 3. LATENCIA
# ============================================
echo "=== 3. LATENCIA (menor = mejor) ===" | tee -a $OUT

if [ "$USE_FIO" = true ]; then
    LAT=$(fio --name=lat --ioengine=libaio --iodepth=1 --rw=randread \
        --bs=4k --direct=1 --size=256M --numjobs=1 --runtime=20 --time_based \
        --group_reporting --filename=$TEST_FILE 2>/dev/null | \
        grep "lat (usec):" | head -1)
    echo "$LAT" | tee -a $OUT
else
    echo "No disponible sin fio" | tee -a $OUT
fi
echo "" | tee -a $OUT

rm -f $TEST_FILE

# ============================================
# 4. SNAPSHOTS BTRFS
# ============================================
echo "=== 4. SNAPSHOTS (BTRFS) ===" | tee -a $OUT

SUBVOL="$MOUNT_POINT/bench_subvol_$$"
btrfs subvolume create $SUBVOL &>/dev/null

# Crear algo de contenido
dd if=/dev/zero of=$SUBVOL/testfile bs=1M count=100 &>/dev/null 2>&1

START=$(date +%s.%N)
btrfs subvolume snapshot $SUBVOL ${SUBVOL}_snap &>/dev/null
END=$(date +%s.%N)
SNAP_TIME=$(echo "$END - $START" | bc)

echo "Tiempo creación: ${SNAP_TIME}s" | tee -a $OUT

# Contar subvolúmenes
SUBVOL_COUNT=$(btrfs subvolume list $MOUNT_POINT 2>/dev/null | wc -l)
echo "Subvolúmenes actuales: $SUBVOL_COUNT" | tee -a $OUT

btrfs subvolume delete ${SUBVOL}_snap &>/dev/null
btrfs subvolume delete $SUBVOL &>/dev/null
echo "" | tee -a $OUT

# ============================================
# 5. RECURSOS
# ============================================
echo "=== 5. CONSUMO DE RECURSOS ===" | tee -a $OUT

RAM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
RAM_USADO=$(free -m | awk '/^Mem:/ {print $3}')
CACHE=$(free -m | awk '/^Mem:/ {print $6}')

echo "RAM total: ${RAM_TOTAL} MB" | tee -a $OUT
echo "RAM usada: ${RAM_USADO} MB" | tee -a $OUT
echo "Caché FS:  ${CACHE} MB" | tee -a $OUT
echo "" | tee -a $OUT

# ============================================
# 6. ANÁLISIS PARA PROXMOX
# ============================================
echo "=== 6. VALORACIÓN PARA PROXMOX ===" | tee -a $OUT
echo "" | tee -a $OUT
echo "VENTAJAS:" | tee -a $OUT
echo "  ✓ Snapshots instantáneos (CoW)" | tee -a $OUT
echo "  ✓ Subvolúmenes flexibles" | tee -a $OUT
echo "  ✓ Compresión opcional (zstd, lzo)" | tee -a $OUT
echo "  ✓ RAID integrado (1, 5, 6, 10)" | tee -a $OUT
echo "  ✓ Checksums de datos" | tee -a $OUT
echo "  ✓ Balance automático" | tee -a $OUT
echo "  ✓ Consumo RAM moderado" | tee -a $OUT
echo "" | tee -a $OUT
echo "DESVENTAJAS:" | tee -a $OUT
echo "  ⚠  Menos maduro que EXT4 o ZFS" | tee -a $OUT
echo "  ⚠  RAID 5/6 aún experimental" | tee -a $OUT
echo "  ⚠  Puede fragmentarse con el tiempo" | tee -a $OUT
echo "  ⚠  Rendimiento variable según carga" | tee -a $OUT
echo "" | tee -a $OUT
echo "USO RECOMENDADO:" | tee -a $OUT
echo "  • Balance entre funcionalidad y recursos" | tee -a $OUT
echo "  • Cuando se necesitan snapshots pero RAM es limitado" | tee -a $OUT
echo "  • Workloads mixtos (no extremos)" | tee -a $OUT
echo "  • Flexibilidad en gestión de volúmenes" | tee -a $OUT
echo "" | tee -a $OUT
echo "NO RECOMENDADO:" | tee -a $OUT
echo "  • Entornos de producción críticos (usar ZFS o EXT4)" | tee -a $OUT
echo "  • Bases de datos de alto rendimiento" | tee -a $OUT

echo "" | tee -a $OUT
echo "==========================================" | tee -a $OUT
echo "✓ Resultados guardados en: $OUT"
echo "==========================================" | tee -a $OUT
