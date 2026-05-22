#!/bin/bash
set -euo pipefail

cd /workspaces/copy-fail-challenge-1-2b/kernel/linux

echo "========== COMPILAR KERNEL + MÓDULO + INITRAMFS HITO 3 =========="
echo ""

echo "[*] Paso 1: Verifica configuración"
grep "CONFIG_CRYPTO_USER_API_AEAD" .config

echo ""
echo "[*] Paso 2: Compila el módulo"
make -j$(nproc) 2>&1 | tail -10

echo ""
echo "[*] Paso 3: Instala módulo en staging area"
mkdir -p ../initramfs/lib/modules/6.12.0/kernel/crypto

if [ -f crypto/algif_aead.ko ]; then
    cp crypto/algif_aead.ko ../initramfs/lib/modules/6.12.0/kernel/crypto/
    echo "[✓] algif_aead.ko copiado a initramfs"
    ls -lh ../initramfs/lib/modules/6.12.0/kernel/crypto/algif_aead.ko
else
    echo "[-] ERROR: algif_aead.ko no existe"
    exit 1
fi

echo ""
echo "[*] Paso 4: Regenera initramfs"
cd ../initramfs
find . -print0 | cpio --null --create --verbose --format=newc | gzip --best > ../build/initramfs.cpio.gz 2>&1 | tail -5
cd ../linux

echo "[✓] Initramfs regenerado"
ls -lh ../build/initramfs.cpio.gz

echo ""
echo "[*] Paso 5: Recompila kernel con nuevo initramfs"
make -j$(nproc) 2>&1 | tail -10

echo ""
if [ -f arch/x86/boot/bzImage ]; then
    echo "[✓] Kernel compilado"
    cp arch/x86/boot/bzImage ../build/bzImage_vuln
    echo "[✓] bzImage_vuln actualizado"
    stat ../build/bzImage_vuln | grep Modify
else
    echo "[-] ERROR: bzImage no existe"
    exit 1
fi

echo ""
echo "========== LISTO PARA HITO 3 =========="
echo ""
echo "Ejecuta:"
echo "  cd /workspaces/copy-fail-challenge-1-2b"
echo "  ./scripts/03_run_qemu.sh"
echo ""
echo "Dentro QEMU:"
echo "  lsmod | grep algif"
echo "  rmmod algif_aead"
echo "  ./exploit_c"
echo "  id"
