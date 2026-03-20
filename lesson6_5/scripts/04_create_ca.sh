#!/bin/bash
# =============================================================
#  04_create_ca.sh — Створення CA та видача сертифікатів
#  Лабораторна робота: PKI | ВІТІ
# =============================================================

set -e

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

command -v openssl &>/dev/null || err "openssl не встановлено: sudo apt install openssl"

PKI_DIR="$HOME/pki"
CA_DIR="$PKI_DIR/ca"
SRV_DIR="$PKI_DIR/server"
CLI_DIR="$PKI_DIR/client"

mkdir -p "$CA_DIR" "$SRV_DIR" "$CLI_DIR"
cd "$PKI_DIR"

# ------------------------------------------------------------
header "КРОК 1 — Створення кореневого CA"
# ------------------------------------------------------------

info "Структура PKI що буде створена:"
echo ""
echo "  pki/"
echo "  ├── ca/"
echo "  │   ├── ca.key   ← приватний ключ CA (найсекретніший файл!)"
echo "  │   └── ca.crt   ← самопідписаний сертифікат CA (довіряємо всьому)"
echo "  ├── server/"
echo "  │   ├── server.key  ← приватний ключ сервера"
echo "  │   ├── server.csr  ← запит на підпис (CSR)"
echo "  │   └── server.crt  ← підписаний сертифікат сервера"
echo "  └── client/"
echo "      ├── client.key"
echo "      ├── client.csr"
echo "      └── client.crt"
echo ""

info "Генерація приватного ключа кореневого CA (4096 біт)..."
openssl genrsa -out "$CA_DIR/ca.key" 4096 2>/dev/null
chmod 400 "$CA_DIR/ca.key"   # лише читання власником
ok "ca.key створено (права: 400 — лише читання)"

info "Створення самопідписаного сертифіката CA (10 років)..."
openssl req -new -x509 \
    -key     "$CA_DIR/ca.key" \
    -out     "$CA_DIR/ca.crt" \
    -days    3650 \
    -subj    "/C=UA/ST=Kyiv/O=VIIT Lab/CN=VIIT Root CA" \
    2>/dev/null

ok "ca.crt створено"
echo ""
info "Інформація про CA-сертифікат:"
openssl x509 -in "$CA_DIR/ca.crt" -noout \
    -subject -issuer -dates \
    | sed 's/^/     /'

# ------------------------------------------------------------
header "КРОК 2 — Запит на сертифікат для сервера"
# ------------------------------------------------------------

info "Генерація ключа сервера (2048 біт)..."
openssl genrsa -out "$SRV_DIR/server.key" 2048 2>/dev/null
ok "server.key створено"

info "Створення CSR (Certificate Signing Request)..."
openssl req -new \
    -key  "$SRV_DIR/server.key" \
    -out  "$SRV_DIR/server.csr" \
    -subj "/C=UA/ST=Kyiv/O=VIIT Lab/CN=tsa233.lab" \
    2>/dev/null

ok "server.csr створено"
echo ""
info "Вміст CSR (що саме підписуватиме CA):"
openssl req -in "$SRV_DIR/server.csr" -noout -subject -text 2>/dev/null \
    | grep -E "Subject:|DNS:|IP:" | sed 's/^/     /'

# ------------------------------------------------------------
header "КРОК 3 — CA підписує сертифікат сервера"
# ------------------------------------------------------------

# Конфіг для Subject Alternative Names (SAN)
cat > "$SRV_DIR/san.cnf" <<EOF
[req]
req_extensions = v3_req
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = tsa233.lab
DNS.2 = www.tsa233.lab
DNS.3 = mail.tsa233.lab
IP.1  = 192.168.1.10
IP.2  = 127.0.0.1
EOF

info "CA підписує сертифікат сервера (365 днів)..."
openssl x509 -req \
    -in      "$SRV_DIR/server.csr" \
    -CA      "$CA_DIR/ca.crt" \
    -CAkey   "$CA_DIR/ca.key" \
    -CAcreateserial \
    -out     "$SRV_DIR/server.crt" \
    -days    365 \
    -extensions v3_req \
    -extfile "$SRV_DIR/san.cnf" \
    2>/dev/null

ok "server.crt підписано CA"
echo ""
info "Деталі виданого сертифіката:"
openssl x509 -in "$SRV_DIR/server.crt" -noout \
    -subject -issuer -dates \
    | sed 's/^/     /'

