FROM php:8.4.5-apache

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends git libzip-dev zip && \
    docker-php-ext-install pdo pdo_mysql zip && \
    rm -rf /var/lib/apt/lists/*

# Clone application
RUN git clone https://github.com/dansarpong/todo-php.git /var/www/todo-app

# Configure Apache
COPY apache-config.conf /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD curl -f http://localhost:80 || exit 1
