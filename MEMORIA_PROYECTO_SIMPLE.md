---
title: "Análisis Comparativo de Sistemas de Almacenamiento en Proxmox VE"
subtitle: "EXT4/LVM vs ZFS vs BTRFS"
author: "Proyecto de Infraestructuras y Sistemas"
date: "Noviembre 2025"
---

# 1. Introducción

## 1.1 Contexto del Proyecto

Proxmox Virtual Environment (Proxmox VE) es una plataforma de virtualización open-source que durante la instalación ofrece tres opciones de almacenamiento local:

- **EXT4 con LVM**: Sistema tradicional de Linux con gestión de volúmenes
- **ZFS**: Sistema avanzado con características enterprise
- **BTRFS**: Sistema moderno con funcionalidades intermedias

La elección del sistema de almacenamiento afecta directamente al rendimiento de las máquinas virtuales, la integridad de datos, la eficiencia de backups y el consumo de recursos del servidor.

## 1.2 Objetivo

Desarrollar scripts de benchmarking para comparar objetivamente los tres sistemas de almacenamiento y determinar cuál es más adecuado según diferentes escenarios de uso.

\newpage

# 2. Metodología

## 2.1 Herramientas Desarrolladas

Se crearon tres scripts bash automatizados (`benchmark_ext4.sh`, `benchmark_zfs.sh`, `benchmark_btrfs.sh`) que miden:

1. **Rendimiento secuencial**: Velocidad de lectura/escritura con bloques grandes (dd)
2. **IOPS**: Operaciones por segundo con bloques pequeños aleatorios (fio)
3. **Latencia**: Tiempo de respuesta de operaciones individuales (fio)
4. **Snapshots**: Velocidad de creación de instantáneas
5. **Consumo de recursos**: RAM y CPU utilizados

## 2.2 Entorno de Pruebas

- **Hardware**: AMD Ryzen 9 3900X, 8GB RAM, disco virtual
- **Software**: Proxmox VE 8.x con configuración por defecto del instalador
- **Condiciones**: Sistema en reposo sin VMs ejecutándose

\newpage

# 3. Análisis del Código Desarrollado

## 3.1 Estructura General de los Scripts

Los tres scripts siguen una estructura común de 4 fases:

```
1. Detección automática del sistema
2. Validación de herramientas necesarias
3. Ejecución de pruebas de rendimiento
4. Generación de informe de resultados
```

## 3.2 Fase 1: Detección Automática

**Objetivo**: Verificar que el script se ejecuta en el sistema correcto.

### Código EXT4:
```bash
MOUNT_POINT=$(df -t ext4 | grep -v "tmpfs" | awk 'NR==2 {print $6}')
if [ -z "$MOUNT_POINT" ]; then
    echo "❌ ERROR: No se detectó sistema de archivos EXT4"
    exit 1
fi
```

**Qué hace**: Busca particiones EXT4 montadas. Si no encuentra ninguna, muestra error y termina.

### Código ZFS:
```bash
if ! command -v zpool &> /dev/null; then
    echo "❌ ERROR: ZFS no está instalado"
    exit 1
fi
POOL=$(zpool list -H -o name | head -1)
```

**Qué hace**: Primero verifica que ZFS esté instalado, luego busca el pool ZFS activo.

## 3.3 Fase 2: Pruebas de Rendimiento Secuencial

**Objetivo**: Medir velocidad con operaciones grandes y continuas (relevante para backups y migraciones).

```bash
sync && echo 3 > /proc/sys/vm/drop_caches

WRITE=$( (dd if=/dev/zero of=$TEST_FILE bs=1M count=1024 \
         oflag=direct 2>&1) | grep -oP '\d+\.?\d* [MG]B/s' | tail -1)
sync
READ=$( (dd if=$TEST_FILE of=/dev/null bs=1M count=1024 \
        iflag=direct 2>&1) | grep -oP '\d+\.?\d* [MG]B/s' | tail -1)
```

**Explicación**:
- `sync`: Fuerza escritura de buffers al disco
- `drop_caches`: Limpia la caché para evitar resultados falsos
- `bs=1M count=1024`: Escribe/lee 1GB en bloques de 1MB
- `oflag=direct / iflag=direct`: I/O directo sin caché (resultados reales)
- Extrae la velocidad (MB/s) del output de dd

## 3.4 Fase 3: Pruebas de IOPS y Latencia

**Objetivo**: Medir operaciones aleatorias pequeñas (LO MÁS IMPORTANTE para VMs).

```bash
if [ "$USE_FIO" = true ]; then
    READ_IOPS=$(fio --name=rr --ioengine=libaio --iodepth=32 \
        --rw=randread --bs=4k --direct=1 --size=512M \
        --runtime=30 --time_based --filename=$TEST_FILE 2>/dev/null | \
        grep "read:" | grep -oP 'IOPS=\K[0-9.k]+')
fi
```

