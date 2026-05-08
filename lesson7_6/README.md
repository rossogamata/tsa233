# Змістовний модуль 7. Адміністрування серверів та балансування навантаження
## ЗАНЯТТЯ 6 (Групове) — Конфігурація веб-сервера Nginx

> **Дисципліна:** Технології Системного Адміністрування | **Курс:** 2-й  
> **ОС:** Ubuntu Server 24.04 LTS | **Тип заняття:** Групове  
> **Середовище:** Proxmox VE · підмережа курсанта `192.168.100.0/24`

---

## Навчальні питання

1. [Конфігураційні файли Nginx](#1-конфігураційні-файли-nginx)
2. [Базова конфігурація Nginx, налаштування блокових директив server](#2-базова-конфігурація-nginx-налаштування-блокових-директив-server)
3. [Налаштування безпечного з'єднання у Nginx та Apache2](#3-налаштування-безпечного-зєднання-у-nginx-та-apache2)

---

## 1. Конфігураційні файли Nginx

### Nginx vs Apache: архітектурна різниця

| Характеристика | Apache | Nginx |
|---|---|---|
| Модель обробки | Процес/потік на з'єднання | Асинхронна, подієво-орієнтована |
| Споживання RAM | Вище (кожен процес — окрема копія) | Нижче (фіксована кількість воркерів) |
| Статичний контент | Добре | Відмінно |
| Динамічний контент | Вбудований (mod_php) | Тільки через FastCGI/проксі |
| Конфігурація | `.htaccess` на директорію | Тільки глобальні файли |
| Типове застосування | Класичний LAMP | Реверс-проксі, CDN, high-load |

```
Apache (prefork MPM):             Nginx:
┌───────────────────────────┐     ┌───────────────────────────────┐
│  Master process            │     │  Master process (root)        │
│  ┌──────┐┌──────┐┌──────┐ │     │  ┌────────────────────────┐   │
│  │Child ││Child ││Child │ │     │  │ Worker #1 (non-root)   │   │
│  │proc. ││proc. ││proc. │ │     │  │  ┌──┐┌──┐┌──┐┌──┐     │   │
│  │(idle)││(busy)││(idle)│ │     │  │  │C1││C2││C3││C4│...  │   │
│  └──────┘└──────┘└──────┘ │     │  └────────────────────────┘   │
│  Кожен = 1 з'єднання      │     │  ┌────────────────────────┐   │
└───────────────────────────┘     │  │ Worker #2              │   │
  1 клієнт = 1 процес             │  │  ┌──┐┌──┐┌──┐┌──┐     │   │
                                  │  │  │C1││C2││C3││C4│...  │   │
                                  │  └────────────────────────┘   │
                                  │  1 воркер = тисячі з'єднань   │
                                  └───────────────────────────────┘
```

### Структура конфігураційних файлів

```
/etc/nginx/
├── nginx.conf                ← головний конфіг (точка входу)
├── mime.types                ← таблиця MIME-типів файлів
├── fastcgi_params            ← змінні для FastCGI (PHP-FPM)
├── proxy_params              ← параметри реверс-проксі
│
├── conf.d/                   ← доп. фрагменти (підключаються через include)
│   └── *.conf
│
├── sites-available/          ← всі описані server-блоки (vhost)
│   └── default               ← дефолтний vhost
├── sites-enabled/            ← символічні посилання на активні vhost
│   └── default -> ../sites-available/default
│
└── modules-enabled/          ← завантажені динамічні модулі
    └── *.conf
```

> В Ubuntu/Debian схема `sites-available` / `sites-enabled` — додається
> пакетом. У «чистому» Nginx (CentOS/RHEL) використовують тільки `conf.d/`.

### Синтаксис: контексти та директиви

Конфіг Nginx — це дерево **контекстів** (`{}`), всередині яких стоять **директиви** (рядки, що закінчуються `;`).

```nginx
# ── main context (глобальний) ──────────────────────────────────────────
user www-data;
worker_processes auto;          # кількість воркерів (= кількість CPU)
pid /run/nginx.pid;

# ── events context ─────────────────────────────────────────────────────
events {
    worker_connections 1024;    # max з'єднань на один воркер
}

# ── http context ────────────────────────────────────────────────────────
http {
    include       mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout 65;

    # ── server context (один vhost) ─────────────────────────────────────
    server {
        listen 80;
        server_name example.com;

        # ── location context ────────────────────────────────────────────
        location / {
            root  /var/www/html;
            index index.html;
        }
    }
}
```

**Ієрархія успадкування:** директива, задана у `http {}`, діє на всі `server {}` блоки;
директива у `server {}` — на всі `location {}` цього vhost. Вужчий контекст перекриває ширший.

### Глобальні директиви nginx.conf

| Директива | Де | Призначення |
|---|---|---|
| `worker_processes auto` | main | кількість воркерів = кількість CPU |
| `worker_connections 1024` | events | max з'єднань на воркер |
| `include mime.types` | http | підключити таблицю MIME |
| `sendfile on` | http | передача файлів через sendfile() syscall |
| `gzip on` | http | стискати відповіді |
| `access_log /path` | http/server | шлях до журналу доступу |
| `error_log /path` | main/http | шлях до журналу помилок |

---

## 2. Базова конфігурація Nginx, налаштування блокових директив server

### Крок 1 — Встановлення Nginx

```bash
sudo apt update
sudo apt install nginx -y

# Перевірити статус
sudo systemctl status nginx

# Переконатись що слухає порт 80
ss -tlnp | grep nginx
```

### Крок 2 — Огляд дефолтного vhost

```bash
# Переглянути поточний активний vhost
cat /etc/nginx/sites-enabled/default
```

Дефолтний `server` блок:

```nginx
server {
    listen 80 default_server;     # default_server = fallback для незнайомих доменів
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;

    server_name _;                # _ = відловити всі імена (wildcard)

    location / {
        try_files $uri $uri/ =404;
    }
}
```

> `try_files $uri $uri/ =404` — спробувати файл, потім директорію, потім повернути 404.

### Крок 3 — Підготовка директорії сайту

```bash
# Створити директорію для свого сайту
sudo mkdir -p /var/www/surname.tsa233.lab

# Встановити правильного власника
sudo chown -R www-data:www-data /var/www/surname.tsa233.lab

# Дати права на читання
sudo chmod -R 755 /var/www/surname.tsa233.lab

# Створити тестову сторінку (замінити surname на своє прізвище)
sudo nano /var/www/surname.tsa233.lab/index.html
```

Вміст `index.html`:

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <title>surname.tsa233.lab</title>
</head>
<body>
    <h1>Вітаю на сайті surname.tsa233.lab</h1>
    <p>Nginx працює коректно</p>
</body>
</html>
```

### Крок 4 — Створення конфігурації vhost

```bash
# Створити новий файл конфігурації
sudo nano /etc/nginx/sites-available/surname.tsa233.lab
```

Вміст конфігурації (`surname` замінити на своє прізвище):

```nginx
server {
    listen 80;
    listen [::]:80;

    server_name surname.tsa233.lab www.surname.tsa233.lab;

    root /var/www/surname.tsa233.lab;
    index index.html;

    # Логи для цього vhost (окремі від дефолтних)
    access_log /var/log/nginx/surname.tsa233.lab-access.log;
    error_log  /var/log/nginx/surname.tsa233.lab-error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

### Директиви блоку server — детально

| Директива | Призначення | Приклад |
|---|---|---|
| `listen` | Порт і адреса прослуховування | `listen 80;` `listen 443 ssl;` |
| `server_name` | Доменні імена цього vhost | `server_name example.com www.example.com;` |
| `root` | Коренева директорія файлів | `root /var/www/html;` |
| `index` | Файли-індекси (за замовчуванням) | `index index.html index.php;` |
| `access_log` | Журнал запитів | `access_log /var/log/nginx/site.log;` |
| `error_log` | Журнал помилок | `error_log /var/log/nginx/site-err.log;` |
| `return` | Перенаправлення | `return 301 https://$host$request_uri;` |

### Директиви блоку location — детально

`location` визначає правило обробки залежно від URI запиту.

```
Пріоритет збігу location (від вищого до нижчого):
──────────────────────────────────────────────────────
  location =  /exact    { ... }   # 1. Точний збіг
  location ^~ /prefix   { ... }   # 2. Пріоритетний префікс
  location ~  \.php$    { ... }   # 3. Регулярний вираз (з урахуванням регістру)
  location ~* \.jpg$    { ... }   # 4. Регулярний вираз (без урахування регістру)
  location    /prefix   { ... }   # 5. Звичайний префікс
```

Приклади `location` блоків:

```nginx
# Статичні файли — відповідати одразу без динаміки
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 30d;
    add_header Cache-Control "public, no-transform";
}

# Сторінка помилки 404
error_page 404 /404.html;
location = /404.html {
    internal;
}

# Приховати файли .htaccess (якщо є)
location ~ /\.ht {
    deny all;
}
```

### Крок 5 — Активація vhost

```bash
# Створити символічне посилання (аналог a2ensite в Apache)
sudo ln -s /etc/nginx/sites-available/surname.tsa233.lab \
           /etc/nginx/sites-enabled/surname.tsa233.lab

# Перевірити синтаксис усіх конфігів (ОБОВ'ЯЗКОВО перед reload)
sudo nginx -t

# Очікуваний вивід:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful

# Перезавантажити Nginx (без зупинки)
sudo systemctl reload nginx
```

### Крок 6 — Перевірка HTTP

```bash
# Перевірити без DNS — через заголовок Host
curl -H "Host: surname.tsa233.lab" http://192.168.100.20

# Переглянути заголовки відповіді
curl -I -H "Host: surname.tsa233.lab" http://192.168.100.20

# Після налаштування DNS (BIND9 з попереднього заняття)
curl http://surname.tsa233.lab

# Спостерігати логи в реальному часі
sudo tail -f /var/log/nginx/surname.tsa233.lab-access.log
```

---

## 3. Налаштування безпечного з'єднання у Nginx та Apache2

### Теоретична довідка: TLS Handshake

```
Клієнт (браузер)                    Сервер (Nginx/Apache)
       │                                    │
       │──── ClientHello ──────────────────►│  (версія TLS, шифри)
       │                                    │
       │◄─── ServerHello ───────────────────│  (обраний шифр)
       │◄─── Certificate ───────────────────│  (X.509 сертифікат)
       │◄─── ServerHelloDone ───────────────│
       │                                    │
       │  [Перевірка сертифікату]           │
       │  (підпис CA, термін дії, CN/SAN)   │
       │                                    │
       │──── ClientKeyExchange ────────────►│  (pre-master secret)
       │──── ChangeCipherSpec ─────────────►│
       │──── Finished ─────────────────────►│
       │◄─── ChangeCipherSpec ──────────────│
       │◄─── Finished ──────────────────────│
       │                                    │
       │════ Зашифрований HTTP ═════════════│
```

### Крок 1 — Генерація самопідписаного сертифіката

> Для виробничого середовища використовують сертифікати від CA (Let's Encrypt).
> У лабораторії — self-signed для навчання.

```bash
# Створити директорію для сертифікатів сайту
sudo mkdir -p /etc/nginx/ssl/surname.tsa233.lab

# Згенерувати приватний ключ + сертифікат одною командою
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/surname.tsa233.lab/privkey.pem \
    -out    /etc/nginx/ssl/surname.tsa233.lab/fullchain.pem \
    -subj "/C=UA/ST=Kyiv/L=Kyiv/O=VITI/OU=TSA/CN=surname.tsa233.lab"

# Перевірити що файли створені
ls -la /etc/nginx/ssl/surname.tsa233.lab/

# Обмежити права на приватний ключ
sudo chmod 600 /etc/nginx/ssl/surname.tsa233.lab/privkey.pem

# Переглянути інформацію про сертифікат
sudo openssl x509 -in /etc/nginx/ssl/surname.tsa233.lab/fullchain.pem \
    -text -noout | grep -A2 "Subject:\|Validity\|Not"
```

Параметри `openssl req`:

| Параметр | Значення |
|---|---|
| `-x509` | Створити самопідписаний сертифікат (не CSR) |
| `-nodes` | Не шифрувати приватний ключ паролем |
| `-days 365` | Термін дії — 365 днів |
| `-newkey rsa:2048` | Створити новий RSA ключ 2048 біт |
| `-keyout` | Файл приватного ключа |
| `-out` | Файл сертифіката |
| `-subj` | Поля сертифіката (без інтерактивних запитань) |

### 3.1 Налаштування HTTPS у Nginx

```bash
# Відкрити конфіг vhost
sudo nano /etc/nginx/sites-available/surname.tsa233.lab
```

Оновлений конфіг з TLS та редиректом HTTP→HTTPS:

```nginx
# ── HTTP: редирект на HTTPS ──────────────────────────────────────────────
server {
    listen 80;
    listen [::]:80;
    server_name surname.tsa233.lab www.surname.tsa233.lab;

    # 301 = постійний редирект
    return 301 https://$host$request_uri;
}

# ── HTTPS: основний vhost ────────────────────────────────────────────────
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name surname.tsa233.lab www.surname.tsa233.lab;

    # Сертифікат і ключ
    ssl_certificate     /etc/nginx/ssl/surname.tsa233.lab/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/surname.tsa233.lab/privkey.pem;

    # Протоколи: вимкнути застарілі TLS 1.0/1.1
    ssl_protocols TLSv1.2 TLSv1.3;

    # Набори шифрів (рекомендовані Mozilla)
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Кешування TLS-сесій (пришвидшує повторні з'єднання)
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;

    # Заголовки безпеки
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;

    root  /var/www/surname.tsa233.lab;
    index index.html;

    access_log /var/log/nginx/surname.tsa233.lab-access.log;
    error_log  /var/log/nginx/surname.tsa233.lab-error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

```bash
# Перевірити синтаксис
sudo nginx -t

# Застосувати конфіг
sudo systemctl reload nginx

# Перевірити що слухає порти 80 і 443
ss -tlnp | grep nginx
```

### Крок 2 — Перевірка HTTPS Nginx

```bash
# Перевірити редирект HTTP→HTTPS
curl -I http://surname.tsa233.lab
# Очікується: HTTP/1.1 301 Moved Permanently
#             Location: https://surname.tsa233.lab/

# Перевірити HTTPS (--insecure = ігнорувати self-signed помилку)
curl --insecure https://surname.tsa233.lab

# Детальна інформація про TLS з'єднання
curl --insecure -v https://surname.tsa233.lab 2>&1 | grep -E "SSL|TLS|cipher|subject|issuer"

# Перевірити сертифікат через openssl
echo | openssl s_client -connect surname.tsa233.lab:443 2>/dev/null \
    | openssl x509 -text -noout | grep -A2 "Subject:\|Not "
```

---

### 3.2 Налаштування HTTPS у Apache2

> Якщо Nginx та Apache2 встановлені на одному сервері — їм потрібні різні порти.
> Типово: Nginx на 80/443, Apache на 8080/8443.
> У нашій лабораторії кожен студент налаштовує **одне** з двох.

```bash
# Увімкнути модуль SSL
sudo a2enmod ssl

# Увімкнути дефолтний HTTPS-vhost (шаблон для довідки)
sudo a2ensite default-ssl

# Переглянути структуру default-ssl.conf
cat /etc/apache2/sites-available/default-ssl.conf
```

#### Створення SSL vhost для Apache2

```bash
# Скопіювати HTTP vhost як основу
sudo cp /etc/apache2/sites-available/surname.tsa233.lab.conf \
        /etc/apache2/sites-available/surname.tsa233.lab-ssl.conf

sudo nano /etc/apache2/sites-available/surname.tsa233.lab-ssl.conf
```

Вміст SSL vhost (Apache2):

```apacheconf
<VirtualHost *:443>
    ServerName  surname.tsa233.lab
    ServerAdmin surname@tsa233.lab

    DocumentRoot /var/www/surname.tsa233.lab

    # Увімкнути SSL для цього vhost
    SSLEngine on

    # Шлях до сертифіката і ключа
    SSLCertificateFile    /etc/nginx/ssl/surname.tsa233.lab/fullchain.pem
    SSLCertificateKeyFile /etc/nginx/ssl/surname.tsa233.lab/privkey.pem

    # Вимкнути застарілі протоколи
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1

    # Заголовки безпеки
    Header always set Strict-Transport-Security "max-age=31536000"
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff

    <Directory /var/www/surname.tsa233.lab>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog  ${APACHE_LOG_DIR}/surname-ssl-error.log
    CustomLog ${APACHE_LOG_DIR}/surname-ssl-access.log combined
</VirtualHost>
```

#### Редирект HTTP→HTTPS у Apache2

Додати до HTTP-vhost (`surname.tsa233.lab.conf`) всередину `<VirtualHost *:80>`:

```apacheconf
# Редирект усього трафіку на HTTPS
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]
```

Або простіший варіант з `mod_alias`:

```apacheconf
Redirect permanent / https://surname.tsa233.lab/
```

```bash
# Увімкнути необхідні модулі
sudo a2enmod ssl rewrite headers

# Активувати SSL vhost
sudo a2ensite surname.tsa233.lab-ssl.conf

# Перевірити синтаксис
sudo apache2ctl configtest

# Перезавантажити Apache
sudo systemctl reload apache2

# Перевірити
sudo apache2ctl -S
ss -tlnp | grep apache2
```

### Порівняння TLS директив: Nginx vs Apache2

| Функція | Nginx | Apache2 |
|---|---|---|
| Увімкнути SSL | `listen 443 ssl;` | `SSLEngine on` |
| Файл сертифіката | `ssl_certificate` | `SSLCertificateFile` |
| Приватний ключ | `ssl_certificate_key` | `SSLCertificateKeyFile` |
| Протоколи | `ssl_protocols` | `SSLProtocol` |
| Шифри | `ssl_ciphers` | `SSLCipherSuite` |
| HSTS заголовок | `add_header Strict-Transport-Security` | `Header always set Strict-Transport-Security` |
| Перевірка конфігу | `nginx -t` | `apache2ctl configtest` |
| Перезавантаження | `systemctl reload nginx` | `systemctl reload apache2` |

### Заголовки безпеки — пояснення

| Заголовок | Призначення |
|---|---|
| `Strict-Transport-Security` | Браузер завжди використовує HTTPS (HSTS) |
| `X-Frame-Options: DENY` | Забороняє вставку сайту в `<iframe>` (захист від Clickjacking) |
| `X-Content-Type-Options: nosniff` | Браузер не «вгадує» MIME-тип (захист від MIME-sniffing) |

---

## Завдання на самопідготовку

1. Додати `location` блок, що роздає файли зі статичної директорії `/var/www/surname.tsa233.lab/static/` з кешуванням на 7 днів:
   ```nginx
   location /static/ {
       expires 7d;
       add_header Cache-Control "public";
   }
   ```

2. Налаштувати сторінку помилки 404 для Nginx:
   ```bash
   sudo nano /var/www/surname.tsa233.lab/404.html
   ```
   ```nginx
   error_page 404 /404.html;
   location = /404.html { internal; }
   ```

3. Перевірити рейтинг безпеки TLS конфігурації (у браузері або через `testssl.sh`):
   ```bash
   # Встановити testssl.sh
   sudo apt install testssl.sh -y
   testssl.sh https://surname.tsa233.lab
   ```

4. Подивитись як Nginx логує запити у форматі `combined`:
   ```bash
   sudo tail -f /var/log/nginx/surname.tsa233.lab-access.log
   # Зробити кілька curl-запитів і проаналізувати записи
   ```

5. Налаштувати обмеження розміру тіла запиту (захист від великих POST):
   ```nginx
   # Всередині server {} блоку:
   client_max_body_size 10m;
   ```

---

## Корисні команди

```bash
# ── Nginx ────────────────────────────────────────────────────────────────
sudo systemctl start|stop|restart|reload nginx
sudo systemctl enable nginx                     # автозапуск

sudo nginx -t                                   # перевірити синтаксис конфігів
sudo nginx -T                                   # вивести весь об'єднаний конфіг
sudo nginx -s reload                            # перезавантажити без systemctl

# Управління vhost (вручну, аналог a2ensite/a2dissite)
sudo ln -s /etc/nginx/sites-available/site /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/site

# ── Apache2 ──────────────────────────────────────────────────────────────
sudo systemctl start|stop|restart|reload apache2
sudo a2enmod ssl rewrite headers                # увімкнути модулі
sudo a2ensite <конфіг>                          # увімкнути vhost
sudo a2dissite <конфіг>                         # вимкнути vhost
sudo apache2ctl configtest                      # перевірити синтаксис
sudo apache2ctl -S                              # список активних vhost

# ── OpenSSL / TLS діагностика ────────────────────────────────────────────
# Переглянути сертифікат сервера
echo | openssl s_client -connect hostname:443 2>/dev/null | openssl x509 -text -noout

# Перевірити підтримувані шифри
openssl ciphers -v 'ECDHE+AESGCM:ECDHE+AES256' | column -t

# Перевірити термін дії сертифіката
openssl x509 -in /etc/nginx/ssl/surname.tsa233.lab/fullchain.pem -noout -dates

# ── Мережева діагностика ─────────────────────────────────────────────────
ss -tlnp | grep -E 'nginx|apache'               # порти, що слухають
curl -I http://surname.tsa233.lab               # заголовки (HTTP)
curl --insecure -I https://surname.tsa233.lab   # заголовки (HTTPS, self-signed)
curl -v --insecure https://surname.tsa233.lab   # детальний вивід TLS

# ── Логи ─────────────────────────────────────────────────────────────────
tail -f /var/log/nginx/surname.tsa233.lab-access.log
tail -f /var/log/nginx/surname.tsa233.lab-error.log
journalctl -u nginx -f
journalctl -u apache2 -f
```
