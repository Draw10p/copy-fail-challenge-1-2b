#!/bin/bash
set -euo pipefail

cd /workspaces/copy-fail-challenge-1-2b/kernel/linux

echo "[*] LIMPIEZA NUCLEAR - Elimina TODO"
make distclean 2>/dev/null || true
rm -rf .config .config.old .config.prev
rm -rf vmlinux vmlinux.o vmlinux.symvers
rm -rf arch/x86/boot/bzImage
find . -name "*.o" -delete 2>/dev/null || true
find . -name "*.a" -delete 2>/dev/null || true

echo "[*] Genera config limpio"
make defconfig > /dev/null 2>&1

echo "[*] Configura AEAD como módulo"
sed -i '/# CONFIG_CRYPTO_USER_API_AEAD is not set/d' .config
echo "CONFIG_CRYPTO_USER_API_AEAD=m" >> .config

echo "[*] Valida"
yes "" | make oldconfig > /dev/null 2>&1 || true

echo "[✓] Verificación final:"
grep "CONFIG_CRYPTO_USER_API_AEAD" .config

echo ""
echo "[*] Compilando limpiamente (sin paralelismo)"
make 2>&1 | tail -30

echo ""
if [ -f crypto/algif_aead.ko ]; then
    echo "[✓] ¡ÉXITO! Módulo creado:"
    ls -lh crypto/algif_aead.ko
    cp arch/x86/boot/bzImage ../build/bzImage_vuln
    echo "[✓] Kernel copiado"
else
    echo "[-] FALLO: No se creó módulo"
    [ -f crypto/algif_aead.o ] && echo "  Pero sí se compiló algif_aead.o (en kernel)" || true
fi
