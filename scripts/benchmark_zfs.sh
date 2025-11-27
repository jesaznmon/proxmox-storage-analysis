#!/bin/bash

# Benchmark mejorado para ZFS en Proxmox
# Enfocado en métricas críticas para virtualización

PROJECT_DIR=$(find / -type d -name "proxmox-storage-analysis" 2>/dev/null | head -1)
if [ -z "$PROJECT_DIR" ]; then
    echo "ERROR: No se encontró proxmox-storage-analysis"
    exit 1
fi

RESULTS_DIR="$PROJECT_DIR/resultados"
mkdir -p "$RESULTS_DIR"
OUT="$RESULTS_DIR/zfs_mejorado.txt"

# Verificar que ZFS está disponible
if ! command -v zpool &> /dev/null; then
    echo "❌ ERROR: ZFS no está instalado en este sistema"
    echo ""
    echo "Este script debe ejecutarse en una instalación de Proxmox con ZFS."
    echo "Sistema actual: $(df -T / | tail -1 | awk '{print $2}')"
    exit 1
fi

# Detección automática del pool ZFS
POOL=$(zpool list -H -o name 2>/dev/null | head -1)
if [ -z "$POOL" ]; then
    echo "❌ ERROR: No se detectó ningún pool ZFS"
    echo ""
    echo "Este script necesita un pool ZFS configurado."
    echo "Ejecuta 'zpool list' para verificar."
    echo ""
    echo "Sistema actual: $(df -T / | tail -1 | awk '{print $2}')"
    exit 1
fi

# Encontrar dataset principal
DATASET=$(zfs list -H -o name,mounted,mountpoint | grep "yes" | grep -v "@" | awk '{print $1}' | head -1)
MOUNT_POINT=$(zfs get -H -o value mountpoint $DATASET)

echo "==========================================" | tee $OUT
echo "  BENCHMARK ZFS - PROXMOX" | tee -a $OUT
echo "  Pool: $POOL" | tee -a $OUT
echo "  Dataset: $DATASET" | tee -a $OUT
echo "  Montaje: $MOUNT_POINT" | tee -a $OUT
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
# 4. SNAPSHOTS ZFS
# ============================================
echo "=== 4. SNAPSHOTS (ZFS) ===" | tee -a $OUT

START=$(date +%s.%N)
zfs snapshot ${DATASET}@benchmark_test &>/dev/null
END=$(date +%s.%N)
SNAP_TIME=$(echo "$END - $START" | bc)

echo "Tiempo creación: ${SNAP_TIME}s (instantáneo)" | tee -a $OUT

# Contar snapshots existentes
SNAP_COUNT=$(zfs list -t snapshot | grep -c "^$DATASET@" || echo 0)
echo "Snapshots actuales: $SNAP_COUNT" | tee -a $OUT

zfs destroy ${DATASET}@benchmark_test &>/dev/null
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


echo "" | tee -a $OUT
echo "==========================================" | tee -a $OUT
echo "✓ Resultados guardados en: $OUT"
echo "==========================================" | tee -a $OUT
