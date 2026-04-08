#!/bin/bash
# =============================================================
#  01_create_cert.sh — Створення цифрових сертифікатів
#  Практичне заняття 6: Робота з цифровими сертифікатами
#  Курс: ТСА-233 | ВІТІ
# =============================================================

set -e

# Кольори виводу
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

header() { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}"; }
ok()     { echo -e "${GREEN}  ✔ $1${NC}"; }
info()   { echo -e "${YELLOW}  ℹ $1${NC}"; }
err()    { echo -e "${RED}  ✘ $1${NC}"; exit 1; }
step()   { echo -e "\n${BOLD}  ▶ $1${NC}"; }

# Перевірка залежностей
command -v openssl &>/dev/null || err "OpenSSL не встановлено: sudo apt install openssl"

WORK_DIR="$HOME/certs-lab"
CA_DIR="$WORK_DIR/ca"
SRV_DIR="$WORK_DIR/server"
CLI_DIR="$WORK_DIR/client"

# =============================================================
header "ПІДГОТОВКА"
# =============================================================

step "Створення структури директорій"
mkdir -p "$CA_DIR" "$SRV_DIR" "$CLI_DIR"
ok "Директорії: $WORK_DIR/{ca,server,client}"

echo ""
info "Що буде створено:"
echo "
  certs-lab/
  ├── ca/
  │   ├── ca.key      ← приватний ключ CA (4096 біт)
  │   └── ca.crt      ← самопідписаний сертифікат CA (10 років)
  ├── server/
  │   ├── server.key  ← приватний ключ сервера (2048 біт)
  │   ├── server.csr  ← CSR (запит на підпис)
  │   ├── server.crt  ← підписаний сертифікат (1 рік)
  │   ├── server.der  ← сертифікат у форматі DER
  │   └── server.pfx  ← сертифікат у форматі PKCS#12
  └── client/
      ├── client.key
      ├── client.csr
      └── client.crt
"

cd "$WORK_DIR"

# =============================================================
header "КРОК 1 — Кореневий CA"
# =============================================================

step "Генерація приватного ключа CA (4096 біт)"
openssl genrsa -out "$CA_DIR/ca.key" 4096 2>/dev/null
chmod 400 "$CA_DIR/ca.key"
ok "ca.key створено (права: 400)"

step "Створення самопідписаного сертифіката CA"
openssl req -new -x509 \
    -key "$CA_DIR/ca.key" \
    -out "$CA_DIR/ca.crt" \
    -days 3650 \
    -subj "/C=UA/ST=Kyiv/O=VIIT/CN=VIIT Root CA" \
    2>/dev/null
ok "ca.crt створено (термін: 10 років)"

echo ""
info "Деталі CA сертифіката:"
openssl x509 -in "$CA_DIR/ca.crt" -noout \
    -subject -issuer -dates 2>/dev/null | sed 's/^/    /'

# =============================================================
header "КРОК 2 — Сертифікат сервера"
# =============================================================

step "Генерація приватного ключа сервера (2048 біт)"
openssl genrsa -out "$SRV_DIR/server.key" 2048 2>/dev/null
ok "server.key створено"

step "Генерація CSR (Certificate Signing Request)"
openssl req -new \
    -key "$SRV_DIR/server.key" \
    -out "$SRV_DIR/server.csr" \
    -subj "/C=UA/ST=Kyiv/O=VIIT/CN=tsa233.lab" \
    2>/dev/null
ok "server.csr створено"

info "Вміст CSR:"
openssl req -in "$SRV_DIR/server.csr" -noout -subject 2>/dev/null | sed 's/^/    /'

step "CA підписує сертифікат сервера"

# Розширення SAN для сумісності з сучасними браузерами
cat > /tmp/san_ext.cnf << 'EOF'
subjectAltName = DNS:tsa233.lab, DNS:www.tsa233.lab, DNS:localhost, IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF

openssl x509 -req \
    -in "$SRV_DIR/server.csr" \
    -CA "$CA_DIR/ca.crt" \
    -CAkey "$CA_DIR/ca.key" \
    -CAcreateserial \
    -out "$SRV_DIR/server.crt" \
    -days 365 \
    -sha256 \
    -extfile /tmp/san_ext.cnf \
    2>/dev/null
ok "server.crt підписано CA (термін: 1 рік)"

step "Перевірка ланцюга довіри"
VERIFY=$(openssl verify -CAfile "$CA_DIR/ca.crt" "$SRV_DIR/server.crt" 2>&1)
if echo "$VERIFY" | grep -q "OK"; then
    ok "Ланцюг довіри: $VERIFY"
else
    err "Помилка верифікації: $VERIFY"
fi

# =============================================================
header "КРОК 3 — Конвертація форматів"
# =============================================================

step "PEM → DER (бінарний формат)"
openssl x509 \
    -in "$SRV_DIR/server.crt" \
    -outform DER \
    -out "$SRV_DIR/server.der" \
    2>/dev/null
ok "server.der створено"

step "PEM → PKCS#12 / PFX (для Windows)"
openssl pkcs12 -export \
    -in "$SRV_DIR/server.crt" \
    -inkey "$SRV_DIR/server.key" \
    -certfile "$CA_DIR/ca.crt" \
    -out "$SRV_DIR/server.pfx" \
    -passout pass: \
    -name "tsa233.lab" \
    2>/dev/null
ok "server.pfx створено (порожній пароль)"

# =============================================================
header "КРОК 4 — Клієнтський сертифікат"
# =============================================================

step "Генерація ключа та CSR для клієнта"
openssl genrsa -out "$CLI_DIR/client.key" 2048 2>/dev/null

openssl req -new \
    -key "$CLI_DIR/client.key" \
    -out "$CLI_DIR/client.csr" \
    -subj "/C=UA/ST=Kyiv/O=VIIT/CN=cadet-client" \
    2>/dev/null

cat > /tmp/client_ext.cnf << 'EOF'
extendedKeyUsage = clientAuth
EOF

openssl x509 -req \
    -in "$CLI_DIR/client.csr" \
    -CA "$CA_DIR/ca.crt" \
    -CAkey "$CA_DIR/ca.key" \
    -CAcreateserial \
    -out "$CLI_DIR/client.crt" \
    -days 365 \
    -sha256 \
    -extfile /tmp/client_ext.cnf \
    2>/dev/null
ok "Клієнтський сертифікат створено"

# =============================================================
header "ПІДСУМОК"
# =============================================================

echo ""
info "Створені файли:"
ls -lh "$CA_DIR/" "$SRV_DIR/" "$CLI_DIR/" | grep -v "^total" | sed 's/^/  /'

echo ""
echo -e "${BOLD}  Відбитки сертифікатів (SHA-256):${NC}"
echo -n "  CA:     "
openssl x509 -in "$CA_DIR/ca.crt" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2
echo -n "  Server: "
openssl x509 -in "$SRV_DIR/server.crt" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2
echo -n "  Client: "
openssl x509 -in "$CLI_DIR/client.crt" -noout -fingerprint -sha256 2>/dev/null | cut -d= -f2

echo ""
echo -e "${BOLD}  Наступний крок — встановлення CA:${NC}"
echo "  ./02_install_ca_linux.sh"
echo ""
