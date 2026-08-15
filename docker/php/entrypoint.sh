#!/bin/bash
set -e

# 최초 실행 시에만 Laravel 프로젝트를 새로 생성한다 (이미 있으면 건너뜀)
if [ ! -f /var/www/html/artisan ]; then
    echo ">> Laravel 프로젝트가 없어 새로 생성합니다..."
    composer create-project laravel/laravel /tmp/laravel-new --prefer-dist --no-interaction
    cp -a /tmp/laravel-new/. /var/www/html/
    rm -rf /tmp/laravel-new
fi

if [ ! -f /var/www/html/.env ]; then
    cp /var/www/html/.env.example /var/www/html/.env
fi

composer install --no-interaction --optimize-autoloader

# .env DB 설정을 docker-compose 환경변수에 맞춰 갱신
sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/" /var/www/html/.env
sed -i "s/^DB_HOST=.*/DB_HOST=${DB_HOST:-db}/" /var/www/html/.env
sed -i "s/^DB_PORT=.*/DB_PORT=${DB_PORT:-3306}/" /var/www/html/.env
sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${DB_DATABASE:-laravel}/" /var/www/html/.env
sed -i "s/^DB_USERNAME=.*/DB_USERNAME=${DB_USERNAME:-laravel}/" /var/www/html/.env
sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=${DB_PASSWORD:-secret}/" /var/www/html/.env

# APP_KEY가 비어 있을 때만 새로 만든다 (매번 새로 만들면 재시작할 때마다 기존 세션/쿠키가 깨짐)
if grep -q "^APP_KEY=$" /var/www/html/.env; then
    php artisan key:generate --force
fi

# Laravel 최신 버전의 기본값은 SESSION_DRIVER=database인데, 정작 sessions 테이블
# 마이그레이션은 기본 스캐폴드에 없어서 그대로 두면 세션 접근 시 500 에러가 난다.
# php artisan session:table로 매번 해결하려 했더니 재실행 시 "Migration already exists"로
# 죽는 문제가 있어서, 회사 LAMP 스택과 더 비슷한 파일 기반 세션으로 바꿔서 근본적으로 피한다.
sed -i "s/^SESSION_DRIVER=.*/SESSION_DRIVER=file/" /var/www/html/.env

# create-project 과정에서는 sqlite 기준으로 한 번 migrate가 돌지만,
# 실제 쓰는 DB는 위에서 설정한 MariaDB(mysql)이므로 여기서 다시 migrate 한다.
php artisan migrate --force

# jQuery(레거시 방식, CDN)를 기본 웰컴 뷰에 삽입 - 회사 스택 방식 반영
if [ -f /var/www/html/resources/views/welcome.blade.php ] && ! grep -q "jquery" /var/www/html/resources/views/welcome.blade.php; then
    sed -i 's#</body>#    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>\n</body>#' /var/www/html/resources/views/welcome.blade.php
fi

chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true

# 웹서버는 nginx가 별도 컨테이너로 붙어서 이 프로세스에 요청을 넘겨준다 (FastCGI, 9000번 포트)
exec php-fpm
