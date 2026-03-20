#!/bin/bash
# =============================================================
#  03_rsa_demo.sh — RSA: генерація ключів, шифрування, підпис
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

# Перевірити наявність openssl
command -v openssl &>/dev/null || err "openssl не встановлено: sudo apt install openssl"

WORKDIR="$HOME/rsa_demo"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ------------------------------------------------------------
header "КРОК 1 — Генерація RSA-ключів (2048 біт)"
# ------------------------------------------------------------

info "Генерація приватного ключа..."
openssl genrsa -out private.pem 2048 2>/dev/null
ok "Приватний ключ: $WORKDIR/private.pem"

info "Витягнення публічного ключа..."
openssl rsa -in private.pem -pubout -out public.pem 2>/dev/null
ok "Публічний ключ: $WORKDIR/public.pem"

echo ""
info "Розміри ключів:"
ls -lh private.pem public.pem | awk '{printf "     %-20s %s\n", $9, $5}'

echo ""
info "Початок публічного ключа:"
head -3 public.pem

echo ""
info "Структура приватного ключа (перші поля):"
openssl rsa -in private.pem -text -noout 2>/dev/null | head -10

# ------------------------------------------------------------
header "КРОК 2 — Шифрування публічним ключем"
# ------------------------------------------------------------

echo "Секретне повідомлення від курсанта $(whoami)" > message.txt
info "Оригінальний файл:"
cat message.txt

echo ""
info "Шифрування публічним ключем..."
openssl pkeyutl -encrypt \
    -inkey public.pem -pubin \
    -in  message.txt \
    -out message.enc

ok "Файл зашифровано → message.enc"
echo ""
info "Зашифровані дані (hex, перші 4 рядки):"
xxd message.enc | head -4

# ------------------------------------------------------------
header "КРОК 3 — Розшифрування приватним ключем"
# ------------------------------------------------------------

info "Розшифрування приватним ключем..."
openssl pkeyutl -decrypt \
    -inkey private.pem \
    -in  message.enc \
    -out message_dec.txt

ok "Файл розшифровано → message_dec.txt"
echo ""
info "Розшифрований вміст:"
cat message_dec.txt

# Перевірити що файли ідентичні
if diff -q message.txt message_dec.txt &>/dev/null; then
    ok "Оригінал і розшифрований файл — ідентичні ✓"
else
    err "Файли відрізняються!"
fi

# ------------------------------------------------------------
header "КРОК 4 — Цифровий підпис"
# ------------------------------------------------------------

cat > order.txt <<EOF
НАКАЗ №$(date +%Y%m%d)-01
Виконати лабораторну роботу з PKI.
Відповідальний: $(whoami)
Дата: $(date '+%d.%m.%Y %H:%M:%S')
EOF

info "Документ для підпису:"
cat order.txt

echo ""
info "Підписання приватним ключем (SHA-256)..."
openssl dgst -sha256 \
    -sign   private.pem \
    -out    order.sig \
    order.txt

ok "Підпис створено → order.sig"
info "Розмір підпису: $(wc -c < order.sig) байт"

# ------------------------------------------------------------
header "КРОК 5 — Перевірка підпису"
# ------------------------------------------------------------

echo ""
info "Перевірка оригінального документа..."
openssl dgst -sha256 \
    -verify  public.pem \
    -signature order.sig \
    order.txt \
    && ok "ПІДПИС ДІЙСНИЙ — документ не змінено" \
    || err "Підпис недійсний!"

# Підробка документа
cp order.txt order_fake.txt
echo "Підроблений рядок — змінено наказ" >> order_fake.txt

echo ""
info "Перевірка підробленого документа..."
if openssl dgst -sha256 \
    -verify  public.pem \
    -signature order.sig \
    order_fake.txt 2>/dev/null; then
    err "Увага: підпис прийнятий для підробки!"
else
    ok "ПІДПИС НЕ ДІЙСНИЙ — підробку виявлено ✓"
fi

# ------------------------------------------------------------
header "КРОК 6 — Хешування та цілісність"
# ------------------------------------------------------------

info "Хеші одного файлу різними алгоритмами:"
echo ""
printf "  %-10s %s\n" "MD5:"    "$(openssl dgst -md5    order.txt | awk '{print $2}')"
printf "  %-10s %s\n" "SHA-1:"  "$(openssl dgst -sha1   order.txt | awk '{print $2}')"
printf "  %-10s %s\n" "SHA-256:""$(openssl dgst -sha256 order.txt | awk '{print $2}')"
printf "  %-10s %s\n" "SHA-512:""$(openssl dgst -sha512 order.txt | awk '{print $2}')"

echo ""
info "Зміна 1 символу → повністю інший хеш (лавинний ефект):"
HASH1=$(echo "Hello" | openssl dgst -sha256 | awk '{print $2}')
HASH2=$(echo "hello" | openssl dgst -sha256 | awk '{print $2}')
printf "  %-10s %s\n" "'Hello':" "$HASH1"
printf "  %-10s %s\n" "'hello':" "$HASH2"

# ------------------------------------------------------------
header "ПІДСУМОК"
# ------------------------------------------------------------

echo ""
echo -e "  Файли створено в: ${BOLD}$WORKDIR/${NC}"
ls -lh "$WORKDIR"/ | awk 'NR>1 {printf "     %-25s %s\n", $9, $5}'
echo ""
ok "Демонстрацію RSA завершено."
echo ""
info "Наступний крок: запустіть 04_create_ca.sh"