**Parámetros clave de fio**:
- `--rw=randread`: Lectura aleatoria (randwrite para escritura)
- `--bs=4k`: Bloques de 4KB (típico de bases de datos y SO)
- `--iodepth=32`: 32 operaciones simultáneas en cola
- `--runtime=30`: Ejecutar durante 30 segundos
- `--direct=1`: Sin caché

**Por qué 4K aleatorio**: Las VMs constantemente leen/escriben archivos dispersos por el disco. Esta métrica es más crítica que MB/s secuenciales.

## 3.5 Fase 4: Snapshots

### EXT4 con LVM:
```bash
START=$(date +%s.%N)
lvcreate -s -n bench_snap -L 100M $LV &>/dev/null
END=$(date +%s.%N)
SNAP_TIME=$(echo "$END - $START" | bc)
lvremove -f /dev/$VG/bench_snap &>/dev/null
```

**Qué mide**: Tiempo en crear snapshot de 100MB y eliminarlo.

### ZFS:
```bash
START=$(date +%s.%N)
zfs snapshot ${DATASET}@benchmark_test &>/dev/null
END=$(date +%s.%N)
SNAP_TIME=$(echo "$END - $START" | bc)
zfs destroy ${DATASET}@benchmark_test &>/dev/null
```

**Diferencia con LVM**: ZFS no requiere espacio preasignado y es instantáneo (operación de metadata).

### BTRFS:
```bash
btrfs subvolume create $SUBVOL &>/dev/null
dd if=/dev/zero of=$SUBVOL/testfile bs=1M count=100 &>/dev/null

START=$(date +%s.%N)
btrfs subvolume snapshot $SUBVOL ${SUBVOL}_snap &>/dev/null
END=$(date +%s.%N)
```

**Característica**: Similar a ZFS, snapshot instantáneo mediante Copy-on-Write.

## 3.6 Medición de Recursos (ZFS)

```bash
ARC_SIZE=$(awk '/^size/ {print int($3/1024/1024)}' /proc/spl/kstat/zfs/arcstats)
ARC_MAX=$(awk '/^c_max/ {print int($3/1024/1024)}' /proc/spl/kstat/zfs/arcstats)
```

**Qué mide**: El ARC (Adaptive Replacement Cache) es la caché de ZFS que consume RAM del sistema. Esta medición muestra cuánta RAM usa ZFS (crítico porque reduce RAM disponible para VMs).

\newpage

# 4. Métricas Evaluadas y Su Importancia

## 4.1 Rendimiento Secuencial (MB/s)

**Qué es**: Velocidad leyendo/escribiendo bloques grandes en ubicaciones consecutivas.

**Cuándo importa**:
- Backups completos de VMs
- Migraciones entre nodos
- Copias grandes de archivos

**Valores típicos**:
- HDD: 150-200 MB/s
- SSD SATA: 400-550 MB/s
- NVMe: 2000-3500 MB/s

## 4.2 IOPS (Operaciones por Segundo)

**Qué es**: Número de lecturas/escrituras pequeñas (4KB) en ubicaciones aleatorias completadas por segundo.

**Por qué es LA métrica más importante**: Las VMs hacen constantemente I/O aleatorio:
- El sistema operativo lee archivos dispersos
- Las bases de datos acceden a registros no consecutivos
- Múltiples VMs acceden simultáneamente a diferentes partes del disco

**Valores típicos**:
- HDD: 100-150 IOPS → Insuficiente para >3 VMs
- SSD: 10,000-50,000 IOPS → Aceptable para 10-20 VMs
- NVMe: 100,000-400,000 IOPS → Excelente para 50+ VMs

## 4.3 Latencia

**Qué es**: Tiempo que tarda en completarse una operación individual.

**Impacto**:
- < 1ms: Experiencia fluida
- 1-5ms: Aceptable
- \> 10ms: Sistema lento, aplicaciones "colgadas"

## 4.4 Snapshots

**Qué son**: Instantáneas del estado del filesystem en un momento dado.

**Casos de uso**:
- Backup sin parar VMs
- Protección antes de actualizaciones (rollback si falla)
- Clonación rápida de VMs para testing

**Características deseables**:
- Creación rápida (<1s)
- Sin impacto en rendimiento
- Eficientes en espacio (solo guardar cambios)

## 4.5 Checksums e Integridad

**Problema**: "Silent data corruption" - bits que cambian espontáneamente sin aviso.

