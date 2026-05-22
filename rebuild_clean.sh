#!/bin/bash
set -euo pipefail

cd /workspaces/copy-fail-challenge-1-2b/kernel/linux

echo "[*] Limpiando build anterior..."
make distclean > /dev/null 2>&1 || true
rm -rf arch/x86/boot/bzImage .config

echo "[*] Recompilando desde cero (esto toma tiempo)..."
make -j$(nproc) > /tmp/build.log 2>&1

BUILD_SIZE=$(stat -c%s arch/x86/boot/bzImage)
echo "[✓] Kernel compilado: $BUILD_SIZE bytes"

cp arch/x86/boot/bzImage ../build/bzImage_patched
cp ../build/bzImage_patched ../build/bzImage_vuln

echo "[✓] Kernel copiado a bzImage_vuln"
ls -lh ../build/bzImage_vuln

echo ""
echo "[✓] Build completo. Ejecuta:"
echo "    cd /workspaces/copy-fail-challenge-1-2b"
echo "    ./scripts/03_run_qemu.sh"
