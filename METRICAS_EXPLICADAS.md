# Métricas de Benchmark - Explicación y Relevancia para Proxmox

## ¿Por qué estas métricas y no otras?

Este documento explica **qué miden los nuevos scripts** y **por qué son importantes** para evaluar sistemas de almacenamiento en Proxmox VE.

---

## 1. RENDIMIENTO SECUENCIAL (MB/s)

### Qué mide:
Velocidad de lectura/escritura cuando los datos se leen o escriben en bloques continuos grandes.

### Por qué importa:
- **Backups de VMs**: Copiar imágenes completas
- **Migraciones**: Mover VMs entre nodos
- **Instalación de ISOs**: Desplegar nuevas máquinas

### Valores típicos:
- SSD SATA: 400-550 MB/s
- NVMe: 2000-3500 MB/s
- HDD RAID: 200-400 MB/s

### Interpretación:
⚠️ No es la métrica más crítica para VMs en producción, pero sí para operaciones administrativas.

---

## 2. IOPS (4K Random)

### Qué mide:
**Operaciones de entrada/salida por segundo** con bloques pequeños (4KB) en ubicaciones aleatorias.

### Por qué importa (CRÍTICO):
- **Bases de datos**: Lecturas/escrituras dispersas
- **Aplicaciones web**: Acceso aleatorio a archivos
- **SO de las VMs**: El kernel hace I/O aleatorio constantemente
- **Múltiples VMs**: Cada VM accede a diferentes partes del disco

### Valores típicos:
- HDD: 100-200 IOPS
- SSD SATA: 10,000-90,000 IOPS
- NVMe: 100,000-500,000 IOPS

### Interpretación:
✅ **LA MÉTRICA MÁS IMPORTANTE** para entornos virtualizados. IOPS bajos = VMs lentas.

---

## 3. LATENCIA (microsegundos/milisegundos)

### Qué mide:
Tiempo que tarda una operación individual de I/O en completarse.

### Por qué importa:
- **Experiencia de usuario**: Latencia alta = aplicaciones congeladas
- **Bases de datos**: Cada query espera por I/O
- **Responsividad**: Afecta directamente cómo se "sienten" las VMs

### Valores típicos:
- NVMe: 50-100 µs (0.05-0.1 ms)
- SSD SATA: 100-500 µs (0.1-0.5 ms)
- HDD: 5,000-10,000 µs (5-10 ms)

### Interpretación:
- < 1 ms: Excelente
- 1-5 ms: Aceptable
- \> 10 ms: Problemático para aplicaciones interactivas

### Relación con IOPS:
```
Latencia baja = Más IOPS posibles
1 ms latencia → máximo 1000 IOPS por proceso
0.1 ms latencia → máximo 10000 IOPS por proceso
```

---

## 4. SNAPSHOTS

### Qué mide:
Velocidad de creación de instantáneas del sistema de archivos.

### Por qué importa:
- **Backups sin downtime**: Snapshot + backup en caliente
- **Protección pre-cambios**: Snapshot antes de updates
- **Recuperación rápida**: Rollback en segundos
- **Replicación**: Enviar cambios incrementales

### Comparativa:
- **ZFS**: Instantáneo (0.001-0.01s), sin overhead de rendimiento
- **BTRFS**: Instantáneo (0.001-0.02s), CoW
- **LVM**: Lento (0.1-2s), consume espacio y afecta rendimiento

### Interpretación:
✅ Para Proxmox con backups frecuentes, snapshots rápidos son esenciales.

---

## 5. COMPRESIÓN

### Qué mide:
Ratio de compresión real y su impacto en rendimiento.

### Por qué importa:
- **Ahorro de espacio**: Más VMs en menos discos
- **Coste efectividad**: 30-50% ahorro típico
- **Trade-off CPU**: ¿Vale la pena el coste computacional?

### Comparativa:
- **ZFS**: Transparente, LZ4 es rápido (~2x compresión, bajo CPU)
- **BTRFS**: Zstd buena compresión, CPU moderado
- **EXT4**: No disponible

### Interpretación:
- Ratio > 1.5x: Muy efectivo
- CPU overhead < 5%: Aceptable
- En SSD pequeños: Muy valioso

---

## 6. CONSUMO DE RECURSOS

### Qué mide:
RAM y CPU usados por el sistema de archivos.

### Por qué importa:
La RAM que usa el almacenamiento no está disponible para las VMs.

### Comparativa:
- **EXT4**: ~50-200 MB caché, CPU bajo
- **ZFS**: 1-8 GB (ARC), CPU medio (checksums)
- **BTRFS**: ~200-500 MB caché, CPU medio

