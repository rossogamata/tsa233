# 📧 Лабораторна робота: Базове налаштування поштового сервера

> **Курс:** Адміністрування мережевих служб  
> **Аудиторія:** Курсанти 3 курсу ВІТІ  
> **ОС:** Ubuntu 22.04 LTS (сервер), Windows 10/11 (клієнти)  
> **Час виконання:** ~90 хвилин  
> **Попередня вимога:** Виконана лабораторна робота з DNS (BIND9, зона `tsa233.lab`)

---

## 📋 Зміст

1. [Теоретична довідка](#теоретична-довідка)
2. [Топологія стенду](#топологія-стенду)
3. [Встановлення Postfix та Dovecot](#1-встановлення-postfix-та-dovecot)
4. [Налаштування Postfix (SMTP)](#2-налаштування-postfix-smtp)
5. [Налаштування Dovecot (IMAP/POP3)](#3-налаштування-dovecot-imappop3)
6. [Створення поштових скриньок](#4-створення-поштових-скриньок)
7. [Додавання MX-запису в DNS](#5-додавання-mx-запису-в-dns)
8. [Налаштування поштового клієнта](#6-налаштування-поштового-клієнта-thunderbird)
9. [Перевірка роботи](#7-перевірка-роботи)
10. [Завдання на самопідготовку](#завдання-на-самопідготовку)
11. [Корисні команди](#корисні-команди)

---

## Теоретична довідка

### Компоненти поштової системи

Відправлення та отримання пошти — це не одна програма, а ланцюжок із трьох типів агентів:

```
[Відправник]                                    [Отримувач]
    │                                                │
   MUA ──SMTP──► MTA ──SMTP──► MTA ──deliver──► MDA
(Thunderbird)  (Postfix)     (Postfix)       (Dovecot)
                                                  │
                                              ◄─IMAP/POP3─ MUA
                                                       (Thunderbird)
```

| Абревіатура | Повна назва | Програма | Функція |
|-------------|-------------|----------|---------|
| **MUA** | Mail User Agent | Thunderbird, Outlook | Поштовий клієнт користувача |
| **MTA** | Mail Transfer Agent | **Postfix** | Приймає та передає листи між серверами (SMTP) |
| **MDA** | Mail Delivery Agent | **Dovecot** | Зберігає листи, надає доступ клієнту (IMAP/POP3) |

### Протоколи

| Протокол | Порт | Призначення |
|----------|------|-------------|
| **SMTP** | 25 | Передача пошти між серверами |
| **SMTP Submission** | 587 | Відправка пошти від клієнта до сервера |
| **IMAP** | 143 | Читання пошти (листи зберігаються на сервері) |
| **POP3** | 110 | Завантаження пошти (листи видаляються з сервера) |

### Чому IMAP краще за POP3 у локальній мережі?

IMAP залишає листи на сервері — курсант може перевірити пошту з будь-якого ПК. POP3 завантажує і видаляє — лист буде лише на тому ПК, де перевіряли.

---

## Топологія стенду

```
┌──────────────────────────────────────────────────────────────┐
│                      Мережа: 192.168.1.0/24                   │
│                                                               │
│  ┌─────────────────────────────────────┐                     │
│  │          Ubuntu Server              │                     │
│  │  ┌─────────────┐  ┌──────────────┐ │                     │
│  │  │   Postfix   │  │   Dovecot    │ │                     │
│  │  │   (SMTP)    │  │ (IMAP/POP3)  │ │                     │
│  │  │   порт 25   │  │  порт 143    │ │                     │
│  │  │   порт 587  │  │  порт 110    │ │                     │
│  │  └─────────────┘  └──────────────┘ │                     │
│  │         192.168.1.10               │                     │
│  └─────────────────────────────────────┘                     │
│                                                               │
│  ┌──────────────────┐  ┌──────────────────┐                  │
│  │   Курсант #1     │  │   Курсант #2     │                  │
│  │   Thunderbird    │  │   Thunderbird    │                  │
│  │  user1@tsa233.lab│  │  user2@tsa233.lab│                  │
│  └──────────────────┘  └──────────────────┘                  │
└──────────────────────────────────────────────────────────────┘
```

### Адресний план:

| Пристрій | IP-адреса | Роль |
|----------|-----------|------|
| Роутер / шлюз | `192.168.1.1` | Вихід в інтернет |
| Ubuntu VM | `192.168.1.10` | Postfix + Dovecot |
| ПК курсантів | `192.168.1.101–120` | Поштові клієнти |

---

## 1. Встановлення Postfix та Dovecot

### 1.1 Оновити систему

```bash
sudo apt update && sudo apt upgrade -y
```

### 1.2 Встановити Postfix

Під час встановлення з'явиться діалог налаштування:

```bash
sudo apt install -y postfix
```

У діалозі вибрати:
- **General type of mail configuration:** `Internet Site`
- **System mail name:** `tsa233.lab`

> 💡 Якщо діалог не з'явився або потрібно переналаштувати:
> ```bash
> sudo dpkg-reconfigure postfix
> ```

### 1.3 Встановити Dovecot

```bash
sudo apt install -y dovecot-core dovecot-imapd dovecot-pop3d
```

### 1.4 Встановити допоміжні утиліти

```bash
sudo apt install -y mailutils
```

### 1.5 Перевірити статус служб

```bash
sudo systemctl status postfix
sudo systemctl status dovecot
```

---

## 2. Налаштування Postfix (SMTP)

Головний конфігураційний файл: `/etc/postfix/main.cf`

```bash
sudo nano /etc/postfix/main.cf
```

Знайти та встановити або додати наступні параметри:

```conf
# Ім'я хоста сервера
myhostname = mail.tsa233.lab

# Домен для пошти
mydomain = tsa233.lab

# Від імені якого домену відправляти листи
myorigin = $mydomain

# Мережеві інтерфейси для прийому пошти
inet_interfaces = all

# Протокол (лише IPv4)
inet_protocols = ipv4

# Для яких доменів приймати пошту
mydestination = $myhostname, $mydomain, localhost.$mydomain, localhost

# Довіряти листам із локальної мережі
mynetworks = 127.0.0.0/8, 192.168.1.0/24

# Де зберігати листи
home_mailbox = Maildir/

# Розмір поштової скриньки (50 МБ)
mailbox_size_limit = 52428800

# Максимальний розмір листа (10 МБ)
message_size_limit = 10240000

# Банер при підключенні (не розкривати версію ПЗ)
smtpd_banner = $myhostname ESMTP
```

### 2.1 Увімкнути порт 587 (Submission)

```bash
sudo nano /etc/postfix/master.cf
```

Знайти рядок із `submission` і розкоментувати (прибрати `#`):

```conf
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=may
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
```

### 2.2 Перезапустити Postfix

```bash
sudo systemctl restart postfix
sudo systemctl status postfix
```

---

## 3. Налаштування Dovecot (IMAP/POP3)

### 3.1 Головний конфіг

```bash
sudo nano /etc/dovecot/dovecot.conf
```

Переконатися що є рядок:

```conf
protocols = imap pop3
```

### 3.2 Налаштування автентифікації

```bash
sudo nano /etc/dovecot/conf.d/10-auth.conf
```

Знайти та змінити:

```conf
# Дозволити передачу пароля відкритим текстом (для лабораторії)
disable_plaintext_auth = no

# Механізми автентифікації
auth_mechanisms = plain login
```

### 3.3 Налаштування поштових скриньок

```bash
sudo nano /etc/dovecot/conf.d/10-mail.conf
```

Знайти та змінити:

```conf
# Формат зберігання — Maildir (одне повідомлення = один файл)
mail_location = maildir:~/Maildir
```

### 3.4 Налаштування прослуховування

```bash
sudo nano /etc/dovecot/conf.d/10-master.conf
```

Знайти секцію `inet_listener imap` та переконатися:

```conf
service imap-listener {
  inet_listener imap {
    port = 143
  }
}

service pop3-listener {
  inet_listener pop3 {
    port = 110
  }
}
```

### 3.5 Перезапустити Dovecot

```bash
sudo systemctl restart dovecot
sudo systemctl status dovecot
```

---

## 4. Створення поштових скриньок

Postfix + Dovecot з налаштуванням `maildir` використовують **системних користувачів Linux** як поштові скриньки. Кожен користувач = окрема адреса.

### 4.1 Створити користувачів

```bash
# Створити користувача user1
sudo useradd -m -s /bin/bash user1
sudo passwd user1

# Створити користувача user2
sudo useradd -m -s /bin/bash user2
sudo passwd user2
```

### 4.2 Створити структуру Maildir

```bash
# Для кожного користувача створити директорії
sudo -u user1 maildirmake.dovecot /home/user1/Maildir
sudo -u user2 maildirmake.dovecot /home/user2/Maildir

# Або через Postfix (автоматично при першому листі)
# Можна просто надіслати тестовий лист — Maildir створюється сам
```

### 4.3 Перевірити права

```bash
ls -la /home/user1/
# Директорія Maildir має належати user1:user1
```

---

## 5. Додавання MX-запису в DNS

Поштовий сервер знаходять через **MX-запис** у DNS. Без нього пошта не доставлятиметься.

### 5.1 Відредагувати файл зони

```bash
sudo nano /etc/bind/zones/db.tsa233.lab
```

Додати записи:

```dns
; MX-запис — вказує на поштовий сервер домену
@       IN  MX  10  mail.tsa233.lab.

; A-запис для поштового сервера
mail    IN  A   192.168.1.10
```

### 5.2 Оновити Serial у SOA

Збільшити число Serial на 1 (обов'язково при кожній зміні зони):

```dns
; Було:
2024010101  ; Serial

; Стало:
2024010102  ; Serial
```

### 5.3 Перевірити та перезапустити BIND

```bash
sudo named-checkzone tsa233.lab /etc/bind/zones/db.tsa233.lab
sudo systemctl reload bind9
```

### 5.4 Перевірити MX-запис

```bash
dig @localhost MX tsa233.lab
```

Очікуваний вивід:
```
tsa233.lab.   604800  IN  MX  10 mail.tsa233.lab.
```

---

## 6. Налаштування поштового клієнта (Thunderbird)

### 6.1 Встановити Thunderbird на Windows

Завантажити з: https://www.thunderbird.net

### 6.2 Додати обліковий запис

Запустити Thunderbird → **Отримати новий обліковий запис** → **Використати існуючу пошту**

Заповнити форму:

| Поле | Значення |
|------|----------|
| Ваше ім'я | `Курсант Іваненко` |
| Адреса | `user1@tsa233.lab` |
| Пароль | *(пароль user1 на сервері)* |

### 6.3 Налаштувати вручну

Натиснути **«Налаштувати вручну»** та заповнити:

**Вхідна пошта (IMAP):**

| Параметр | Значення |
|----------|----------|
| Сервер | `192.168.1.10` |
| Порт | `143` |
| Захист | `Немає` |
| Автентифікація | `Звичайний пароль` |
| Ім'я користувача | `user1` |

**Вихідна пошта (SMTP):**

| Параметр | Значення |
|----------|----------|
| Сервер | `192.168.1.10` |
| Порт | `587` |
| Захист | `Немає` |
| Автентифікація | `Звичайний пароль` |
| Ім'я користувача | `user1` |

> ⚠️ Thunderbird може попередити про незахищене з'єднання — для лабораторної мережі це нормально, підтвердити.

---

## 7. Перевірка роботи

### 7.1 Тест із командного рядка на сервері

```bash
# Надіслати тестовий лист від root до user1
echo "Тестовий лист із командного рядка" | mail -s "Тест SMTP" user1@tsa233.lab

# Перевірити чи лист дійшов
ls /home/user1/Maildir/new/
```

### 7.2 Ручний SMTP-діалог (telnet)

Це важлива навичка — розуміти як працює протокол SMTP:

```bash
telnet 192.168.1.10 25
```

```smtp
EHLO test.lab
MAIL FROM: <admin@tsa233.lab>
RCPT TO: <user1@tsa233.lab>
DATA
Subject: Ручний тест

Привіт, це лист надісланий вручну через SMTP!
.
QUIT
```

> 💡 Крапка `.` на окремому рядку — це сигнал кінця листа в SMTP.

### 7.3 Перевірка черги Postfix

```bash
# Переглянути чергу листів
sudo postqueue -p

# Примусово обробити чергу
sudo postqueue -f

# Переглянути логи
sudo tail -f /var/log/mail.log
```

### 7.4 Тест IMAP через telnet

```bash
telnet 192.168.1.10 143
```

```imap
a LOGIN user1 <пароль>
b SELECT INBOX
c FETCH 1 BODY[]
d LOGOUT
```

### 7.5 Надіслати лист між курсантами

На ПК курсанта #1 у Thunderbird:
- Написати лист на `user2@tsa233.lab`
- Натиснути **Надіслати**

На ПК курсанта #2:
- Натиснути **Отримати пошту** — лист має з'явитись у папці Вхідні

---

## Завдання на самопідготовку

> Виконати після заняття. Результати надати у вигляді скриншотів або конфігураційних файлів.

### Завдання 1 — Базове (обов'язкове)

1. Створити двох нових користувачів: `cadet1` та `cadet2`
2. Надіслати лист від `cadet1@tsa233.lab` до `cadet2@tsa233.lab`
3. Переконатись що лист отримано через Thunderbird
4. Переглянути рядки логу `/var/log/mail.log` що відповідають доставці

---

### Завдання 2 — Середнє

Налаштувати **псевдоніми (aliases)** — щоб листи на одну адресу отримували кілька людей:

```bash
sudo nano /etc/aliases
```

```conf
# Додати:
squad: user1, user2, cadet1
```

```bash
sudo newaliases
```

Перевірити: надіслати лист на `squad@tsa233.lab` — мають отримати всі троє.

---

### Завдання 3 — Підвищеної складності

Налаштувати **Postfix + Dovecot SASL-автентифікацію** — щоб клієнти могли відправляти пошту лише після авторизації:

1. Встановити `libsasl2-modules`
2. Налаштувати `smtpd_sasl_*` параметри в `main.cf`
3. Пов'язати Postfix із Dovecot через Unix-сокет
4. Перевірити що неавторизований SMTP на порту 587 відхиляється

---

### Питання для самоконтролю

1. Яка різниця між MTA і MDA? Яку роль виконує Postfix, а яку — Dovecot?
2. Чому для поштового сервера обов'язково потрібен MX-запис у DNS?
3. Яка різниця між протоколами IMAP та POP3? Коли доцільно використовувати кожен?
4. Що означає команда `DATA` та крапка `.` у SMTP-діалозі?
5. Для чого потрібен параметр `mynetworks` у Postfix і чим небезпечно вказати там `0.0.0.0/0`?

---

## Корисні команди

### Управління службами

```bash
sudo systemctl restart postfix      # Перезапустити Postfix
sudo systemctl restart dovecot      # Перезапустити Dovecot
sudo systemctl status postfix       # Статус Postfix
sudo systemctl status dovecot       # Статус Dovecot
```

### Діагностика Postfix

```bash
sudo postfix check                  # Перевірити конфігурацію
sudo postconf -n                    # Показати лише змінені параметри
sudo postqueue -p                   # Черга листів
sudo tail -f /var/log/mail.log      # Лог у реальному часі
sudo tail -f /var/log/mail.err      # Лог помилок
```

### Діагностика Dovecot

```bash
sudo doveconf -n                    # Показати лише змінені параметри
sudo doveadm user '*'               # Список всіх поштових скриньок
sudo doveadm mailbox list -u user1  # Папки скриньки user1
sudo doveadm log find               # Де знаходяться логи
```

### Файли конфігурації

| Файл | Призначення |
|------|-------------|
| `/etc/postfix/main.cf` | Головний конфіг Postfix |
| `/etc/postfix/master.cf` | Конфіг служб Postfix (порти, демони) |
| `/etc/aliases` | Псевдоніми адрес |
| `/etc/dovecot/dovecot.conf` | Головний конфіг Dovecot |
| `/etc/dovecot/conf.d/10-auth.conf` | Автентифікація |
| `/etc/dovecot/conf.d/10-mail.conf` | Формат зберігання пошти |
| `/var/log/mail.log` | Головний лог пошти |
| `~/Maildir/` | Папка пошти користувача |

---

## Структура проєкту на GitHub

```
lesson7_3/
├── README.md                          # Ця методичка
└── configs/
    ├── main.cf                        # Конфіг Postfix
    ├── master.cf                      # Служби Postfix
    ├── dovecot.conf                   # Головний конфіг Dovecot
    ├── 10-auth.conf                   # Автентифікація Dovecot
    └── 10-mail.conf                   # Зберігання пошти Dovecot
```

---

## Автор

> Матеріал підготовлено для навчальних занять ВІТІ.  
> При використанні — посилання вітається.

---

*Версія: 1.0 | Дата: 2026*
