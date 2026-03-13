# ============================================================
#  Dockerfile — nginx-сайт для лабораторної роботи tsa233.lab
#  Запускається на ПК викладача, доступний через DNS BIND
# ============================================================

FROM nginx:alpine

# Метадані образу
LABEL maintainer="MITIT Lab"
LABEL description="Тестovий сайт tsa233.lab для лабораторної роботи з DNS"

RUN rm /etc/nginx/conf.d/default.conf

# Копіюємо кастомну сторінку та конфіг nginx
COPY html/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN chown -R nginx:nginx /usr/share/nginx/html
# Відкриваємо порт 80
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
# Healthcheck — перевіряє, що nginx відповідає
