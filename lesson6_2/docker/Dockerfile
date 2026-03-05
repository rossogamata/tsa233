# ============================================================
#  Dockerfile — nginx-сайт для лабораторної роботи tsa233.lab
#  Запускається на ПК викладача, доступний через DNS BIND
# ============================================================

FROM nginx:alpine

# Метадані образу
LABEL maintainer="MITIT Lab"
LABEL description="Тестovий сайт tsa233.lab для лабораторної роботи з DNS"

# Копіюємо кастомну сторінку та конфіг nginx
COPY html/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Відкриваємо порт 80
EXPOSE 80

# Healthcheck — перевіряє, що nginx відповідає
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1