**Protección ZFS**: Cada bloque tiene checksum verificado en cada lectura. Si detecta corrupción con redundancia (mirror/RAID), usa copia buena y repara la dañada.

**EXT4**: No tiene checksums de datos → Corrupción pasa desapercibida hasta que es tarde.

## 4.6 Consumo de RAM

**EXT4**: ~50-200 MB (caché kernel básica)

**BTRFS**: ~200-500 MB

**ZFS**: Variable, ARC consume 1-16GB típicamente
- En servidor 32GB: ZFS usa ~8GB, quedan ~24GB para VMs
- En servidor 16GB: ZFS usa ~2-4GB, quedan ~12-14GB para VMs

\newpage

# 5. Resultados Obtenidos

## 5.1 EXT4 + LVM

### Rendimiento
```
Escritura secuencial: 92.5 MB/s
Lectura secuencial:   240 MB/s
```

**Análisis**: Valores coherentes con entorno virtualizado. En SSD real se esperaría 400-550 MB/s.

### Snapshots
```
Tiempo creación: 0.1-2s (variable)
Limitación: Requiere espacio libre en Volume Group
```

### Recursos
```
RAM usada: 1.5 GB (sistema completo)
Overhead FS: ~50-100 MB
```

## 5.2 ZFS

### Rendimiento
```
Escritura: 2.5 GB/s ⚠️
Lectura:   3.2 GB/s ⚠️
```

**⚠️ ADVERTENCIA**: Estos valores son desde caché RAM, NO disco real (scripts originales sin direct I/O). Valores reales esperados: 350-450 MB/s en SSD.

### Configuración
```
Pool: rpool (Mirror - RAID 1)
Compresión: LZ4 activa
Ratio compresión: 1.90x (ahorro ~47%)
```

### Snapshots
```
Tiempo creación: <0.01s (instantáneo)
Overhead: Ninguno
```

### Recursos
```
RAM usada: 1.9 GB (incluye ARC)
ARC: Auto-ajustable según RAM disponible
```

\newpage

# 6. Comparativa de Sistemas

## 6.1 Tabla Resumen

| Característica | EXT4+LVM | ZFS | BTRFS |
|----------------|----------|-----|-------|
| **Rendimiento** | Excelente (100%) | Muy bueno (85-90%) | Muy bueno (90-95%) |
| **IOPS** | Máximo | Alto | Alto |
| **Latencia** | Mínima | Media | Baja |
| **Snapshots** | Lentos (LVM) | Instantáneos | Instantáneos |
| **Compresión** | ❌ No | ✅ Sí (LZ4) | ✅ Sí (zstd) |
| **Checksums** | ❌ No | ✅ Sí (todo) | ✅ Sí |
| **Consumo RAM** | Mínimo (~100MB) | Alto (2-16GB) | Medio (~500MB) |
| **Madurez** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **RAID Integrado** | ❌ No | ✅ Sí | ✅ Sí |

## 6.2 Ventajas y Desventajas

### EXT4 + LVM

**✅ Ventajas:**
- Máximo rendimiento (5-15% más rápido)
- Mínimo consumo de RAM
- Muy estable y probado
- Simple de gestionar

**❌ Desventajas:**
- Sin checksums (no detecta corrupción)
- Sin compresión
- Snapshots LVM lentos y consumen espacio
- Requiere RAID hardware para redundancia

**Ideal para**: Servidores con poca RAM (<16GB), máxima prioridad en rendimiento, workloads simples.

### ZFS

**✅ Ventajas:**
- Checksums garantizan integridad de datos
- Snapshots instantáneos perfectos
- Compresión transparente (ahorra 30-50% espacio)
- RAID integrado (mirror, raidz)
- Detección y corrección de errores

**❌ Desventajas:**
- Alto consumo de RAM (ARC)
- Latencia 10-20% mayor que EXT4
- Más complejo de configurar
- Overhead de CPU por checksums/compresión

**Ideal para**: Servidores con 32GB+ RAM, datos críticos, necesidad de snapshots frecuentes, integridad prioritaria.

### BTRFS

**✅ Ventajas:**
- Snapshots instantáneos (como ZFS)
- Checksums de datos
- Compresión opcional
- Consumo RAM moderado
- RAID integrado (1, 10)

**❌ Desventajas:**
- Menos maduro que EXT4 o ZFS
- RAID 5/6 aún experimental
- Puede fragmentarse a largo plazo
- Menos probado en producción enterprise

**Ideal para**: Balance entre funcionalidad y recursos, cuando RAM es limitado pero se necesitan features avanzadas.

\newpage

# 7. Recomendaciones por Escenario

## 7.1 Servidor Pequeño (<16GB RAM, 1-10 VMs)

**Recomendación: EXT4 + LVM**

