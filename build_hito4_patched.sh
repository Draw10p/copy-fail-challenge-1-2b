#!/bin/bash
set -euo pipefail

cd /workspaces/copy-fail-challenge-1-2b/kernel/linux

echo "========== HITO 4: Compilar kernel CON PARCHE PERMANENTE =========="
echo ""
echo "[*] Paso 1: Limpieza TOTAL"
make distclean > /dev/null 2>&1 || true
rm -rf .config .config.old vmlinux arch/x86/boot/bzImage

echo "[*] Paso 2: Genera config base"
make defconfig > /dev/null 2>&1

echo "[*] Paso 3: Habilita AEAD como COMPILADO (=y) para Hito 4"
sed -i '/# CONFIG_CRYPTO_USER_API_AEAD is not set/d' .config
echo "CONFIG_CRYPTO_USER_API_AEAD=y" >> .config
echo "CONFIG_CRYPTO_AUTHENC=y" >> .config

echo "[*] Paso 4: Valida config"
yes "" | make oldconfig > /dev/null 2>&1 || true

echo "[✓] Config verificado:"
grep "CONFIG_CRYPTO_USER_API_AEAD" .config

echo ""
echo "[*] Paso 5: Verifica que el parche está en algif_aead.c"
if grep -q "CVE-2026-31431 FIX" crypto/algif_aead.c; then
    echo "[✓] Parche ya está aplicado en código"
else
    echo "[-] ERROR: Parche NO encontrado en código"
    exit 1
fi

echo ""
echo "[*] Paso 6: Recompila kernel CON PARCHE (~20 minutos)"
make 2>&1 | tail -30

echo ""
if [ -f arch/x86/boot/bzImage ]; then
    echo "[✓] Kernel compilado exitosamente"
    ls -lh arch/x86/boot/bzImage
    
    cp arch/x86/boot/bzImage ../build/bzImage_patched
    cp ../build/bzImage_patched ../build/bzImage_vuln
    
    echo "[✓] Kernel copiado a bzImage_vuln"
    stat ../build/bzImage_vuln | grep Modify
else
    echo "[-] ERROR: No se creó bzImage"
    exit 1
fi

echo ""
echo "========== HITO 4 KERNEL LISTO =========="
echo "Próximos pasos:"
echo "  1. ./scripts/03_run_qemu.sh"
echo "  2. Dentro VM: ./exploit_c"
echo "  3. Verifica: id"
echo "  4. Si sale uid=1001(student), el parche FUNCIONA"
