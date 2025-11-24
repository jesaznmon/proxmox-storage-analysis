#!/bin/bash

RESULTS="/root/resultados_storage.txt"
echo "===== PRUEBAS ZFS =====" > $RESULTS
echo "Fecha: $(date)" >> $RESULTS
echo "" >> $RESULTS

############################################
# 1. INFO ZFS
############################################

echo "===== INFO DEL POOL =====" >> $RESULTS
zpool status >> $RESULTS
zfs list >> $RESULTS
zfs get compressratio rpool >> $RESULTS
echo "" >> $RESULTS

############################################
# 2. RENDIMIENTO
############################################

echo "===== RENDIMIENTO (dd) =====" >> $RESULTS
echo "--- Escritura ---" >> $RESULTS
dd if=/dev/zero of=/rpool/testfile bs=1G count=1 oflag=direct 2>> $RESULTS

sync
echo "--- Lectura ---" >> $RESULTS
dd if=/rpool/testfile of=/dev/null bs=1G count=1 iflag=direct 2>> $RESULTS

rm -f /rpool/testfile
echo "" >> $RESULTS

############################################
# 3. SNAPSHOT
############################################

echo "===== SNAPSHOT ZFS =====" >> $RESULTS
zfs snapshot rpool/data@test_snap >> $RESULTS 2>&1
zfs list -t snapshot >> $RESULTS
zfs destroy rpool/data@test_snap >> $RESULTS
echo "" >> $RESULTS

############################################
# 4. TOLERANCIA A FALLOS (SIMULADA)
############################################

echo "===== SIMULACIÓN DE FALLO DE DISCO =====" >> $RESULTS
zpool offline rpool /dev/sdb >> $RESULTS 2>&1
zpool status >> $RESULTS
zpool online rpool /dev/sdb >> $RESULTS 2>&1
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
dd if=/dev/urandom of=/rpool/test_integrity bs=10M count=1 2>> $RESULTS
sha256sum /rpool/test_integrity >> $RESULTS
cp /rpool/test_integrity /rpool/test_integrity_copy
sha256sum /rpool/test_integrity_copy >> $RESULTS
rm -f /rpool/test_integrity /rpool/test_integrity_copy

echo "===== FIN DE PRUEBAS ZFS =====" >> $RESULTS
echo "Resultados en: $RESULTS"

