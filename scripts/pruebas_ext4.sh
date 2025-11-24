#!/bin/bash

RESULTS="/root/resultados_storage.txt"
echo "===== PRUEBAS EXT4 + LVM =====" > $RESULTS
echo "Fecha: $(date)" >> $RESULTS
echo "" >> $RESULTS

############################################
# 1. INFO DEL SISTEMA
############################################

echo "===== INFO DEL SISTEMA =====" >> $RESULTS
hostname >> $RESULTS
uname -a >> $RESULTS
lsblk -f >> $RESULTS
vgdisplay >> $RESULTS
lvdisplay >> $RESULTS
echo "" >> $RESULTS

############################################
# 2. RENDIMIENTO (dd)
############################################

echo "===== PRUEBA DE RENDIMIENTO (dd) =====" >> $RESULTS
echo "--- Escritura ---" >> $RESULTS
dd if=/dev/zero of=/test_file bs=1G count=1 oflag=direct 2>> $RESULTS

echo "--- Lectura ---" >> $RESULTS
sync
dd if=/test_file of=/dev/null bs=1G count=1 iflag=direct 2>> $RESULTS

rm -f /test_file
echo "" >> $RESULTS

############################################
# 3. SNAPSHOT LVM
############################################

echo "===== SNAPSHOT LVM =====" >> $RESULTS

LV=$(lvdisplay | grep "LV Path" | awk '{print $3}' | head -1)

lvcreate -s -n snap_test -L 1G $LV >> $RESULTS 2>&1
echo "Snapshot creado." >> $RESULTS

lvremove -f /dev/*/snap_test >> $RESULTS 2>&1
echo "Snapshot eliminado." >> $RESULTS
echo "" >> $RESULTS

############################################
# 4. RECURSOS
############################################

echo "===== CONSUMO DE RECURSOS =====" >> $RESULTS
free -h >> $RESULTS
lscpu >> $RESULTS
echo "" >> $RESULTS

############################################
# 5. INTEGRIDAD
############################################

echo "===== INTEGRIDAD DE DATOS =====" >> $RESULTS
dd if=/dev/urandom of=/test_integrity bs=10M count=1 2>> $RESULTS
sha256sum /test_integrity >> $RESULTS
cp /test_integrity /test_integrity_copy
sha256sum /test_integrity_copy >> $RESULTS
rm -f /test_integrity /test_integrity_copy

echo "===== FIN DE PRUEBAS EXT4 + LVM =====" >> $RESULTS
echo "Resultados en: $RESULTS"
