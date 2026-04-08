#!/bin/bash
# =============================================================
#  02_install_ca_linux.sh — Встановлення CA сертифіката в Linux
#  Практичне заняття 6: Робота з цифровими сертифікатами
#  Курс: ТСА-233 | ВІТІ
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
step()   { echo -e "\n${BOLD}  ▶ $1${NC}"; }

CA_CRT="$HOME/certs-lab/ca/ca.crt"
SRV_CRT="$HOME/certs-lab/server/server.crt"

[ -f "$CA_CRT" ] || err "CA сертифікат не знайдено: $CA_CRT\nСпочатку запустіть: ./01_create_cert.sh"

# =============================================================
header "МЕТОД 1 — Системне сховище (update-ca-certificates)"
# =============================================================

step "Перевірка поточного стану (до встановлення)"
info "Перевірка ланцюга довіри ДО встановлення CA:"
if openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt "$SRV_CRT" 2>/dev/null | grep -q "OK"; then
    info "Сертифікат вже довіряється системою"
else
    info "Сертифікат поки НЕ довіряється системою (очікувано)"
fi

step "Копіювання CA у системну директорію"
sudo cp "$CA_CRT" /usr/local/share/ca-certificates/viit-root-ca.crt
ok "Скопійовано → /usr/local/share/ca-certificates/viit-root-ca.crt"

step "Оновлення системного сховища"
RESULT=$(sudo update-ca-certificates 2>&1)
echo "$RESULT" | sed 's/^/    /'
ok "Системне сховище оновлено"

step "Перевірка після встановлення"
VERIFY=$(openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt "$SRV_CRT" 2>&1)
if echo "$VERIFY" | grep -q "OK"; then
    ok "Ланцюг довіри підтверджено: $SRV_CRT: OK"
else
    err "Верифікація не пройшла: $VERIFY"
fi

info "CA у системному сховищі:"
ls /etc/ssl/certs/ | grep -i viit | sed 's/^/    /'

# =============================================================
header "МЕТОД 2 — Firefox (NSS сховище)"
# =============================================================

if command -v certutil &>/dev/null; then
    FIREFOX_PROFILE=$(find "$HOME/.mozilla/firefox" -name "*.default*" -type d 2>/dev/null | head -1)

    if [ -n "$FIREFOX_PROFILE" ]; then
        step "Встановлення CA у Firefox профіль"
        info "Профіль: $FIREFOX_PROFILE"

        certutil -d "sql:$FIREFOX_PROFILE" \
                 -A -n "VIIT Root CA" \
                 -t "CT,," \
                 -i "$CA_CRT" 2>/dev/null && \
        ok "CA встановлено у Firefox" || \
        info "Firefox може бути запущений — закрийте і спробуйте ще раз"

        info "Список CA у Firefox:"
        certutil -d "sql:$FIREFOX_PROFILE" -L 2>/dev/null | grep -i viit | sed 's/^/    /' || true
    else
        info "Firefox профіль не знайдено (Firefox не встановлено або не запускався)"
    fi
else
    info "certutil не встановлено. Для Firefox/Chrome підтримки:"
    echo "    sudo apt install libnss3-tools"
fi

# =============================================================
header "МЕТОД 3 — Chrome/Chromium (NSS сховище)"
# =============================================================

if command -v certutil &>/dev/null; then
    NSS_DIR="$HOME/.pki/nssdb"

    if [ -d "$NSS_DIR" ]; then
        step "Встановлення CA у Chrome NSS сховище"
        certutil -d "sql:$NSS_DIR" \
                 -A -n "VIIT Root CA" \
                 -t "CT,," \
                 -i "$CA_CRT" 2>/dev/null && \
        ok "CA встановлено у Chrome/Chromium" || \
        info "Не вдалось встановити у Chrome NSS"
    else
        info "Chrome NSS сховище не знайдено ($NSS_DIR)"
        info "Щоб створити: mkdir -p $NSS_DIR && certutil -d sql:$NSS_DIR -N --empty-password"
    fi
fi

# =============================================================
header "ПЕРЕВІРКА — curl без прапорців"
# =============================================================

step "Перевірка curl (використовує системне сховище)"
info "Встановлення тестового запису в /etc/hosts..."

# Перевірити чи вже є запис
if ! grep -q "tsa233.lab" /etc/hosts 2>/dev/null; then
    echo "127.0.0.1 tsa233.lab" | sudo tee -a /etc/hosts > /dev/null
    ok "Додано: 127.0.0.1 tsa233.lab → /etc/hosts"
else
    info "Запис tsa233.lab вже є в /etc/hosts"
fi

info "Якщо nginx налаштований, перевірте:"
echo "    curl -sv https://tsa233.lab 2>&1 | grep -E 'SSL|TLS|issuer|subject|HTTP'"

# =============================================================
header "ВИДАЛЕННЯ CA (якщо потрібно)"
# =============================================================

echo ""
info "Для видалення CA з системи:"
echo "    sudo rm /usr/local/share/ca-certificates/viit-root-ca.crt"
echo "    sudo update-ca-certificates --fresh"
echo ""
info "Для видалення з Firefox:"
echo "    certutil -d sql:\$HOME/.mozilla/firefox/*.default* -D -n 'VIIT Root CA'"
echo ""
ok "Скрипт завершено успішно"