# ------------------------------------------------------------
header "КРОК 4 — Перевірка ланцюга довіри"
# ------------------------------------------------------------

echo ""
info "Перевірка: чи підписаний server.crt нашим CA?"
openssl verify -CAfile "$CA_DIR/ca.crt" "$SRV_DIR/server.crt" \
    && ok "Ланцюг довіри підтверджено: server.crt ← VIIT Root CA" \
    || err "Перевірка не пройшла!"

# Демонстрація: сертифікат від чужого CA не пройде
info "Перевірка: прийме чи чужий сертифікат?"
openssl req -new -x509 \
    -newkey rsa:2048 -nodes \
    -keyout /tmp/other.key \
    -out    /tmp/other.crt \
    -days   1 \
    -subj   "/CN=Fake CA" \
    2>/dev/null

if openssl verify -CAfile "$CA_DIR/ca.crt" /tmp/other.crt 2>/dev/null; then
    echo "  Підписано (несподівано)"
else
    ok "Чужий сертифікат відхилено — ланцюг довіри не збігається ✓"
fi

# ------------------------------------------------------------
header "КРОК 5 — Клієнтський сертифікат"
# ------------------------------------------------------------

info "Видача клієнтського сертифіката (для mTLS)..."
openssl genrsa -out "$CLI_DIR/client.key" 2048 2>/dev/null

openssl req -new \
    -key  "$CLI_DIR/client.key" \
    -out  "$CLI_DIR/client.csr" \
    -subj "/C=UA/O=VIIT Lab/CN=cadet-$(whoami)" \
    2>/dev/null

openssl x509 -req \
    -in      "$CLI_DIR/client.csr" \
    -CA      "$CA_DIR/ca.crt" \
    -CAkey   "$CA_DIR/ca.key" \
    -CAcreateserial \
    -out     "$CLI_DIR/client.crt" \
    -days    365 \
    2>/dev/null

ok "Клієнтський сертифікат видано для: cadet-$(whoami)"

# ------------------------------------------------------------
header "КРОК 6 — Налаштування nginx з TLS (якщо встановлено)"
# ------------------------------------------------------------

if command -v nginx &>/dev/null; then
    info "nginx знайдено — налаштовуємо HTTPS..."

    sudo cp "$SRV_DIR/server.crt" /etc/ssl/certs/tsa233.crt
    sudo cp "$SRV_DIR/server.key" /etc/ssl/private/tsa233.key
    sudo chmod 600 /etc/ssl/private/tsa233.key

    sudo tee /etc/nginx/sites-available/tsa233-ssl > /dev/null <<'NGINX'
server {
    listen 443 ssl;
    server_name tsa233.lab;

    ssl_certificate     /etc/ssl/certs/tsa233.crt;
    ssl_certificate_key /etc/ssl/private/tsa233.key;
    ssl_protocols       TLSv1.2 TLSv1.3;

    root  /var/www/html;
    index index.html;
}

server {
    listen 80;
    server_name tsa233.lab;
    return 301 https://$host$request_uri;
}
NGINX

    sudo ln -sf /etc/nginx/sites-available/tsa233-ssl \
                /etc/nginx/sites-enabled/tsa233-ssl

    sudo nginx -t 2>/dev/null && sudo systemctl reload nginx
    ok "nginx налаштовано з TLS"

    echo ""
    info "Перевірка HTTPS-з'єднання:"
    openssl s_client -connect localhost:443 \
        -CAfile "$CA_DIR/ca.crt" \
        -brief 2>/dev/null | head -5 | sed 's/^/     /'

else
    info "nginx не встановлено — пропускаємо крок 6"
    info "Встановити: sudo apt install nginx"
fi

# ------------------------------------------------------------
header "ПІДСУМОК"
# ------------------------------------------------------------

echo ""
echo -e "  ${BOLD}Створена PKI-інфраструктура:${NC}"
echo ""
find "$PKI_DIR" -type f | sort | while read -r f; do
    size=$(wc -c < "$f")
    printf "  %-45s %5d байт\n" "${f/$HOME\//~/}" "$size"
done

echo ""
info "Щоб браузер довіряв нашому CA — імпортуйте:"
echo "     ${CA_DIR}/ca.crt"
echo "     (Firefox: Налаштування → Сертифікати → Імпортувати)"
echo ""
ok "PKI лабораторну роботу завершено!"