### Regla ZFS:
```
RAM mínima = 2GB + (1GB por TB de almacenamiento)
RAM óptima = 8GB + ARC grande para caché
```

### Interpretación:
⚠️ En servidores con poca RAM (< 16GB), ZFS puede ser contraproducente.

---

## 7. CARACTERÍSTICAS AVANZADAS

### Checksums (Integridad de datos):
- **ZFS**: Sí, automático → Detecta bit rot, corrupción silenciosa
- **BTRFS**: Sí, opcional
- **EXT4**: No → Corrupción puede pasar desapercibida

### Thin Provisioning (Overcommit):
Crear VM de 100GB que solo usa 10GB físicamente.
- **ZFS**: Nativo
- **BTRFS**: Nativo
- **LVM**: LVM-thin (más complejo)

### RAID Integrado:
- **ZFS**: Mirror, RAIDZ (5), RAIDZ2 (6)
- **BTRFS**: Mirror, RAID10 (RAID5/6 experimental)
- **EXT4**: Requiere mdadm o hardware RAID

---

## MATRIZ DE DECISIÓN PARA PROXMOX

| Criterio | EXT4+LVM | ZFS | BTRFS |
|----------|----------|-----|-------|
| **Rendimiento puro** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **IOPS** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Latencia** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Snapshots** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Compresión** | ❌ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Integridad datos** | ❌ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Consumo RAM** | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| **Madurez** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Complejidad** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## RECOMENDACIONES SEGÚN ESCENARIO

### Escenario 1: Servidor pequeño (16GB RAM, 1-5 VMs)
**Recomendado: EXT4+LVM**
- Máximo rendimiento
- Bajo overhead
- Suficiente para pocos snapshots

### Escenario 2: Servidor medio (32-64GB RAM, 10-20 VMs)
**Recomendado: ZFS**
- Integridad crítica con múltiples VMs
- ARC mejora rendimiento con caché
- Snapshots eficientes para backups

### Escenario 3: Datos críticos (bancario, médico)
**Recomendado: ZFS en Mirror o RAIDZ2**
- Checksums detectan cualquier corrupción
- Redundancia integrada
- Scrub regular verifica integridad

### Escenario 4: Máximo rendimiento (gaming, HPC)
**Recomendado: EXT4 en NVMe RAID**
- Cero overhead
- Latencia mínima
- Hardware RAID para redundancia

### Escenario 5: Equilibrio y flexibilidad
**Recomendado: BTRFS**
- Entre EXT4 y ZFS en todo
- Buena opción si no necesitas los extremos

---

## ASPECTOS NO MEDIDOS (pero importantes)

### 1. Fragmentación a largo plazo
- **EXT4**: Se fragmenta, requiere defrag periódico
- **ZFS**: CoW, no se fragmenta
- **BTRFS**: CoW, puede fragmentar parcialmente

### 2. Comportamiento bajo presión
Con 20 VMs haciendo I/O simultáneo, ¿se degrada?

### 3. Recuperación ante fallos
Tiempo de resilvering (reconstrucción) tras fallo de disco.

### 4. Escalabilidad
¿Rendimiento lineal con más discos?

---

## CÓMO USAR LOS SCRIPTS

```bash
# Dar permisos de ejecución
chmod +x scripts/benchmark_*.sh

# Ejecutar según tu sistema
./scripts/benchmark_ext4.sh    # Si usas EXT4+LVM
./scripts/benchmark_zfs.sh     # Si usas ZFS
./scripts/benchmark_btrfs.sh   # Si usas BTRFS

# Los resultados se guardan en:
# resultados/ext4_mejorado.txt
# resultados/zfs_mejorado.txt
# resultados/btrfs_mejorado.txt
```

### ⚠️ Requisitos:
```bash
# Para mediciones completas, instalar fio:
apt update && apt install fio bc -y

# Sin fio, solo se medirá rendimiento secuencial
```

---

## PARA EL INFORME

### Compara especialmente:
1. **IOPS**: ¿Cuál da más operaciones/segundo?
2. **Latencia**: ¿Cuál responde más rápido?
3. **Snapshots**: ¿Cuál es más eficiente?
4. **RAM**: ¿Cuánta memoria consume cada uno?
5. **Trade-offs**: ¿Qué sacrificas por cada feature?

### Conclusión sugerida:
No hay "mejor" absoluto, depende de:
- Tamaño del servidor (RAM disponible)
- Criticidad de datos (¿necesitas checksums?)
- Frecuencia de backups (¿necesitas snapshots rápidos?)
- Presupuesto (¿compresión ahorra discos?)
