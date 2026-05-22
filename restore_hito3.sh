#!/bin/bash
set -euo pipefail

cd /workspaces/copy-fail-challenge-1-2b/kernel/linux

echo "========== RESTAURANDO HITO 3: AEAD COMO MÓDULO REMOVIBLE =========="
echo ""

echo "[*] Paso 1: Limpia todo"
make distclean > /dev/null 2>&1 || true
rm -f .config .config.old vmlinux arch/x86/boot/bzImage

echo "[*] Paso 2: Genera config base"
make defconfig > /dev/null 2>&1

echo "[*] Paso 3: Restaura algif_aead.c a ORIGINAL (sin parche)"
git checkout crypto/algif_aead.c 2>/dev/null || echo "No es repo git, saltando"

echo "[*] Paso 4: Configura AEAD como MÓDULO (=m) para Hito 3"
sed -i '/# CONFIG_CRYPTO_USER_API_AEAD is not set/d' .config
echo "CONFIG_CRYPTO_USER_API_AEAD=m" >> .config
echo "CONFIG_CRYPTO_AUTHENC=y" >> .config

echo "[*] Paso 5: Valida config"
yes "" | make oldconfig > /dev/null 2>&1 || true

echo "[✓] Config verificado:"
grep "CONFIG_CRYPTO_USER_API_AEAD" .config

echo ""
echo "[*] Paso 6: Recompila kernel (~20 minutos)"
make -j$(nproc) 2>&1 | tail -30

echo ""
if [ -f arch/x86/boot/bzImage ]; then
    echo "[✓] Kernel compilado exitosamente"
    ls -lh arch/x86/boot/bzImage
    
    cp arch/x86/boot/bzImage ../build/bzImage_vuln
    
    echo "[✓] Kernel copiado a bzImage_vuln"
    stat ../build/bzImage_vuln | grep Modify
else
    echo "[-] ERROR: bzImage no se creó"
    exit 1
fi

echo ""
echo "========== HITO 3 RESTAURADO =========="
echo ""
echo "Próximos pasos:"
echo "  1. cd /workspaces/copy-fail-challenge-1-2b"
echo "  2. ./scripts/03_run_qemu.sh"
echo "  3. Dentro VM: ./exploit_c"
echo "  4. Resultado esperado: Address family not supported (uid=1001)"
