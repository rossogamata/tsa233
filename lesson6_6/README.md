# Практичне заняття 6: Робота з цифровими сертифікатами

> **Курс:** Технології системного адміністрування (ТСА-233)
> **Аудиторія:** Курсанти 3 курсу ВІТІ
> **Тип заняття:** Практичне
> **Час виконання:** ~120 хвилин

---

## Навчальні питання

1. [Створення сертифікату за допомогою OpenSSL](#1-створення-сертифікату-за-допомогою-openssl)
2. [Додавання цифрового сертифікату в ОС Linux та Windows](#2-додавання-цифрового-сертифікату-в-ос-linux-та-windows)
3. [Шифрування та розшифрування тексту у файлі](#3-шифрування-та-розшифрування-тексту-у-файлі)

---

## Теоретична довідка

### Що таке цифровий сертифікат?

**Цифровий сертифікат X.509** — це електронний документ, що зв'язує публічний ключ з інформацією про його власника, підписаний Центром сертифікації (CA).

```
┌────────────────────────────────────────┐
│         Сертифікат X.509               │
├────────────────────────────────────────┤
│  Subject:  CN=tsa233.lab, O=VIIT       │
│  Issuer:   CN=VIIT Root CA             │
│  Valid:    2026-01-01 – 2027-01-01     │
│  Key:      RSA 2048 bit                │
│  [Публічний ключ власника...]          │
│  [Підпис CA...]                        │
└────────────────────────────────────────┘
```

### Типи сертифікатів за призначенням

| Тип | Використання |
|-----|--------------|
| **Server (TLS)** | HTTPS-сайти, захищене з'єднання |
| **Client** | Автентифікація користувача (mTLS) |
| **CA (Root/Intermediate)** | Підписування інших сертифікатів |
| **Code Signing** | Підпис програмного забезпечення |
| **Email (S/MIME)** | Захищена електронна пошта |

### Формати файлів

| Розширення | Формат | Вміст |
|------------|--------|-------|
| `.pem` | Base64 (текст) | Ключ, сертифікат або обидва |
| `.crt` / `.cer` | PEM або DER | Сертифікат |
| `.key` | PEM | Приватний ключ |
| `.csr` | PEM | Запит на підпис |
| `.p12` / `.pfx` | PKCS#12 (бінарний) | Сертифікат + приватний ключ разом |
| `.der` | Бінарний | Сертифікат (без Base64) |

---

## 1. Створення сертифікату за допомогою OpenSSL

### 1.1 Перевірка наявності OpenSSL

```bash
openssl version
# Очікуваний вивід: OpenSSL 3.x.x  ...

# Якщо не встановлено:
sudo apt update && sudo apt install -y openssl
```

---

### 1.2 Підготовка робочої директорії

```bash
mkdir -p ~/certs-lab/{ca,server,client}
cd ~/certs-lab

# Переглянути структуру що будемо будувати
tree ~/certs-lab 2>/dev/null || find ~/certs-lab -type d | sort
```

```
certs-lab/
├── ca/          ← файли Центру сертифікації
├── server/      ← сертифікат сервера
└── client/      ← клієнтський сертифікат
```

---

### 1.3 Варіант A — Самопідписаний сертифікат

Найпростіший варіант: один файл, без ієрархії CA. Використовується для тестування.

```bash
cd ~/certs-lab

# Крок 1: Генерація приватного ключа
openssl genrsa -out server/self.key 2048

# Переглянути структуру ключа
openssl rsa -in server/self.key -text -noout | head -20
```

```bash
# Крок 2: Самопідписаний сертифікат (ключ + CSR + підпис — за один крок)
openssl req -new -x509 \
    -key server/self.key \
    -out server/self.crt \
    -days 365 \
    -subj "/C=UA/ST=Kyiv/L=Kyiv/O=VIIT/OU=Lab/CN=tsa233.lab"
```

> Параметри поля `-subj`:
> - `C`  — Country (2 літери країни): `UA`
> - `ST` — State (область): `Kyiv`
> - `L`  — Locality (місто): `Kyiv`
> - `O`  — Organization: `VIIT`
> - `OU` — Organizational Unit: `Lab`
> - `CN` — Common Name (ім'я домену або хосту): `tsa233.lab`

```bash
# Крок 3: Переглянути сертифікат
openssl x509 -in server/self.crt -text -noout

# Короткий огляд — тільки ключові поля
openssl x509 -in server/self.crt -noout \
    -subject -issuer -dates -fingerprint
```

Очікуваний вивід:
```
subject=C=UA, ST=Kyiv, L=Kyiv, O=VIIT, OU=Lab, CN=tsa233.lab
issuer=C=UA, ST=Kyiv, L=Kyiv, O=VIIT, OU=Lab, CN=tsa233.lab
notBefore=Jan  1 00:00:00 2026 GMT
notAfter= Jan  1 00:00:00 2027 GMT
SHA1 Fingerprint=XX:XX:XX:...
```

> **Зверніть увагу:** `subject` і `issuer` однакові — це ознака самопідписаного сертифіката.

---

### 1.4 Варіант B — Сертифікат, підписаний власним CA (рекомендований для лабораторії)

#### Крок 1 — Створення кореневого CA

```bash
cd ~/certs-lab

# 1.1 Генерація ключа CA (4096 біт — CA потребує більшої стійкості)
openssl genrsa -out ca/ca.key 4096

# Захист ключа CA (в реальній роботі — обов'язково!)
chmod 400 ca/ca.key
```

```bash
# 1.2 Самопідписаний сертифікат CA (термін — 10 років)
openssl req -new -x509 \
    -key ca/ca.key \
    -out ca/ca.crt \
    -days 3650 \
    -subj "/C=UA/ST=Kyiv/O=VIIT/CN=VIIT Root CA"
```

```bash
# 1.3 Перевірити CA сертифікат
openssl x509 -in ca/ca.crt -text -noout | grep -A5 "Issuer\|Subject\|Validity"
```

---

#### Крок 2 — Генерація ключа сервера та CSR

**CSR (Certificate Signing Request)** — запит на підпис: містить публічний ключ та інформацію про власника, але ще **не підписаний** CA.

```bash
# 2.1 Приватний ключ сервера
openssl genrsa -out server/server.key 2048
```

```bash
# 2.2 Генерація CSR
openssl req -new \
    -key server/server.key \
    -out server/server.csr \
    -subj "/C=UA/ST=Kyiv/O=VIIT/CN=tsa233.lab"

# Переглянути що всередині CSR
openssl req -in server/server.csr -text -noout
```

```
Certificate Request:
    Subject: C=UA, ST=Kyiv, O=VIIT, CN=tsa233.lab
    Public Key Algorithm: rsaEncryption
        Public-Key: (2048 bit)
    Signature Algorithm: sha256WithRSAEncryption
```

---

#### Крок 3 — CA підписує сертифікат сервера

```bash
# 3.1 Підписати CSR — видати сертифікат (термін — 1 рік)
openssl x509 -req \
    -in server/server.csr \
    -CA ca/ca.crt \
    -CAkey ca/ca.key \
    -CAcreateserial \
    -out server/server.crt \
    -days 365 \
    -sha256
```

```bash
# 3.2 Переглянути виданий сертифікат
openssl x509 -in server/server.crt -text -noout | grep -A5 "Issuer\|Subject\|Validity"
```

Тепер `issuer` відрізняється від `subject`:
```
Issuer:  C=UA, ST=Kyiv, O=VIIT, CN=VIIT Root CA
Subject: C=UA, ST=Kyiv, O=VIIT, CN=tsa233.lab
```

---

#### Крок 4 — Перевірка ланцюга довіри

```bash
# Перевірити що сертифікат підписаний нашим CA
openssl verify -CAfile ca/ca.crt server/server.crt
# Очікуваний вивід: server/server.crt: OK

# Переглянути поточний стан директорії
ls -lh ca/ server/
```

```
ca/
├── ca.crt    ← сертифікат CA (довіряємо, розповсюджуємо)
├── ca.key    ← ключ CA     (НІКОЛИ не передавати!)
└── ca.srl    ← серійний лічильник

server/
├── server.crt  ← підписаний сертифікат (розповсюджуємо на сервер)
├── server.csr  ← CSR (після підпису вже не потрібен)
└── server.key  ← ключ сервера (зберігати в безпеці)
```

---

### 1.5 Конвертація форматів сертифікатів

```bash
cd ~/certs-lab

# PEM → DER (бінарний, для Java/Android)
openssl x509 -in server/server.crt -outform DER -out server/server.der

# PEM → PKCS#12 / PFX (для Windows, IIS, .NET)
# Об'єднує ключ + сертифікат + ланцюг CA в один файл
openssl pkcs12 -export \
    -in server/server.crt \
    -inkey server/server.key \
    -certfile ca/ca.crt \
    -out server/server.pfx \
    -name "tsa233.lab"
# Ввести пароль для захисту PFX (можна порожній для лабораторії)

# PKCS#12 → PEM (зворотньо)
openssl pkcs12 -in server/server.pfx -out server/server_from_pfx.pem -nodes

# Переглянути вміст PFX файлу
openssl pkcs12 -in server/server.pfx -info -nodes 2>/dev/null | head -20

# Порівняти розміри форматів
ls -lh server/server.crt server/server.der server/server.pfx
```

---

### 1.6 Сертифікат з розширеннями SAN (Subject Alternative Name)

У сучасних браузерах поле CN ігнорується — обов'язково потрібен **SAN**. Без нього Chrome/Firefox покажуть помилку навіть для валідних сертифікатів.

```bash
cd ~/certs-lab

# Створити конфігурацій файл з SAN
cat > /tmp/san.cnf << 'EOF'
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C  = UA
ST = Kyiv
O  = VIIT
CN = tsa233.lab

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = tsa233.lab
DNS.2 = www.tsa233.lab
DNS.3 = lab.local
IP.1  = 127.0.0.1
EOF
```

```bash
# Генерація ключа та CSR з SAN
openssl genrsa -out server/san.key 2048

openssl req -new \
    -key server/san.key \
    -out server/san.csr \
    -config /tmp/san.cnf

# Підписати CA з розширеннями
cat > /tmp/san_ext.cnf << 'EOF'
subjectAltName = DNS:tsa233.lab, DNS:www.tsa233.lab, DNS:lab.local, IP:127.0.0.1
extendedKeyUsage = serverAuth
EOF

openssl x509 -req \
    -in server/san.csr \
    -CA ca/ca.crt \
    -CAkey ca/ca.key \
    -CAcreateserial \
    -out server/san.crt \
    -days 365 \
    -sha256 \
    -extfile /tmp/san_ext.cnf

# Перевірити SAN у сертифікаті
openssl x509 -in server/san.crt -text -noout | grep -A5 "Subject Alternative"
```

---

## 2. Додавання цифрового сертифікату в ОС Linux та Windows

### 2.1 Сховища сертифікатів — де вони знаходяться?

#### Linux (Ubuntu/Debian)

```
/etc/ssl/certs/               ← системне сховище (PEM файли)
/usr/local/share/ca-certificates/ ← місце для додавання своїх CA
/etc/ssl/private/             ← приватні ключі (chmod 700)
```

#### Windows

```
certmgr.msc                   ← сховище поточного користувача (GUI)
certlm.msc                    ← сховище комп'ютера (GUI)

Основні контейнери:
  Trusted Root CA              ← кореневі CA яким довіряємо
  Intermediate CA              ← проміжні CA
  Personal                     ← особисті сертифікати
```

---

### 2.2 Додавання CA сертифіката в Linux (Ubuntu/Debian)

#### Метод 1 — через update-ca-certificates (системний рівень)

```bash
# Скопіювати CA сертифікат у системну директорію
# ВАЖЛИВО: файл повинен мати розширення .crt
sudo cp ~/certs-lab/ca/ca.crt /usr/local/share/ca-certificates/viit-root-ca.crt

# Оновити системне сховище
sudo update-ca-certificates
```

Очікуваний вивід:
```
Updating certificates in /etc/ssl/certs...
1 added, 0 removed; done.
Running hooks in /etc/hooks/ca-certificates.d...
done.
```

```bash
# Перевірити що CA з'явився у системному сховищі
ls /etc/ssl/certs/ | grep viit
# viit-root-ca.pem

# Або перевірити через openssl
openssl verify -CAfile /etc/ssl/certs/viit-root-ca.pem ~/certs-lab/server/server.crt
# server.crt: OK
```

---

#### Метод 2 — перевірка через curl

```bash
# Без довіреного CA — помилка
curl https://tsa233.lab
# curl: (60) SSL certificate problem: unable to get local issuer certificate

# З явним вказанням CA — OK
curl --cacert ~/certs-lab/ca/ca.crt https://tsa233.lab

# Після додавання CA в систему — працює без прапорця
curl https://tsa233.lab
```

---

#### Метод 3 — для браузера Firefox (власне сховище)

Firefox **не використовує** системне сховище Linux — у нього власна база.

```bash
# Встановити утиліту для роботи зі сховищем NSS
sudo apt install -y libnss3-tools

# Знайти профілі Firefox
ls ~/.mozilla/firefox/*.default-release/

# Додати CA до Firefox профілю
certutil -d sql:$HOME/.mozilla/firefox/*.default-release \
         -A -n "VIIT Root CA" \
         -t "CT,," \
         -i ~/certs-lab/ca/ca.crt
```

> Прапорці довіри `-t "CT,,"`:
> - `C` — довіряти як CA для SSL/TLS
> - `T` — довіряти для видачі клієнтських сертифікатів
> - `,` — email (не встановлено)
> - `,` — code signing (не встановлено)

```bash
# Перевірити що CA додано
certutil -d sql:$HOME/.mozilla/firefox/*.default-release -L | grep VIIT

# Видалити CA (якщо потрібно)
# certutil -d sql:$HOME/.mozilla/firefox/*.default-release -D -n "VIIT Root CA"
```

---

#### Метод 4 — для Chrome/Chromium (на Linux)

Chrome на Linux також має власне сховище NSS, але зазвичай спільне:

```bash
# Chrome зазвичай використовує:
certutil -d sql:$HOME/.pki/nssdb \
         -A -n "VIIT Root CA" \
         -t "CT,," \
         -i ~/certs-lab/ca/ca.crt

# Перезапустити Chrome після цього
```

---

#### Видалення CA з Linux

```bash
# Видалити файл і оновити сховище
sudo rm /usr/local/share/ca-certificates/viit-root-ca.crt
sudo update-ca-certificates --fresh
```

---

### 2.3 Встановлення сертифіката сервера для nginx (Linux)

```bash
# Встановити nginx якщо немає
sudo apt install -y nginx

# Скопіювати сертифікат та ключ
sudo cp ~/certs-lab/server/server.crt /etc/ssl/certs/tsa233.crt
sudo cp ~/certs-lab/server/server.key /etc/ssl/private/tsa233.key

# Встановити правильні права на приватний ключ
sudo chmod 640 /etc/ssl/private/tsa233.key
sudo chown root:ssl-cert /etc/ssl/private/tsa233.key
```

```bash
# Створити конфігурацію nginx
sudo tee /etc/nginx/sites-available/tsa233 > /dev/null << 'EOF'
server {
    listen 443 ssl;
    server_name tsa233.lab;

    ssl_certificate     /etc/ssl/certs/tsa233.crt;
    ssl_certificate_key /etc/ssl/private/tsa233.key;

    # Сучасні параметри TLS
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    root /var/www/html;
    index index.html;
}

# Перенаправлення HTTP → HTTPS
server {
    listen 80;
    server_name tsa233.lab;
    return 301 https://$host$request_uri;
}
EOF
```

```bash
# Активувати конфігурацію
sudo ln -sf /etc/nginx/sites-available/tsa233 /etc/nginx/sites-enabled/

# Перевірити конфігурацію
sudo nginx -t

# Перезавантажити nginx
sudo systemctl reload nginx

# Додати запис у /etc/hosts для тестування
echo "127.0.0.1 tsa233.lab" | sudo tee -a /etc/hosts

# Перевірити HTTPS з'єднання
openssl s_client -connect tsa233.lab:443 -CAfile ~/certs-lab/ca/ca.crt
```

---

### 2.4 Додавання CA сертифіката в Windows

#### Метод 1 — через GUI (certmgr.msc)

1. Скопіювати файл `ca.crt` на Windows машину (через спільну папку, SCP, або USB)

2. Відкрити менеджер сертифікатів:
   - `Win + R` → ввести `certmgr.msc` → Enter
   - *(для всіх користувачів: `certlm.msc`)*

3. В лівій панелі:
   ```
   Certificates - Current User
   └── Trusted Root Certification Authorities
       └── Certificates  ← ПКМ тут
   ```

4. Правою кнопкою → **All Tasks** → **Import...**

5. Майстер імпорту:
   - **Next** → вибрати файл `ca.crt` → **Next**
   - Certificate store: **Trusted Root Certification Authorities**
   - **Next** → **Finish**

6. Підтвердити попередження безпеки → **Yes**

7. Перевірити:
   ```
   Trusted Root Certification Authorities → Certificates
   → знайти "VIIT Root CA"
   ```

---

#### Метод 2 — через PowerShell (автоматизація)

```powershell
# Запустити PowerShell від імені Адміністратора

# Імпортувати CA у сховище поточного користувача
Import-Certificate -FilePath "C:\certs\ca.crt" `
    -CertStoreLocation Cert:\CurrentUser\Root

# Імпортувати CA у сховище комп'ютера (для всіх користувачів)
Import-Certificate -FilePath "C:\certs\ca.crt" `
    -CertStoreLocation Cert:\LocalMachine\Root
```

```powershell
# Перевірити що сертифікат встановлено
Get-ChildItem -Path Cert:\CurrentUser\Root | `
    Where-Object { $_.Subject -like "*VIIT*" }

# Переглянути деталі
Get-ChildItem -Path Cert:\CurrentUser\Root | `
    Where-Object { $_.Subject -like "*VIIT*" } | `
    Format-List Subject, Issuer, NotBefore, NotAfter, Thumbprint
```

---

#### Метод 3 — через certutil (командний рядок Windows)

```cmd
:: Запустити cmd від імені Адміністратора

:: Додати CA до сховища поточного користувача
certutil -addstore Root "C:\certs\ca.crt"

:: Додати CA до сховища комп'ютера
certutil -addstore -enterprise Root "C:\certs\ca.crt"

:: Перевірити встановлення
certutil -store Root | findstr /i "VIIT"

:: Видалити сертифікат за відбитком (Thumbprint)
:: certutil -delstore Root <Thumbprint>
```

---

#### Імпорт PKCS#12 (.pfx) на Windows

PFX файл містить і сертифікат, і приватний ключ — використовується для серверів IIS або клієнтської автентифікації.

```powershell
# PowerShell — імпорт PFX з паролем
$password = ConvertTo-SecureString -String "пароль" -Force -AsPlainText

Import-PfxCertificate -FilePath "C:\certs\server.pfx" `
    -CertStoreLocation Cert:\LocalMachine\My `
    -Password $password
```

```cmd
:: CMD — через certutil
certutil -importpfx "C:\certs\server.pfx"
```

**Через GUI:**
1. Двічі клікнути на `.pfx` файл
2. Майстер імпорту → вибрати сховище (**Local Machine** або **Current User**)
3. Ввести пароль PFX
4. Вибрати контейнер: для сервера — **Personal**, для CA — **Trusted Root CA**

---

#### Видалення сертифіката в Windows

```powershell
# Знайти за відбитком
$cert = Get-ChildItem -Path Cert:\CurrentUser\Root | `
    Where-Object { $_.Subject -like "*VIIT*" }

# Видалити
$cert | Remove-Item
```

---

### 2.5 Перевірка після встановлення

#### Linux

```bash
# Перевірити через openssl
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt ~/certs-lab/server/server.crt

# Перевірити що curl довіряє
curl -v https://tsa233.lab 2>&1 | grep -E "SSL|TLS|issuer|subject"

# Переглянути сертифікат живого HTTPS-з'єднання
openssl s_client -connect tsa233.lab:443 -showcerts < /dev/null 2>/dev/null \
    | openssl x509 -noout -text | grep -A3 "Issuer\|Subject\|Validity"
```

#### Windows

```powershell
# Перевірити з'єднання через PowerShell
[Net.ServicePointManager]::ServerCertificateValidationCallback = $null
Invoke-WebRequest -Uri "https://tsa233.lab" -UseBasicParsing

# Переглянути сертифікат сайту
$request = [System.Net.HttpWebRequest]::Create("https://tsa233.lab")
$request.GetResponse() | Out-Null
$cert = $request.ServicePoint.Certificate
Write-Host "Subject:  $($cert.Subject)"
Write-Host "Issuer:   $($cert.Issuer)"
Write-Host "Expires:  $($cert.GetExpirationDateString())"
```

---

## 3. Шифрування та розшифрування тексту у файлі

### 3.1 Асиметричне шифрування файлу (RSA)

RSA шифрує публічним ключем — розшифрувати може тільки власник приватного ключа. Це основа безпечної передачі даних.

> **Обмеження RSA:** не можна зашифрувати файл більший за розмір ключа (~245 байт для RSA-2048). Для великих файлів — дивіться AES нижче.

#### Крок 1 — Підготувати файл із текстом

```bash
mkdir -p ~/encrypt-lab
cd ~/encrypt-lab

# Створити файл з повідомленням
echo "Секретне повідомлення від $(whoami), $(date '+%d.%m.%Y')" > message.txt

cat message.txt
```

#### Крок 2 — Згенерувати пару RSA-ключів

```bash
# Приватний ключ (зберігати в таємниці)
openssl genrsa -out private.pem 2048

# Витягнути публічний ключ (можна передавати будь-кому)
openssl rsa -in private.pem -pubout -out public.pem

ls -lh private.pem public.pem
```

```
private.pem  1.7K   ← приватний: тільки у вас
public.pem    451   ← публічний: можна публікувати
```

#### Крок 3 — Зашифрувати файл публічним ключем

```bash
openssl pkeyutl -encrypt \
    -inkey public.pem -pubin \
    -in  message.txt \
    -out message.enc

# Переглянути зашифровані дані (hex-дамп)
xxd message.enc | head -5
```

```
00000000: 8f3a b210 e5c7 9a02 ...   ← нечитаємий бінарний вміст
```

```bash
# Спроба прочитати напряму — нічого зрозумілого
cat message.enc
```

#### Крок 4 — Розшифрувати приватним ключем

```bash
openssl pkeyutl -decrypt \
    -inkey private.pem \
    -in  message.enc \
    -out message_dec.txt

cat message_dec.txt
```

```bash
# Перевірити що оригінал і розшифрований файл ідентичні
diff message.txt message_dec.txt && echo "Файли ідентичні ✓"
```

#### Схема процесу

```
Відправник                          Отримувач
─────────                           ─────────
message.txt                         private.pem (тільки у нього)
    │
    ▼
openssl pkeyutl -encrypt            openssl pkeyutl -decrypt
    -inkey public.pem -pubin ──────►    -inkey private.pem
    │                                       │
    ▼                                       ▼
message.enc ─────────── мережа ──► message_dec.txt
(нечитаємо)                        (відновлено)
```

---

### 3.2 Симетричне шифрування файлу (AES-256)

AES шифрує одним паролем — швидко, без обмежень на розмір файлу. Використовується для локального захисту або передачі через захищений канал.

#### Зашифрувати файл

```bash
cd ~/encrypt-lab

# Створити файл довільного розміру
cat > secret.txt << 'EOF'
СЕКРЕТНІ ДАНІ ПІДРОЗДІЛУ
Позивний: Альфа
Координати: 50.4501° N, 30.5234° E
Час операції: 03:00
EOF

# Зашифрувати паролем (AES-256-CBC + PBKDF2)
openssl enc -aes-256-cbc -pbkdf2 \
    -in  secret.txt \
    -out secret.enc
# Ввести пароль двічі
```

#### Переглянути зашифроване

```bash
# Бінарний вміст — нічого не розібрати
xxd secret.enc | head -4

# Розмір майже такий самий як оригінал
ls -lh secret.txt secret.enc
```

#### Розшифрувати файл

```bash
openssl enc -d -aes-256-cbc -pbkdf2 \
    -in  secret.enc \
    -out secret_dec.txt
# Ввести пароль

cat secret_dec.txt
```

```bash
# Перевірити що вміст збігається
diff secret.txt secret_dec.txt && echo "Файли ідентичні ✓"
```

---

### 3.3 Гібридне шифрування файлу (AES + RSA)

У реальній практиці для шифрування файлів будь-якого розміру використовують **гібридний підхід**: файл шифрується AES, а сам AES-ключ шифрується RSA. Саме так працює HTTPS, PGP, S/MIME.

```
Файл ──► AES-256 (випадковий ключ) ──► зашифрований файл
              │
              ▼
         RSA-encrypt(AES-ключ, публічний ключ) ──► зашифрований ключ
```

```bash
cd ~/encrypt-lab

# Великий файл для демонстрації
dd if=/dev/urandom bs=1K count=100 2>/dev/null | base64 > bigfile.txt
echo "Розмір: $(wc -c < bigfile.txt) байт"

# 1. Генерація випадкового AES-ключа (32 байти = 256 біт)
openssl rand -hex 32 > aes.key
cat aes.key

# 2. Зашифрувати файл AES-ключем
openssl enc -aes-256-cbc -pbkdf2 \
    -in bigfile.txt \
    -out bigfile.enc \
    -pass file:aes.key

# 3. Зашифрувати AES-ключ публічним ключем RSA
openssl pkeyutl -encrypt \
    -inkey public.pem -pubin \
    -in  aes.key \
    -out aes.key.enc

# Передаємо: bigfile.enc + aes.key.enc (aes.key можна видалити)
rm aes.key
ls -lh bigfile.txt bigfile.enc aes.key.enc
```

```bash
# === Розшифрування ===

# 1. Відновити AES-ключ приватним ключем RSA
openssl pkeyutl -decrypt \
    -inkey private.pem \
    -in  aes.key.enc \
    -out aes.key

# 2. Розшифрувати файл відновленим ключем
openssl enc -d -aes-256-cbc -pbkdf2 \
    -in bigfile.enc \
    -out bigfile_dec.txt \
    -pass file:aes.key

# Перевірити
diff bigfile.txt bigfile_dec.txt && echo "Файли ідентичні ✓"
```

---

## Завдання для самостійної роботи

### Завдання 1 — Базове (обов'язкове)

1. Створити самопідписаний сертифікат для домену `yourname.lab`
2. Конвертувати його у формат `.pfx`
3. Перевірити вміст через `openssl x509 -text`
4. Записати у звіт: Subject, Issuer, термін дії, відбиток (SHA256 Fingerprint)

### Завдання 2 — Основне

1. Створити власний Root CA (`YourName Root CA`)
2. Видати сертифікат серверу `srv.yourname.lab` з SAN
3. Встановити CA сертифікат у системне сховище Linux
4. Перевірити ланцюг довіри через `openssl verify`
5. Налаштувати nginx з HTTPS на виданому сертифікаті
6. Переконатись що `curl https://srv.yourname.lab` повертає `200 OK` без попереджень

### Завдання 3 — Підвищеної складності

1. Передати `ca.crt` на Windows машину
2. Встановити через PowerShell у сховище `LocalMachine\Root`
3. Перевірити що браузер Edge/Chrome не показує попередження при відкритті `https://tsa233.lab`
4. Видалити CA з сховища та переконатись що з'являється попередження

---

## Питання для самоконтролю

1. Чим відрізняється самопідписаний сертифікат від сертифіката, виданого CA?
2. Навіщо встановлювати CA сертифікат, а не серверний?
3. Чому у файлу `.pfx` є пароль, а `.pem` зазвичай без паролю?
4. Що таке SAN і чому він обов'язковий для сучасних браузерів?
5. Де знаходиться системне сховище сертифікатів у Linux? А у Windows?
6. Як перевірити термін дії встановленого сертифіката через командний рядок?

---

## Довідка — корисні команди

```bash
# === OPENSSL ===

# Генерація ключа
openssl genrsa -out key.pem 2048

# Самопідписаний сертифікат
openssl req -new -x509 -key key.pem -out cert.crt -days 365 -subj "/CN=example"

# CSR
openssl req -new -key key.pem -out request.csr -subj "/CN=example"

# Підписати CSR через CA
openssl x509 -req -in request.csr -CA ca.crt -CAkey ca.key \
    -CAcreateserial -out signed.crt -days 365 -sha256

# Перевірити ланцюг
openssl verify -CAfile ca.crt signed.crt

# Переглянути сертифікат
openssl x509 -in cert.crt -text -noout
openssl x509 -in cert.crt -noout -subject -issuer -dates -fingerprint

# Конвертація форматів
openssl x509 -in cert.crt -outform DER -out cert.der          # PEM → DER
openssl x509 -in cert.der -inform DER -outform PEM -out cert.pem # DER → PEM
openssl pkcs12 -export -in cert.crt -inkey key.pem -out cert.pfx  # PEM → PFX
openssl pkcs12 -in cert.pfx -out cert.pem -nodes                   # PFX → PEM

# TLS з'єднання
openssl s_client -connect host:443 -CAfile ca.crt
openssl s_client -connect host:443 -showcerts < /dev/null

# === LINUX СХОВИЩЕ ===
sudo cp ca.crt /usr/local/share/ca-certificates/my-ca.crt
sudo update-ca-certificates
certutil -d sql:$HOME/.pki/nssdb -A -n "My CA" -t "CT,," -i ca.crt

# === WINDOWS (PowerShell) ===
Import-Certificate -FilePath ca.crt -CertStoreLocation Cert:\CurrentUser\Root
Import-PfxCertificate -FilePath cert.pfx -CertStoreLocation Cert:\LocalMachine\My
Get-ChildItem Cert:\CurrentUser\Root | Where-Object { $_.Subject -like "*VIIT*" }

# === WINDOWS (CMD) ===
certutil -addstore Root ca.crt
certutil -store Root | findstr /i "VIIT"
certutil -viewstore Root
```

---

*Версія: 1.0 | Дата: 2026 | ВІТІ ТСА-233*
