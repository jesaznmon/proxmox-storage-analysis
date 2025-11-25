#!/bin/bash

RESULTS="/root/resultados_storage.txt"
echo "===== PRUEBAS BTRFS =====" > $RESULTS
echo "Fecha: $(date)" >> $RESULTS
echo "" >> $RESULTS

############################################
# 1. INFO BTRFS
############################################

echo "===== INFO DEL FILESYSTEM =====" >> $RESULTS
btrfs filesystem df / >> $RESULTS
btrfs filesystem show >> $RESULTS
echo "" >> $RESULTS

############################################
# 2. RENDIMIENTO
############################################

echo "===== RENDIMIENTO (dd) =====" >> $RESULTS
dd if=/dev/zero of=/test_btrfs bs=1G count=1 oflag=direct 2>> $RESULTS
sync
dd if=/test_btrfs of=/dev/null bs=1G count=1 iflag=direct 2>> $RESULTS
rm -f /test_btrfs
echo "" >> $RESULTS

############################################
# 3. SUBVOLUMEN + SNAPSHOT
############################################

echo "===== SUBVOLUMEN Y SNAPSHOT =====" >> $RESULTS
btrfs subvolume create /btrfs_test >> $RESULTS
btrfs subvolume snapshot /btrfs_test /btrfs_test_snap >> $RESULTS
btrfs subvolume list / >> $RESULTS
btrfs subvolume delete /btrfs_test_snap >> $RESULTS
btrfs subvolume delete /btrfs_test >> $RESULTS
echo "" >> $RESULTS

############################################
# 4. COMPRESIÓN
############################################

echo "===== COMPRESIÓN =====" >> $RESULTS
dd if=/dev/zero of=/test_compress bs=100M count=1 2>> $RESULTS
btrfs filesystem df / >> $RESULTS
rm -f /test_compress
echo "" >> $RESULTS

############################################
# 5. RECURSOS
############################################

echo "===== RECURSOS =====" >> $RESULTS
free -h >> $RESULTS
lscpu >> $RESULTS
echo "" >> $RESULTS

############################################
# 6. INTEGRIDAD
############################################

echo "===== INTEGRIDAD =====" >> $RESULTS
dd if=/dev/urandom of=/test_integrity bs=10M count=1 2>> $RESULTS
sha256sum /test_integrity >> $RESULTS
cp /test_integrity /test_integrity_copy
sha256sum /test_integrity_copy >> $RESULTS
rm -f /test_integrity /test_integrity_copy

echo "===== FIN DE PRUEBAS BTRFS =====" >> $RESULTS
echo "Resultados en: $RESULTS"
