#!/bin/bash
set -euo pipefail

cd /workspaces/copy-fail-challenge-1-2b/kernel/linux

echo "[*] Paso 1: Limpieza total"
make distclean > /dev/null 2>&1 || true
rm -f .config

echo "[*] Paso 2: Genera config base"
make defconfig > /dev/null 2>&1

echo "[*] Paso 3: Elimina líneas comentadas de AEAD"
sed -i '/# CONFIG_CRYPTO_USER_API_AEAD is not set/d' .config
sed -i '/# CONFIG_CRYPTO_USER_API_HASH is not set/d' .config
sed -i '/# CONFIG_CRYPTO_USER_API_SKCIPHER is not set/d' .config

echo "[*] Paso 4: Añade AEAD como MÓDULO (=m)"
echo "CONFIG_CRYPTO_USER_API_AEAD=m" >> .config
echo "CONFIG_CRYPTO_USER_API_HASH=m" >> .config
echo "CONFIG_CRYPTO_USER_API_SKCIPHER=m" >> .config
echo "CONFIG_CRYPTO_AUTHENC=y" >> .config

echo "[✓] Config ANTES de olddefconfig:"
grep "CONFIG_CRYPTO_USER_API_AEAD" .config

echo ""
echo "[*] Paso 5: Valida config (YES a todo)"
yes "" | make oldconfig > /dev/null 2>&1 || true

echo "[✓] Config DESPUÉS de olddefconfig:"
grep "CONFIG_CRYPTO_USER_API_AEAD" .config || echo "NO ENCONTRADO"

echo ""
echo "[*] Paso 6: VERIFICA y FUERZA que sea =m si se cambió"
if ! grep -q "CONFIG_CRYPTO_USER_API_AEAD=m" .config; then
    echo "[!] Se cambió a =y. Forzando newamente a =m..."
    sed -i 's/CONFIG_CRYPTO_USER_API_AEAD=y/CONFIG_CRYPTO_USER_API_AEAD=m/g' .config
    sed -i 's/# CONFIG_CRYPTO_USER_API_AEAD is not set/CONFIG_CRYPTO_USER_API_AEAD=m/g' .config
fi

echo "[✓] Config FINAL verificado:"
grep "CONFIG_CRYPTO_USER_API_AEAD" .config

echo ""
echo "[*] Paso 7: Recompila kernel (~20-30 min, paciencia...)"
make -j$(nproc) 2>&1 | tail -20

echo ""
echo "[*] Paso 8: Busca el módulo"
if [ -f crypto/algif_aead.ko ]; then
    echo "[✓] ¡EXITO! Módulo removible:"
    ls -lh crypto/algif_aead.ko
else
    echo "[-] PROBLEMA: algif_aead.ko NO existe"
    echo "Verificando qué se compiló:"
    [ -f crypto/algif_aead.o ] && echo "  - algif_aead.o (compilado en kernel)" || echo "  - nada"
    grep "CONFIG_CRYPTO_USER_API_AEAD" .config
    exit 1
fi

echo ""
echo "[*] Paso 9: Copia kernel"
cp arch/x86/boot/bzImage ../build/bzImage_vuln
stat ../build/bzImage_vuln | grep Modify

echo ""
echo "✅ BUILD COMPLETADO"
echo ""
echo "PRÓXIMOS PASOS:"
echo "  1. ./scripts/03_run_qemu.sh"
echo "  2. Dentro VM: lsmod | grep algif"
echo "  3. rmmod algif_aead"
echo "  4. ./exploit_c"
echo "  5. id  (debe ser uid=1001, NO root)"
