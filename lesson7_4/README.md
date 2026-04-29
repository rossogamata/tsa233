# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 4 (Групове) — Основи налаштування веб-сервера Apache

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Групове  
> **Середовище:** Proxmox VE · підмережа курсанта `192.168.100.0/24`

---

## Навчальні питання

1. [Типи серверів](#1-типи-серверів)
2. [Огляд веб-сервера Apache та його конфігураційних файлів](#2-огляд-apache-та-конфігураційних-файлів)
3. [Налаштування віртуальних хостів в Apache](#3-налаштування-віртуальних-хостів)
4. [Налаштування субдомену](#4-налаштування-субдомену)

---

## 1. Типи серверів

**Сервер** — програмне або апаратне забезпечення, що надає сервіси клієнтам за моделлю клієнт-сервер.

### Класифікація за призначенням

| Тип сервера | Призначення | Приклади ПЗ |
|-------------|-------------|-------------|
| **Веб-сервер** | Обслуговує HTTP/HTTPS запити, роздає статичний контент | Apache, Nginx, IIS |
| **Сервер застосунків** | Виконує бізнес-логіку, динамічний контент | Tomcat, Gunicorn, uWSGI |
| **Файловий сервер** | Спільний доступ до файлів у мережі | Samba, NFS, FTP |
| **Поштовий сервер** | Приймання та відправлення електронної пошти | Postfix, Dovecot, Exim |
| **DNS-сервер** | Перетворення доменних імен на IP-адреси | BIND9, Unbound |
| **Проксі-сервер** | Посередник між клієнтом і сервером, кешування | Nginx, Squid, HAProxy |
| **Сервер баз даних** | Зберігання та обробка структурованих даних | PostgreSQL, MySQL, SQLite |

### Веб-сервер vs Сервер застосунків

```
Клієнт (браузер)
      │
      ▼ HTTP запит
 Веб-сервер (Apache/Nginx)
      │
      ├── Статичний файл (HTML, CSS, JS, зображення)?
      │   └── Відповідь одразу ──────────────────────► Клієнт
      │
      └── Динамічний запит (PHP, Python...)?
          └──► Сервер застосунків (PHP-FPM, Gunicorn)
                    └── Відповідь ──► Веб-сервер ──► Клієнт
```

> Apache може бути одночасно веб-сервером і сервером застосунків — через модулі
> `mod_php`, `mod_wsgi`. Nginx — виключно веб-сервер та проксі.

---

## 2. Огляд Apache та конфігураційних файлів

**Apache HTTP Server (httpd)** — найпоширеніший веб-сервер у світі з 1996 року.
Модульна архітектура дозволяє вмикати та вимикати функціональність без перекомпіляції.

### Архітектура Apache

```
                    ┌──────────────────────────────┐
                    │          Apache httpd         │
                    │                              │
  HTTP запит ──────►│  MPM (Multi-Processing Module)│
                    │  ┌──────────┐ ┌────────────┐ │
                    │  │ prefork  │ │   worker   │ │
                    │  │(процеси) │ │ (потоки)   │ │
                    │  └──────────┘ └────────────┘ │
                    │                              │
                    │  Модулі: mod_rewrite,        │
                    │  mod_ssl, mod_proxy,         │
                    │  mod_php, mod_headers...     │
                    └──────────────────────────────┘
```

### Структура конфігураційних файлів

```
/etc/apache2/
├── apache2.conf            ← головний конфіг (глобальні параметри)
├── ports.conf              ← порти прослуховування (Listen 80, Listen 443)
├── envvars                 ← змінні середовища (APACHE_RUN_USER тощо)
│
├── mods-available/         ← всі доступні модулі
│   ├── rewrite.load
│   ├── ssl.load
│   └── ...
├── mods-enabled/           ← символічні посилання на увімкнені модулі
│   └── rewrite.load -> ../mods-available/rewrite.load
│
├── sites-available/        ← всі описані віртуальні хости
│   ├── 000-default.conf    ← дефолтний vhost (port 80)
│   └── default-ssl.conf    ← дефолтний vhost (port 443)
├── sites-enabled/          ← символічні посилання на активні vhost
│   └── 000-default.conf -> ../sites-available/000-default.conf
│
└── conf-available/         ← додаткові конфіги
    └── conf-enabled/
```

> Принцип `*-available` / `*-enabled` — конфіг є, але не активний доки немає
> символічного посилання у `*-enabled`. Утиліти `a2ensite`, `a2dissite`,
> `a2enmod`, `a2dismod` керують цими посиланнями автоматично.

### Ключові директиви apache2.conf

| Директива | Призначення | Приклад |
|-----------|-------------|---------|
| `ServerName` | Ім'я сервера за замовчуванням | `ServerName tsa233.lab` |
| `ServerAdmin` | Email адміністратора | `ServerAdmin admin@tsa233.lab` |
| `DocumentRoot` | Директорія з файлами сайту | `DocumentRoot /var/www/html` |
| `ErrorLog` | Файл журналу помилок | `ErrorLog ${APACHE_LOG_DIR}/error.log` |
| `CustomLog` | Файл журналу доступу | `CustomLog ... combined` |
| `Directory` | Налаштування для директорії | `<Directory /var/www/html>` |
| `AllowOverride` | Чи дозволено `.htaccess` | `AllowOverride All` |

---

## 3. Налаштування віртуальних хостів

**Virtual Host (vhost)** — механізм, що дозволяє одному Apache-серверу обслуговувати
кілька доменів з одної IP-адреси. Сервер розрізняє сайти за заголовком `Host:` у HTTP-запиті.

### Топологія заняття

```
┌──────────────────────────────────────────────────────┐
│           Середовище курсанта  192.168.100.0/24       │
│                                                      │
│   192.168.100.20  ← Workstation (Apache httpd)       │
│                      surname.tsa233.lab     → /var/www/main
│                      dev.surname.tsa233.lab → /var/www/dev
│                                                      │
│   192.168.100.10  ← DNS курсанта (BIND9)             │
│                      A-записи для обох доменів       │
└──────────────────────────────────────────────────────┘
```

---

### Крок 1 — Встановлення Apache

```bash
sudo apt update
sudo apt install apache2 -y

# Перевірити статус
sudo systemctl status apache2

# Переконатись що відповідає
curl http://localhost
```

Відкрити у браузері: `http://192.168.100.20` — має з'явитись сторінка "Apache2 Ubuntu Default Page".

---

### Крок 2 — Огляд конфігурації

```bash
# Переглянути головний конфіг
cat /etc/apache2/apache2.conf

# Які модулі увімкнено
ls /etc/apache2/mods-enabled/

# Які порти прослуховуються
cat /etc/apache2/ports.conf

# Дефолтний vhost
cat /etc/apache2/sites-available/000-default.conf

# Де зберігаються логи
ls /var/log/apache2/
tail -20 /var/log/apache2/access.log
tail -20 /var/log/apache2/error.log
```

---

### Крок 3 — Перший віртуальний хост: `surname.tsa233.lab`

#### 3.1 Створити директорію і тестову сторінку

```bash
# Замінити surname на своє прізвище
sudo mkdir -p /var/www/main
sudo chown -R $USER:$USER /var/www/main

cat <<EOF | sudo tee /var/www/main/index.html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>surname.tsa233.lab</title></head>
<body>
  <h1>surname.tsa233.lab</h1>
  <p>Основний сайт курсанта. Apache Virtual Host.</p>
  <p>Сервер: <strong>192.168.100.20</strong></p>
</body>
</html>
EOF
```

#### 3.2 Створити конфіг віртуального хосту

```bash
sudo nano /etc/apache2/sites-available/surname.tsa233.lab.conf
```

```apacheconf
<VirtualHost *:80>
    ServerName   surname.tsa233.lab
    ServerAlias  www.surname.tsa233.lab
    ServerAdmin  surname@tsa233.lab

    DocumentRoot /var/www/main

    <Directory /var/www/main>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog  ${APACHE_LOG_DIR}/surname-error.log
    CustomLog ${APACHE_LOG_DIR}/surname-access.log combined
</VirtualHost>
```

#### 3.3 Увімкнути сайт

```bash
sudo a2ensite surname.tsa233.lab.conf
sudo apache2ctl configtest          # має вивести: Syntax OK
sudo systemctl reload apache2
```

---

### Крок 4 — Перевірка основного хосту

```bash
# Перевірка без DNS через заголовок Host
curl -H "Host: surname.tsa233.lab" http://192.168.100.20

# Список активних vhost
sudo apache2ctl -S

# Журнал в реальному часі
sudo tail -f /var/log/apache2/surname-access.log
```

---

## 4. Налаштування субдомену

### Концепція: зона vs субдомен

У вас є файл зони `tsa233.lab`. **Створювати окремий файл зони для `surname.tsa233.lab` не потрібно.**

`surname.tsa233.lab` — це просто **A-запис усередині вже існуючої зони** `tsa233.lab`.
Так само `dev.surname.tsa233.lab` — ще один A-запис у тій самій зоні.

```
Зона: tsa233.lab  (/etc/bind/db.tsa233.lab)
│
├── @                   IN A  192.168.100.10   ← сам DNS-сервер
├── surname             IN A  192.168.100.20   ← surname.tsa233.lab
└── dev.surname         IN A  192.168.100.20   ← dev.surname.tsa233.lab
```

> Новий файл зони потрібен лише якщо ви **делегуєте** `surname.tsa233.lab`
> на інший DNS-сервер (NS-делегування). У цьому занятті цього не робимо.

З точки зору Apache кожен домен — **окремий віртуальний хост** з власним
`DocumentRoot`. Сервер розрізняє їх за заголовком `Host:` у HTTP-запиті,
тому обидва можуть слухати на одній IP та порту 80.

```
surname.tsa233.lab          → 192.168.100.20  (основний vhost)
dev.surname.tsa233.lab      → 192.168.100.20  (той самий сервер, інший vhost)
```

---

### Крок 5 — Директорія та сторінка субдомену

```bash
sudo mkdir -p /var/www/dev
sudo chown -R $USER:$USER /var/www/dev

cat <<EOF | sudo tee /var/www/dev/index.html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>DEV — surname.tsa233.lab</title></head>
<body style="background:#1a1a2e; color:#eee; font-family:monospace; padding:2rem">
  <h1>dev.surname.tsa233.lab</h1>
  <p>Тестове середовище. Не для production.</p>
  <p>Сервер: <strong>192.168.100.20</strong></p>
</body>
</html>
EOF
```

Перевірити що файл створено:

```bash
cat /var/www/dev/index.html
```

---

### Крок 6 — Конфіг віртуального хосту субдомену

```bash
sudo nano /etc/apache2/sites-available/dev.surname.tsa233.lab.conf
```

```apacheconf
<VirtualHost *:80>
    ServerName  dev.surname.tsa233.lab
    ServerAdmin surname@tsa233.lab

    DocumentRoot /var/www/dev

    <Directory /var/www/dev>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog  ${APACHE_LOG_DIR}/dev-surname-error.log
    CustomLog ${APACHE_LOG_DIR}/dev-surname-access.log combined
</VirtualHost>
```

---

### Крок 7 — Увімкнути конфіг субдомену

```bash
# Активувати vhost
sudo a2ensite dev.surname.tsa233.lab.conf

# Перевірити синтаксис усіх конфігів
sudo apache2ctl configtest

# Перезавантажити Apache (без зупинки сервісу)
sudo systemctl reload apache2

# Переконатись що обидва vhost активні
sudo apache2ctl -S
```

Очікуваний вивід `apache2ctl -S`:

```
VirtualHost configuration:
*:80   surname.tsa233.lab (/etc/apache2/sites-enabled/surname.tsa233.lab.conf)
*:80   dev.surname.tsa233.lab (/etc/apache2/sites-enabled/dev.surname.tsa233.lab.conf)
```

---

### Крок 8 — Додати DNS-записи у зону `tsa233.lab`

Підключитись до DNS-сервера (`192.168.100.10`) та відкрити **існуючий** файл зони:

```bash
sudo nano /etc/bind/db.tsa233.lab
```

Файл зони виглядає приблизно так (скорочено):

```bind
$ORIGIN tsa233.lab.
$TTL 300

@   IN  SOA ns1.tsa233.lab. admin.tsa233.lab. (
        2024042901  ; Serial
        3600        ; Refresh
        900         ; Retry
        604800      ; Expire
        300 )       ; Negative TTL

    IN  NS  ns1.tsa233.lab.

ns1 IN  A   192.168.100.10
```

Необхідно **збільшити Serial на 1** і додати два нові рядки — один для основного домену курсанта,
другий для субдомену:

```bind
$ORIGIN tsa233.lab.
$TTL 300

@   IN  SOA ns1.tsa233.lab. admin.tsa233.lab. (
        2024042902  ; Serial ← збільшити на 1
        3600        ; Refresh
        900         ; Retry
        604800      ; Expire
        300 )       ; Negative TTL

    IN  NS  ns1.tsa233.lab.

ns1         IN  A   192.168.100.10

; Домен курсанта — замінити surname на своє прізвище
surname     IN  A   192.168.100.20
dev.surname IN  A   192.168.100.20
```

> Імена `surname` та `dev.surname` — відносні (без крапки в кінці).
> BIND автоматично додає суфікс `tsa233.lab.`, тому:
> - `surname` → `surname.tsa233.lab.`
> - `dev.surname` → `dev.surname.tsa233.lab.`

Перевірити синтаксис та перезавантажити зону:

```bash
# Перевірка файлу зони (зона — tsa233.lab, не surname.tsa233.lab!)
sudo named-checkzone tsa233.lab /etc/bind/db.tsa233.lab

# Перезавантажити тільки цю зону (без зупинки BIND)
sudo rndc reload tsa233.lab

# Або перезавантажити весь BIND
sudo systemctl reload bind9
```

---

### Крок 9 — Перевірка резолвінгу

```bash
# Перевірити обидва записи напряму (DNS-запит до 192.168.100.10)
dig surname.tsa233.lab @192.168.100.10
dig dev.surname.tsa233.lab @192.168.100.10

# Очікуваний вивід для кожного:
# ;; ANSWER SECTION:
# surname.tsa233.lab.      300  IN  A  192.168.100.20
# dev.surname.tsa233.lab.  300  IN  A  192.168.100.20

# Переконатись що зона правильно завантажена (перевірити SOA)
dig SOA tsa233.lab @192.168.100.10

# Короткий варіант через host
host surname.tsa233.lab 192.168.100.10
host dev.surname.tsa233.lab 192.168.100.10

# Якщо /etc/resolv.conf на workstation вказує на 192.168.100.10 — без @
nslookup surname.tsa233.lab
nslookup dev.surname.tsa233.lab
```

---

### Крок 10 — Перевірка HTTP-відповіді субдомену

```bash
# Без DNS — через заголовок Host (для швидкої перевірки Apache)
curl -H "Host: dev.surname.tsa233.lab" http://192.168.100.20

# З DNS (після налаштування BIND)
curl http://dev.surname.tsa233.lab

# Перевірити заголовки відповіді
curl -I http://dev.surname.tsa233.lab

# Детальний вивід з'єднання
curl -v http://dev.surname.tsa233.lab

# Переконатись що основний домен не зламано
curl http://surname.tsa233.lab

# Спостерігати логи субдомену в реальному часі
sudo tail -f /var/log/apache2/dev-surname-access.log
```

---

## Завдання на самопідготовку

1. Вимкнути дефолтний vhost `000-default` і переконатись що відкривається твій основний сайт:
   ```bash
   sudo a2dissite 000-default.conf
   sudo systemctl reload apache2
   ```
2. Налаштувати сторінку помилки 404 для свого vhost — створити `/var/www/main/404.html` та додати до конфігу:
   ```apacheconf
   ErrorDocument 404 /404.html
   ```
3. Увімкнути модуль `mod_rewrite` і додати редирект з `http://` на `https://` (підготовка до TLS):
   ```bash
   sudo a2enmod rewrite
   ```
4. Додати заголовок `X-Powered-By: surname` до відповідей через `mod_headers`:
   ```bash
   sudo a2enmod headers
   ```
   ```apacheconf
   Header always set X-Powered-By "surname"
   ```
5. Обмежити доступ до `dev.surname.tsa233.lab` тільки з підмережі `192.168.100.0/24`:
   ```apacheconf
   <Directory /var/www/dev>
       Require ip 192.168.100.0/24
   </Directory>
   ```

---

## Корисні команди

```bash
# Керування сервісом
sudo systemctl start|stop|restart|reload apache2
sudo systemctl enable apache2           # автозапуск

# Управління сайтами та модулями
sudo a2ensite  <конфіг>                 # увімкнути vhost
sudo a2dissite <конфіг>                 # вимкнути vhost
sudo a2enmod   <модуль>                 # увімкнути модуль
sudo a2dismod  <модуль>                 # вимкнути модуль

# Перевірка
sudo apache2ctl configtest              # перевірити синтаксис конфігів
sudo apache2ctl -S                      # список активних vhost і портів
sudo apache2ctl -M                      # список увімкнених модулів

# Логи
tail -f /var/log/apache2/error.log
tail -f /var/log/apache2/access.log
journalctl -u apache2 -f

# Діагностика
curl -I http://surname.tsa233.lab       # заголовки відповіді
curl -v http://surname.tsa233.lab       # детальний вивід
ss -tlnp | grep apache2                 # який порт слухає
dig surname.tsa233.lab @192.168.100.10       # DNS-запит до конкретного сервера
```
