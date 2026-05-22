#!/bin/bash
set -euo pipefail

cd /workspaces/copy-fail-challenge-1-2b

echo "========== DIAGNÓSTICO HITO 3 =========="
echo ""

echo "[*] 1. Verifica si el módulo .ko existe"
if [ -f kernel/linux/crypto/algif_aead.ko ]; then
    echo "[✓] algif_aead.ko EXISTE"
    ls -lh kernel/linux/crypto/algif_aead.ko
else
    echo "[-] algif_aead.ko NO EXISTE - necesita recompilación"
fi

echo ""
echo "[*] 2. Verifica config del kernel"
grep "CONFIG_CRYPTO_USER_API_AEAD" kernel/linux/.config

echo ""
echo "[*] 3. Verifica .config"
if grep -q "CONFIG_CRYPTO_USER_API_AEAD=m" kernel/linux/.config; then
    echo "[✓] Config dice AEAD=m (módulo)"
else
    echo "[-] Config está MAL"
fi

echo ""
echo "[*] 4. Si no existe el módulo, recompila limpio"
if [ ! -f kernel/linux/crypto/algif_aead.ko ]; then
    echo "[-] Recompilando kernel/linux..."
    cd kernel/linux
    
    make distclean > /dev/null 2>&1 || true
    make defconfig > /dev/null 2>&1
    
    sed -i '/# CONFIG_CRYPTO_USER_API_AEAD is not set/d' .config
    echo "CONFIG_CRYPTO_USER_API_AEAD=m" >> .config
    echo "CONFIG_CRYPTO_AUTHENC=y" >> .config
    
    yes "" | make oldconfig > /dev/null 2>&1 || true
    
    echo "[*] Compilando (~20 min)..."
    make -j$(nproc) 2>&1 | tail -20
    
    if [ -f crypto/algif_aead.ko ]; then
        echo "[✓] algif_aead.ko CREADO"
        ls -lh crypto/algif_aead.ko
    else
        echo "[-] ERROR: algif_aead.ko NO se creó"
        exit 1
    fi
    
    cp arch/x86/boot/bzImage ../build/bzImage_vuln
    echo "[✓] bzImage_vuln actualizado"
    
    cd ..
fi

echo ""
echo "========== DIAGNÓSTICO COMPLETO =========="
echo ""
echo "Ahora ejecuta en terminal:"
echo "  cd /workspaces/copy-fail-challenge-1-2b"
echo "  ./scripts/03_run_qemu.sh"
echo ""
echo "Dentro QEMU:"
echo "  lsmod | grep algif"
echo "  rmmod algif_aead"
echo "  ./exploit_c"
echo "  id"
