# Встановлення Git та робота з репозиторієм

> **Курс:** Технології системного адміністрування (ТСА-233)
> **Аудиторія:** Курсанти 3 курсу ВІТІ

---

## Зміст

1. [Встановлення Git на Windows](#1-встановлення-git-на-windows)
2. [Встановлення Git на Linux](#2-встановлення-git-на-linux)
3. [Первинне налаштування Git](#3-первинне-налаштування-git)
4. [Клонування репозиторію](#4-клонування-репозиторію)
5. [Основи роботи з репозиторієм](#5-основи-роботи-з-репозиторієм)

---

## 1. Встановлення Git на Windows

### 1.1 Завантаження інсталятора

1. Перейдіть на офіційний сайт: **https://git-scm.com/download/win**
2. Завантаження почнеться автоматично (64-bit версія)
3. Запустіть завантажений файл `Git-X.XX.X-64-bit.exe`

### 1.2 Процес встановлення

Під час встановлення залиште всі параметри за замовчуванням, окрім:

- **Choosing the default editor** — рекомендується вибрати `Notepad++` або `Visual Studio Code` (якщо встановлені), або залишити `Vim`
- **Adjusting your PATH environment** — оберіть `Git from the command line and also from 3rd-party software` (рекомендовано)
- **Configuring line ending conversions** — оберіть `Checkout Windows-style, commit Unix-style line endings`

### 1.3 Перевірка встановлення

Відкрийте **Command Prompt** або **PowerShell** та введіть:

```cmd
git --version
```

Очікуваний вивід:
```
git version 2.47.0.windows.2
```

> Після встановлення Git з'являться два нових застосунки: **Git Bash** (термінал з bash-оболонкою) та **Git GUI** (графічний інтерфейс).

---

## 2. Встановлення Git на Linux

### 2.1 Ubuntu / Debian

```bash
# Оновити список пакетів
sudo apt update

# Встановити Git
sudo apt install -y git

# Перевірити встановлення
git --version
```

### 2.2 CentOS / RHEL / Fedora

```bash
# CentOS / RHEL 8+
sudo dnf install -y git

# Або для старіших версій
sudo yum install -y git

# Перевірити встановлення
git --version
```

### 2.3 Arch Linux

```bash
sudo pacman -S git
```

### 2.4 Встановлення останньої версії з джерела (Ubuntu)

Якщо пакетний менеджер надає застарілу версію:

```bash
sudo add-apt-repository ppa:git-core/ppa
sudo apt update
sudo apt install -y git
```

---

## 3. Первинне налаштування Git

Після встановлення необхідно вказати своє ім'я та email — вони будуть відображатись у кожному коміті.

```bash
# Вказати ім'я (замінити на своє)
git config --global user.name "Іваненко Іван"

# Вказати email
git config --global user.email "ivanov@example.com"

# Перевірити налаштування
git config --list
```

> Прапор `--global` застосовує налаштування до всіх репозиторіїв на цьому комп'ютері. Без нього — лише для поточного репозиторію.

---

## 4. Клонування репозиторію

### 4.1 Клонування через HTTPS

```bash
# Синтаксис
git clone <URL репозиторію>

# Приклад
git clone https://github.com/rossogamata/tsa233.git
```

Після виконання команди буде створена папка `tsa233/` з усім вмістом репозиторію.

### 4.2 Клонування у конкретну папку

```bash
# Клонувати у папку з іншою назвою
git clone https://github.com/rossogamata/tsa233.git my_folder

# Клонувати у поточну директорію (крапка в кінці)
git clone https://github.com/rossogamata/tsa233.git .
```

### 4.3 Клонування через SSH (рекомендовано)

SSH-клонування швидше та не вимагає введення пароля щоразу.

**Крок 1 — Згенерувати SSH-ключ (якщо ще немає):**

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# Натискайте Enter для всіх запитань (залишити значення за замовчуванням)
```

**Крок 2 — Скопіювати публічний ключ:**

```bash
# Linux
cat ~/.ssh/id_ed25519.pub

# Windows (Git Bash)
cat ~/.ssh/id_ed25519.pub
```

**Крок 3 — Додати ключ до GitHub:**

1. Перейдіть на **GitHub → Settings → SSH and GPG keys → New SSH key**
2. Вставте вміст публічного ключа → **Add SSH key**

**Крок 4 — Клонувати через SSH:**

```bash
git clone git@github.com:rossogamata/tsa233.git
```

### 4.4 Перевірка після клонування

```bash
# Перейти в клоновану папку
cd tsa233

# Переглянути структуру
ls -la

# Переглянути інформацію про репозиторій
git remote -v
git log --oneline -5
```

---

## 5. Основи роботи з репозиторієм

### 5.1 Отримання оновлень

```bash
# Завантажити останні зміни з серверу
git pull

# Або більш явно
git pull origin main
```

### 5.2 Перегляд стану репозиторію

```bash
# Показати змінені файли
git status

# Показати всі відмінності
git diff

# Переглянути історію комітів
git log --oneline
```

### 5.3 Збереження змін (коміт)

```bash
# Крок 1 — Додати файли до індексу (staging area)
git add filename.txt        # конкретний файл
git add .                   # всі змінені файли

# Крок 2 — Зробити коміт із повідомленням
git commit -m "Опис змін"

# Крок 3 — Надіслати зміни на сервер
git push origin main
```

### 5.4 Робота з гілками

```bash
# Переглянути поточну гілку
git branch

# Створити нову гілку
git branch my-feature

# Перейти на гілку
git checkout my-feature

# Створити і одразу перейти (скорочений запис)
git checkout -b my-feature

# Злити гілку в main
git checkout main
git merge my-feature
```

### 5.5 Скасування змін

```bash
# Скасувати зміни у файлі (до останнього коміту)
git checkout -- filename.txt

# Скасувати git add (прибрати файл з індексу)
git restore --staged filename.txt

# Переглянути коміт без скасування (тільки читання)
git show <hash коміту>
```

### 5.6 Корисні команди

| Команда | Дія |
|---------|-----|
| `git clone <url>` | Клонувати репозиторій |
| `git pull` | Отримати та злити зміни з сервера |
| `git status` | Показати стан робочої директорії |
| `git add .` | Додати всі зміни до індексу |
| `git commit -m "msg"` | Зберегти зміни в локальний репозиторій |
| `git push` | Надіслати зміни на сервер |
| `git log --oneline` | Коротка історія комітів |
| `git diff` | Показати незбережені зміни |
| `git branch` | Список гілок |
| `git checkout -b <name>` | Створити і перейти на нову гілку |

---

> Матеріал підготовлено для навчальних занять ВІТІ.
