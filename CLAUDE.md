# 프로젝트 배경

수도권 지하철 Open API를 활용해, 유모차/휠체어 등의 이유로 엘리베이터·에스컬레이터를 필수로
이용해야 하는 사람들에게 A역에서 B역까지의 최적 경로를 안내하는 서비스입니다. 메인 서버는
PHP8 + Laravel + nginx(PHP-FPM 구조) + MariaDB로 구성했습니다. 형상관리는 GitHub를 씁니다.

같은 라라벨 스택으로 만드는 다른 토이 프로젝트나 다른 언어 스택 프로젝트(예: `dev_python/`)는
`dev_steeljoon/` 아래 형제 디렉토리로 분리해서 운영합니다. 프로젝트별로 저장소는 완전히
독립되어 있고, nginx 게이트웨이와 MariaDB 서버만 여러 프로젝트가 공유하는 구조입니다.

## 위치와 구조

프로젝트 루트는 `C:\dev_steeljoon\map` 입니다.

```
map/
├── docker-compose.yml       # nginx + app(PHP8-FPM+Laravel) + db(MariaDB) + certbot 서비스
├── .env.example              # APP_PORT, DB_*, COMPOSE_PROJECT_NAME 값 (복사해서 .env로 사용)
├── .gitignore
├── README.md                 # 실행 방법, 도메인 설정, 배포 설정 안내 전부 포함
├── docker/
│   ├── php/
│   │   ├── Dockerfile        # php:8.2-fpm 기반, pdo_mysql/mbstring/gd/zip 등 설치
│   │   └── entrypoint.sh     # 컨테이너 기동 시 실행되는 스크립트 (아래 참고)
│   └── nginx/
│       ├── default.conf      # 로컬용. 서브도메인별 서버 블록 (steeljoon.test, map.steeljoon.test)
│       └── ssl.conf          # 운영 서버 전용 HTTPS 설정 (steeljoon.store, map.steeljoon.store)
├── src/                       # Laravel 프로젝트 실체 (컨테이너가 최초 실행될 때 자동 생성됨, git으로 관리)
└── .github/workflows/deploy.yml   # main push 시 SSH로 운영 서버(Docker Compose) 배포
```

## entrypoint.sh 핵심 로직 (중요, 여러 번 디버깅한 부분)

1. `artisan` 파일이 없으면 `composer create-project laravel/laravel`로 최초 1회 생성
2. `.env`의 `DB_*` 값을 docker-compose 환경변수(MariaDB 접속 정보)로 덮어씀
3. `APP_KEY`는 비어있을 때만 생성 (매번 새로 만들면 재시작마다 세션이 깨짐)
4. **`SESSION_DRIVER`는 반드시 `file`로 고정** — Laravel 기본값인 `database`는 sessions 테이블이 기본 스캐폴드에 없어 500 에러가 남
5. 매번 `php artisan migrate --force`로 MariaDB에 마이그레이션 적용 (users/cache/jobs 테이블)
6. jQuery는 CDN 방식으로 `resources/views/welcome.blade.php`에 자동 삽입 (npm/Vite 없이 legacy 방식 사용)
7. 마지막 줄은 `exec php-fpm` — 웹서버(nginx)가 별도 컨테이너로 분리되어 있어 이 컨테이너는 PHP-FPM 프로세스만 포그라운드로 띄움

## 서브도메인 라우팅 구조

`steeljoon.test`(로컬)/`steeljoon.store`(운영)는 프로젝트마다 서브도메인을 하나씩 쓰는
구조입니다. `map.steeljoon.test`/`map.steeljoon.store`가 이 저장소의
Laravel 앱으로 연결되고, 서브도메인이라 이 앱은 자기가 그냥 도메인 루트("/")에서 돌고
있다고 알면 됩니다. base path를 속이는 트릭이 필요 없어 `route:cache`도 그대로 씁니다.

새 토이 프로젝트가 생기면 `default.conf`/`ssl.conf`에 서버 블록을 하나 더 추가하고,
운영은 Cafe24 DNS에 그 서브도메인 A레코드를 등록한 뒤 `certbot --expand`로 인증서에
추가해야 합니다 (Cafe24는 와일드카드 인증서용 DNS-01 자동화를 지원하지 않음). 자세한
내용은 README.md 참고.

## DB 구성

로컬/운영 각각 MariaDB 컨테이너 한 대만 두고, 프로젝트별로 데이터베이스와 계정을 나눕니다.
지금은 `map` 데이터베이스/계정 하나뿐이지만, 다른 프로젝트가 추가되면 같은 MariaDB
서버 안에 데이터베이스/계정만 추가하고 서버 자체는 공유합니다. `COMPOSE_PROJECT_NAME`,
`DB_DATABASE`도 로컬은 `dev_` 접두어, 운영은 `prod_` 접두어를 붙입니다.

## 배포 (GitHub Actions)

`.github/workflows/deploy.yml`은 `main` 브랜치 push 시 SSH로 운영 서버(Docker Compose 기반)에
접속해 `git pull` → `docker compose up -d --build` → nginx/app 컨테이너 강제 재생성 →
`migrate`/`config:cache`/`route:cache`/`view:cache`를 실행합니다. 강제 재생성이 필요한 이유는
nginx 설정 파일의 bind mount가 파일 교체 후에도 기존 컨테이너에 옛 파일을 물고 있는 문제,
PHP-FPM 워커의 캐시 상태 때문입니다. 자세한 내용은 README.md의 "운영 서버 배포" 절 참고.
