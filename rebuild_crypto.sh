#!/bin/bash
set -euo pipefail

cd /workspaces/copy-fail-challenge-1-2b/kernel/linux

echo "========== RECOMPILANDO CRYPTO CON FIX =========="
echo ""

# Fuerza recompilación de algif_aead
echo "[*] Paso 1: Limpia objetos de crypto"
rm -f crypto/algif_aead.o crypto/built-in.a
find crypto -name "*.o" -delete 2>/dev/null || true

echo "[*] Paso 2: Verifica que el fix está en código"
if grep -q "rsgl_src = tsgl_src;" crypto/algif_aead.c; then
    echo "[✓] Fix ENCONTRADO en crypto/algif_aead.c línea 225"
else
    echo "[-] ERROR: Fix NO encontrado"
    exit 1
fi

echo ""
echo "[*] Paso 3: Recompila SOLO kernel (sin distclean)"
make -j$(nproc) 2>&1 | tail -30

echo ""
echo "[*] Paso 4: Verifica bzImage"
if [ -f arch/x86/boot/bzImage ]; then
    echo "[✓] Kernel compilado exitosamente"
    ls -lh arch/x86/boot/bzImage
    cp arch/x86/boot/bzImage ../build/bzImage_vuln
    echo "[✓] Copiado a bzImage_vuln"
    stat ../build/bzImage_vuln | grep Modify
else
    echo "[-] ERROR: bzImage no existe"
    exit 1
fi

echo ""
echo "========== KERNEL RECONSTRUIDO =========="
echo "Ejecuta en otra terminal:"
echo "  cd /workspaces/copy-fail-challenge-1-2b"
echo "  ./scripts/03_run_qemu.sh"