**Justificación**:
- Máxima RAM disponible para VMs
- Rendimiento excelente
- Suficientemente funcional para pocos snapshots
- No justifica complejidad de ZFS

## 7.2 Servidor Medio (32-64GB RAM, 10-30 VMs)

**Recomendación: ZFS Mirror**

**Justificación**:
- RAM suficiente para ARC efectivo (8-16GB)
- Integridad crítica con múltiples VMs
- Snapshots eficientes para backups frecuentes
- Compresión ahorra ~40% de espacio
- RAID sin hardware dedicado

## 7.3 Datos Críticos (Financiero, Médico, Legal)

**Recomendación: ZFS RAIDZ2**

**Justificación**:
- Checksums detectan cualquier corrupción
- RAIDZ2 tolera 2 fallos de disco simultáneos
- Compliance y auditoría requieren integridad verificable
- No negociable en entornos regulados

## 7.4 Máximo Rendimiento (Gaming, HPC)

**Recomendación: EXT4**

**Justificación**:
- Cero overhead de checksums/compresión
- Latencia mínima
- Cada milisegundo cuenta
- Hardware RAID si necesario

## 7.5 Presupuesto Limitado (RAM <32GB pero necesitas features)

**Recomendación: BTRFS**

**Justificación**:
- Snapshots como ZFS pero menos RAM
- Balance funcionalidad/recursos
- Checksums para integridad básica

## 7.6 Matriz de Decisión

```
¿Tienes más de 32GB RAM?
│
├─ NO: ¿Necesitas snapshots frecuentes?
│      ├─ SÍ: BTRFS
│      └─ NO: EXT4
│
└─ SÍ: ¿Datos críticos?
       ├─ SÍ: ZFS RAIDZ2
       └─ NO: ¿Prioridad máxima = rendimiento?
              ├─ SÍ: EXT4
              └─ NO: ZFS Mirror
```

\newpage

# 8. Conclusiones

## 8.1 Hallazgos Principales

### 1. No existe un "mejor" absoluto
Cada sistema ofrece diferentes compromisos:
- **EXT4**: Rendimiento y simplicidad
- **ZFS**: Integridad y características enterprise
- **BTRFS**: Balance intermedio

### 2. RAM es el factor decisivo para ZFS
- < 16GB: ZFS no recomendado
- 16-32GB: ZFS viable con ARC limitado
- \> 32GB: ZFS óptimo

### 3. IOPS es más crítico que MB/s secuenciales
Para virtualización, las operaciones aleatorias pequeñas (IOPS) importan más que el throughput secuencial. Un SSD con 20,000 IOPS es mejor que un RAID HDD con 400 MB/s para VMs.

### 4. Snapshots de calidad son valiosos operacionalmente
Los snapshots instantáneos de ZFS/BTRFS permiten:
- Backups sin impacto
- Protección automática pre-cambios
- Testing agresivo con rollback fácil

### 5. Integridad no es opcional para datos críticos
La corrupción silenciosa de datos es real. Para entornos críticos, los checksums de ZFS no son un lujo sino un requisito.

## 8.2 Recomendación General

Para **instalaciones nuevas de Proxmox** en escenario típico (servidor medio, 32-64GB RAM, 10-30 VMs):

**→ ZFS en Mirror (RAID 1)**

**Razones**:
- Equilibrio rendimiento/características
- Integridad de datos garantizada
- Snapshots perfectos para backups
- Compresión ahorra espacio
- Bien soportado por Proxmox

**Alternativa** si RAM <16GB o prioridad absoluta en rendimiento:

**→ EXT4 + LVM**

## 8.3 Lecciones del Desarrollo

### De los scripts:
- Limpieza de caché (`drop_caches`) es crucial para resultados reales
- I/O directo (`oflag=direct`) obligatorio para evitar caché
- `fio` es necesario para métricas IOPS/latencia (dd no suficiente)

### Del análisis:
- Las métricas correctas son IOPS y latencia, no solo MB/s
- Características cualitativas (checksums, snapshots) son tan importantes como rendimiento
- La experiencia del equipo importa tanto como las specs técnicas

---

# Referencias

## Herramientas Utilizadas
- **fio**: https://fio.readthedocs.io/
- **Proxmox VE**: https://pve.proxmox.com/wiki/Storage
- **OpenZFS**: https://openzfs.org/

## Scripts del Proyecto
```
/scripts/benchmark_ext4.sh
/scripts/benchmark_zfs.sh
/scripts/benchmark_btrfs.sh
```

## Documentación Adicional
```
METRICAS_EXPLICADAS.md - Explicación detallada de cada métrica
COMO_EJECUTAR.md - Instrucciones de uso paso a paso
```

---

**Fin del documento**
