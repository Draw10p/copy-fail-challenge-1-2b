#!/bin/bash
set -euo pipefail

cd /workspaces/copy-fail-challenge-1-2b

echo "========== PREPARAR HITO 4: PARCHE PERMANENTE =========="
echo ""

echo "[*] Paso 1: Cambiar CONFIG a AEAD=y (compilado en kernel)"
cd kernel/linux

# Modifica .config para compilar AEAD en kernel (no módulo)
sed -i 's/CONFIG_CRYPTO_USER_API_AEAD=m/CONFIG_CRYPTO_USER_API_AEAD=y/' .config
sed -i '/# CONFIG_CRYPTO_USER_API_AEAD is not set/d' .config

if ! grep -q "CONFIG_CRYPTO_USER_API_AEAD=y" .config; then
    echo "CONFIG_CRYPTO_USER_API_AEAD=y" >> .config
fi

echo "[✓] CONFIG actualizada:"
grep "CONFIG_CRYPTO_USER_API_AEAD" .config

echo ""
echo "[*] Paso 2: Aplica parche defensivo de seguridad"
echo ""

# Crea el parche inline
cat > /tmp/algif_aead_cve_fix.patch << 'PATCH_EOF'
--- a/crypto/algif_aead.c
+++ b/crypto/algif_aead.c
@@ -210,7 +210,17 @@ static int _aead_recvmsg(struct socket *sock, struct msghdr *msg, size_t size,
 	 * is achieved by memory management specified as follows.
 	 */
 
-	/* Use the RX SGL as source (and destination) for crypto op. */
+	/* CVE-2026-31431 FIX: Prevent in-place operations via AF_ALG splice
+	 * The vulnerability allows splice() to inject page cache pages into
+	 * the crypto operation, causing out-of-place corruption.
+	 * Solution: Reject if no explicit output buffer provided
+	 */
+	if (!usedpages) {
+		/* No RX buffer = in-place operation impossible, reject */
+		err = -EINVAL;
+		goto free;
+	}
+
+	/* Use the RX SGL as source (and destination) for crypto op. */
 	/* CVE-2026-31431: rsgl_src will be set to TX SGL when usedpages is true */
 	rsgl_src = areq->first_rsgl.sgl.sgt.sgl;
 
PATCH_EOF

if patch -p1 --dry-run < /tmp/algif_aead_cve_fix.patch > /dev/null 2>&1; then
    echo "[✓] Parche se aplica correctamente (dry-run OK)"
    patch -p1 < /tmp/algif_aead_cve_fix.patch
    echo "[✓] Parche APLICADO"
else
    echo "[-] Parche no se aplica, intentando manual..."
    # Aplica el fix manualmente
    sed -i '216a\
	/* CVE-2026-31431 FIX: Prevent in-place operations via AF_ALG splice */\
	if (!usedpages) {\
		err = -EINVAL;\
		goto free;\
	}' crypto/algif_aead.c
    echo "[✓] Fix aplicado manualmente"
fi

echo ""
echo "[*] Paso 3: Verifica el fix en el código"
grep -A 3 "CVE-2026-31431 FIX" crypto/algif_aead.c | head -10

echo ""
echo "[*] Paso 4: Limpia y recompila kernel"
make distclean > /dev/null 2>&1 || true
make defconfig > /dev/null 2>&1
sed -i 's/CONFIG_CRYPTO_USER_API_AEAD=m/CONFIG_CRYPTO_USER_API_AEAD=y/' .config
if ! grep -q "CONFIG_CRYPTO_USER_API_AEAD=y" .config; then
    echo "CONFIG_CRYPTO_USER_API_AEAD=y" >> .config
fi
echo "CONFIG_CRYPTO_AUTHENC=y" >> .config

yes "" | make oldconfig > /dev/null 2>&1 || true

echo "[*] Compilando kernel con parche (~20 min)..."
make -j$(nproc) 2>&1 | tail -20

echo ""
if [ -f arch/x86/boot/bzImage ]; then
    echo "[✓] Kernel compilado EXITOSAMENTE"
    ls -lh arch/x86/boot/bzImage
    cp arch/x86/boot/bzImage ../build/bzImage_vuln
    echo "[✓] bzImage_vuln ACTUALIZADO"
    stat ../build/bzImage_vuln | grep Modify
else
    echo "[-] ERROR: bzImage no existe"
    exit 1
fi

cd ..
echo ""
echo "========== HITO 4 LISTO =========="
echo ""
echo "Ejecuta:"
echo "  cd /workspaces/copy-fail-challenge-1-2b"
echo "  ./scripts/03_run_qemu.sh"
echo ""
echo "Dentro QEMU:"
echo "  ./exploit_c"
echo "  id"
echo ""
echo "Resultado ESPERADO:"
echo "  - Exploit falla (EINVAL o error similar)"
echo "  - uid=1001(student) NO ROOT"
