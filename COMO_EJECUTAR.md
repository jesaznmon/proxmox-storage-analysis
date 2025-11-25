# Cómo Ejecutar los Benchmarks

## 🎯 Importante: Cada script se ejecuta en su sistema correspondiente

Los scripts **NO** se ejecutan todos en el mismo lugar. Necesitas ejecutar cada uno en su instalación de Proxmox específica:

```
┌─────────────────────────────────────────────────────────┐
│  Instalación Proxmox #1 (EXT4+LVM)                     │
│  → Ejecutar: benchmark_ext4.sh                          │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Instalación Proxmox #2 (ZFS)                           │
│  → Ejecutar: benchmark_zfs.sh                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Instalación Proxmox #3 (BTRFS)                         │
│  → Ejecutar: benchmark_btrfs.sh                         │
└─────────────────────────────────────────────────────────┘
```

## 📋 Pasos para cada instalación

### 1️⃣ Preparar el sistema Proxmox

Conéctate por SSH a tu servidor Proxmox:

```bash
ssh root@IP_DEL_PROXMOX
```

### 2️⃣ Instalar dependencias

```bash
# En cada Proxmox, instalar fio (herramienta de benchmark)
apt update
apt install fio bc git -y
```

### 3️⃣ Copiar los scripts

**Opción A: Clonar el repositorio**
```bash
cd /root
git clone https://github.com/USUARIO/proxmox-storage-analysis.git
cd proxmox-storage-analysis
```

**Opción B: Copiar manualmente con scp**
Desde tu máquina local:
```bash
# Copiar todo el directorio
scp -r /home/suero/Escritorio/ISI/proxmox-storage-analysis root@IP_PROXMOX:/root/
```

**Opción C: Copiar solo el script necesario**
```bash
# Para Proxmox con EXT4
scp scripts/benchmark_ext4.sh root@IP_PROXMOX:/root/

# Para Proxmox con ZFS
scp scripts/benchmark_zfs.sh root@IP_PROXMOX:/root/

# Para Proxmox con BTRFS
scp scripts/benchmark_btrfs.sh root@IP_PROXMOX:/root/
```

### 4️⃣ Ejecutar el benchmark correspondiente

```bash
# En Proxmox con EXT4
chmod +x benchmark_ext4.sh
./benchmark_ext4.sh

# En Proxmox con ZFS
chmod +x benchmark_zfs.sh
./benchmark_zfs.sh

# En Proxmox con BTRFS
chmod +x benchmark_btrfs.sh
./benchmark_btrfs.sh
```

### 5️⃣ Recuperar los resultados

Los resultados se guardan en `resultados/NOMBRE_mejorado.txt`

**Copiar resultados a tu máquina local:**
```bash
# Desde tu Fedora
scp root@IP_PROXMOX:/root/proxmox-storage-analysis/resultados/*_mejorado.txt \
    /home/suero/Escritorio/ISI/proxmox-storage-analysis/resultados/
```

## ⏱️ Tiempo de ejecución estimado

- **Sin fio**: ~1-2 minutos (solo pruebas básicas)
- **Con fio**: ~3-5 minutos (incluye IOPS y latencia)

## 🔍 Verificar que estás en el sistema correcto

Antes de ejecutar, verifica tu sistema de archivos:

```bash
df -T /
```

Deberías ver:
- `ext4` → Ejecutar benchmark_ext4.sh ✅
- `zfs` → Ejecutar benchmark_zfs.sh ✅
- `btrfs` → Ejecutar benchmark_btrfs.sh ✅

## ❌ Errores Comunes

### Error: "No se detectó sistema ZFS"
```
❌ Problema: Estás en un sistema sin ZFS
✅ Solución: Ejecuta este script en el Proxmox con ZFS
```

### Error: "fio no instalado"
```
❌ Problema: Faltan dependencias
✅ Solución: apt install fio bc -y
```

### Error: "No se encontró proxmox-storage-analysis"
```
❌ Problema: El script no encuentra la carpeta del proyecto
✅ Solución:
   1. Asegúrate de haber copiado toda la carpeta
   2. O ejecuta desde dentro de la carpeta del proyecto
```

## 📊 Ejemplo de Flujo Completo

```bash
# === EN TU FEDORA (preparación) ===
cd /home/suero/Escritorio/ISI/proxmox-storage-analysis

# === EN PROXMOX #1 (EXT4) ===
ssh root@192.168.1.10
apt update && apt install fio bc -y
# [Copiar scripts]
cd /root/proxmox-storage-analysis
./scripts/benchmark_ext4.sh
# [Esperar ~3-5 min]
exit

# === EN PROXMOX #2 (ZFS) ===
ssh root@192.168.1.11
apt update && apt install fio bc -y
# [Copiar scripts]
cd /root/proxmox-storage-analysis
./scripts/benchmark_zfs.sh
# [Esperar ~3-5 min]
exit

# === EN PROXMOX #3 (BTRFS) ===
ssh root@192.168.1.12
apt update && apt install fio bc -y
# [Copiar scripts]
cd /root/proxmox-storage-analysis
./scripts/benchmark_btrfs.sh
# [Esperar ~3-5 min]
exit

# === DE VUELTA EN TU FEDORA ===
# Copiar todos los resultados
scp root@192.168.1.10:/root/proxmox-storage-analysis/resultados/ext4_mejorado.txt resultados/
scp root@192.168.1.11:/root/proxmox-storage-analysis/resultados/zfs_mejorado.txt resultados/
scp root@192.168.1.12:/root/proxmox-storage-analysis/resultados/btrfs_mejorado.txt resultados/

# Ver resultados
cat resultados/*_mejorado.txt
```

## 💡 Consejos

1. **Ejecuta los benchmarks con el sistema en reposo** (sin VMs corriendo)
2. **Apunta los specs del hardware** (RAM, CPU, tipo de disco)
3. **Repite las pruebas 2-3 veces** para confirmar consistencia
4. **Documenta las configuraciones** (compresión ZFS, thin LVM, etc.)

## 🆘 ¿Necesitas ayuda?

Si un script falla:
1. Verifica que estás en el sistema correcto: `df -T /`
2. Verifica que fio está instalado: `which fio`
3. Ejecuta con más detalle: `bash -x ./benchmark_NOMBRE.sh`
4. Lee el mensaje de error completo

## 📖 Para más información

Lee `METRICAS_EXPLICADAS.md` para entender:
- Qué mide cada métrica
- Por qué importa para Proxmox
- Cómo interpretar los resultados
