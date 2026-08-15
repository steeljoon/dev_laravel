FROM php:8.2-fpm

# 실무 스택 기준 확장 모듈 설치 (웹서버는 nginx가 따로 담당, 이 컨테이너는 PHP-FPM만 실행)
RUN apt-get update && apt-get install -y \
        git \
        unzip \
        zip \
        curl \
        libzip-dev \
        libpng-dev \
        libonig-dev \
        libxml2-dev \
        default-mysql-client \
    && docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd zip \
    && rm -rf /var/lib/apt/lists/*

# Composer 설치
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# 컨테이너 최초 구동 시 Laravel 프로젝트 자동 생성 스크립트
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

ENTRYPOINT ["entrypoint.sh"]
