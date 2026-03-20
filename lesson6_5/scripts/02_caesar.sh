#!/bin/bash
# =============================================================
#  02_caesar.sh — Шифр Цезаря: шифрування, розшифрування, злам
#  Лабораторна робота: PKI | ВІТІ
# =============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

header() { echo -e "\n${CYAN}══════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════${NC}"; }
ok()     { echo -e "${GREEN}  ✔ $1${NC}"; }
info()   { echo -e "${YELLOW}  ℹ $1${NC}"; }

# ------------------------------------------------------------
# Функція шифру Цезаря (python3 для підтримки Unicode-алфавіту)
# ------------------------------------------------------------
caesar() {
    local text="$1"
    local shift="$2"
    python3 - "$text" "$shift" <<'PYEOF'
import sys

text  = sys.argv[1].upper()
shift = int(sys.argv[2])
result = ""
for ch in text:
    if ch.isalpha():
        result += chr((ord(ch) - ord('A') + shift) % 26 + ord('A'))
    else:
        result += ch
print(result)
PYEOF
}

# ------------------------------------------------------------
header "ЧАСТИНА 1 — Як працює шифр Цезаря"
# ------------------------------------------------------------

echo ""
echo -e "  Алфавіт:   ${BOLD}A B C D E F G H I J K L M N O P Q R S T U V W X Y Z${NC}"
echo -e "  Зсув +3:   ${GREEN}D E F G H I J K L M N O P Q R S T U V W X Y Z A B C${NC}"
echo ""
info "Шифрування:   P→S  A→D  T→W  R→U  I→L  A→D"
info "Розшифрування: S→P  D→A  W→T  U→R  L→I  D→A"

# ------------------------------------------------------------
header "ЧАСТИНА 2 — Розшифрування завдання від викладача"
# ------------------------------------------------------------

ENCRYPTED="SDWULD HW KRQRU"
SHIFT=3

echo ""
info "Зашифрований текст: ${RED}${ENCRYPTED}${NC}"
info "Відомий зсув: ${SHIFT}"
echo ""

# Розшифрування = зсув на (-shift), тобто 26-shift
DECRYPTED=$(caesar "$ENCRYPTED" $(( 26 - SHIFT )))

echo -e "  Результат розшифрування:"
echo ""
echo -e "  ${BOLD}${GREEN}>>> ${DECRYPTED} <<<${NC}"
echo ""
ok "Фраза розшифрована успішно!"

# Показати покрокове розшифрування
echo ""
info "Покрокове розшифрування:"
python3 - "$ENCRYPTED" "$SHIFT" <<'PYEOF'
import sys
text  = sys.argv[1].upper()
shift = int(sys.argv[2])
print(f"  {'Зашиф.':<8} → {'Розшиф.':<8} (зсув -{shift})")
print(f"  {'─'*25}")
for ch in text:
    if ch.isalpha():
        dec = chr((ord(ch) - ord('A') - shift) % 26 + ord('A'))
        print(f"  {ch:<8} → {dec:<8}")
    elif ch == ' ':
        print(f"  {'(пробіл)':<8} → {'(пробіл)':<8}")
PYEOF

# ------------------------------------------------------------
header "ЧАСТИНА 3 — Спробуй сам"
# ------------------------------------------------------------

read -rp $'\n  Введіть текст для шифрування: ' USER_TEXT
read -rp "  Введіть зсув (1-25): " USER_SHIFT

if ! [[ "$USER_SHIFT" =~ ^[0-9]+$ ]] || (( USER_SHIFT < 1 || USER_SHIFT > 25 )); then
    echo "  Невірний зсув, використовую 3"
    USER_SHIFT=3
fi

ENCODED=$(caesar "$USER_TEXT" "$USER_SHIFT")
DECODED=$(caesar "$ENCODED" $(( 26 - USER_SHIFT )))

echo ""
info "Оригінал:     ${USER_TEXT^^}"
info "Зашифровано:  ${RED}${ENCODED}${NC}  (зсув +${USER_SHIFT})"
info "Розшифровано: ${GREEN}${DECODED}${NC}  (зсув -${USER_SHIFT})"

# ------------------------------------------------------------
header "ЧАСТИНА 4 — Злам брутфорсом (всі 25 варіантів)"
# ------------------------------------------------------------

echo ""
info "Ламаємо '${ENCRYPTED}' перебором усіх ключів..."
echo ""

for i in $(seq 1 25); do
    result=$(caesar "$ENCRYPTED" $(( 26 - i )))
    if [[ $i -eq $SHIFT ]]; then
        # Виділити правильний варіант
        echo -e "  Зсув ${i}:  ${GREEN}${BOLD}${result}  ← ось він!${NC}"
    else
        echo "  Зсув ${i}:  ${result}"
    fi
done

# ------------------------------------------------------------
header "ВИСНОВОК"
# ------------------------------------------------------------

echo ""
echo -e "  ${BOLD}Шифр Цезаря має лише 25 ключів.${NC}"
echo -e "  Комп'ютер перебрав усі варіанти за ${GREEN}мілісекунди${NC}."
echo ""
echo -e "  Для порівняння — AES-256 має ${RED}2^256 ≈ 10^77${NC} ключів."
echo -e "  Час злому AES-256 брутфорсом: ${RED}більше ніж вік Всесвіту${NC}."
echo ""
ok "Скрипт виконано. Перейдіть до розділу 1 методички."
