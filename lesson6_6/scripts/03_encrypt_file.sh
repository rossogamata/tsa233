#!/bin/bash
# =============================================================
#  03_encrypt_file.sh — Шифрування та розшифрування файлів
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

command -v openssl &>/dev/null || err "OpenSSL не встановлено: sudo apt install openssl"

WORK_DIR="$HOME/encrypt-lab"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# =============================================================
header "ЧАСТИНА 1 — Асиметричне шифрування (RSA)"
# =============================================================

step "Генерація пари RSA-ключів (2048 біт)"
openssl genrsa -out private.pem 2048 2>/dev/null
openssl rsa -in private.pem -pubout -out public.pem 2>/dev/null
ok "Приватний ключ: private.pem"
ok "Публічний ключ: public.pem"

echo ""
info "Розміри ключів:"
ls -lh private.pem public.pem | awk '{printf "    %-15s %s\n", $9, $5}'

# ------------------------------------------------------------
step "Створення файлу з текстом"
echo "Секретне повідомлення від $(whoami), $(date '+%d.%m.%Y %H:%M:%S')" > message.txt
info "Вміст message.txt:"
cat message.txt | sed 's/^/    /'

# ------------------------------------------------------------
step "Шифрування публічним ключем → message.enc"
openssl pkeyutl -encrypt \
    -inkey public.pem -pubin \
    -in  message.txt \
    -out message.enc
ok "message.enc створено ($(wc -c < message.enc) байт)"

echo ""
info "Hex-дамп зашифрованого файлу (перші 3 рядки):"
xxd message.enc | head -3 | sed 's/^/    /'
echo "    ..."

# ------------------------------------------------------------
step "Розшифрування приватним ключем → message_dec.txt"
openssl pkeyutl -decrypt \
    -inkey private.pem \
    -in  message.enc \
    -out message_dec.txt
ok "message_dec.txt відновлено"

echo ""
info "Вміст розшифрованого файлу:"
cat message_dec.txt | sed 's/^/    /'

# Порівняти файли
if diff -q message.txt message_dec.txt &>/dev/null; then
    ok "Оригінал і розшифрований файл — ідентичні ✓"
else
    err "Файли відрізняються — щось пішло не так!"
fi

# =============================================================
header "ЧАСТИНА 2 — Симетричне шифрування (AES-256)"
# =============================================================

step "Створення файлу з секретними даними"
cat > secret.txt << EOF
СЕКРЕТНІ ДАНІ ПІДРОЗДІЛУ
Позивний: Альфа-$(echo $RANDOM | head -c3)
Дата: $(date '+%d.%m.%Y')
Виконавець: $(whoami)
EOF

info "Вміст secret.txt:"
cat secret.txt | sed 's/^/    /'

# ------------------------------------------------------------
step "Шифрування AES-256-CBC (без пароля, автогенерація)"
# Використовуємо фіксований пароль для демонстрації (без інтерактивного вводу)
AES_PASS="demo_password_$(date +%s)"

openssl enc -aes-256-cbc -pbkdf2 \
    -in  secret.txt \
    -out secret.enc \
    -pass "pass:$AES_PASS"
ok "secret.enc створено"

echo ""
info "Hex-дамп зашифрованого файлу:"
xxd secret.enc | head -3 | sed 's/^/    /'

echo ""
info "Розміри файлів:"
ls -lh secret.txt secret.enc | awk '{printf "    %-15s %s\n", $9, $5}'

# ------------------------------------------------------------
step "Розшифрування AES → secret_dec.txt"
openssl enc -d -aes-256-cbc -pbkdf2 \
    -in  secret.enc \
    -out secret_dec.txt \
    -pass "pass:$AES_PASS"
ok "secret_dec.txt відновлено"

echo ""
info "Вміст розшифрованого файлу:"
cat secret_dec.txt | sed 's/^/    /'

if diff -q secret.txt secret_dec.txt &>/dev/null; then
    ok "Оригінал і розшифрований файл — ідентичні ✓"
else
    err "Файли відрізняються!"
fi

# =============================================================
header "ЧАСТИНА 3 — Гібридне шифрування (AES + RSA)"
# =============================================================

info "Мета: зашифрувати великий файл (RSA не впорається з > ~245 байт)"

step "Створення великого файлу"
dd if=/dev/urandom bs=1K count=10 2>/dev/null | base64 > bigfile.txt
echo "Розмір: $(wc -c < bigfile.txt) байт" | sed 's/^/    /'

# --- Шифрування ---
step "Генерація випадкового AES-ключа"
openssl rand -hex 32 > aes.key
info "AES-ключ (256 біт, hex):"
cat aes.key | sed 's/^/    /'

step "Шифрування файлу AES-ключем"
openssl enc -aes-256-cbc -pbkdf2 \
    -in  bigfile.txt \
    -out bigfile.enc \
    -pass file:aes.key
ok "bigfile.enc створено ($(wc -c < bigfile.enc) байт)"

step "Шифрування AES-ключа публічним RSA-ключем"
openssl pkeyutl -encrypt \
    -inkey public.pem -pubin \
    -in  aes.key \
    -out aes.key.enc
ok "aes.key.enc створено ($(wc -c < aes.key.enc) байт)"

# Видалити відкритий AES-ключ — передаємо тільки зашифровану версію
rm aes.key
info "aes.key видалено (передаємо тільки зашифрований aes.key.enc)"

echo ""
info "Що передається отримувачу:"
echo "    bigfile.enc   ← зашифрований файл (AES)"
echo "    aes.key.enc   ← зашифрований ключ (RSA)"

# --- Розшифрування ---
step "Розшифрування AES-ключа приватним RSA-ключем"
openssl pkeyutl -decrypt \
    -inkey private.pem \
    -in  aes.key.enc \
    -out aes.key
ok "AES-ключ відновлено"

step "Розшифрування файлу відновленим AES-ключем"
openssl enc -d -aes-256-cbc -pbkdf2 \
    -in  bigfile.enc \
    -out bigfile_dec.txt \
    -pass file:aes.key
ok "bigfile_dec.txt відновлено"

if diff -q bigfile.txt bigfile_dec.txt &>/dev/null; then
    ok "Великий файл розшифровано коректно ✓"
else
    err "Файли відрізняються!"
fi

# =============================================================
header "ПІДСУМОК"
# =============================================================

echo ""
echo -e "${BOLD}  Файли у $WORK_DIR/:${NC}"
ls -lh "$WORK_DIR"/ | awk 'NR>1 {printf "    %-25s %s\n", $9, $5}'

echo ""
echo -e "${BOLD}  Порівняння методів:${NC}"
printf "    %-30s %-15s %-20s\n" "Метод" "Розмір ключа" "Обмеження"
printf "    %-30s %-15s %-20s\n" "─────" "────────────" "──────────"
printf "    %-30s %-15s %-20s\n" "RSA (асиметричний)" "2048 біт" "< 245 байт"
printf "    %-30s %-15s %-20s\n" "AES-256 (симетричний)" "256 біт" "необмежено"
printf "    %-30s %-15s %-20s\n" "Гібридний (AES + RSA)" "2048 + 256 біт" "необмежено"
echo ""
ok "Завдання виконано."
