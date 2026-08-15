# 프로젝트 배경

회사 실무 개발 환경(PHP8 + Laravel, jQuery, 웹서버, MariaDB, Docker, GitLab)을 개인 로컬 환경에 그대로 재현한 프로젝트입니다. 형상관리만 GitLab 대신 GitHub를 씁니다. 웹서버는 처음 Apache로 시작했다가 nginx + PHP-FPM 구조로 바꿨습니다.

## 위치와 구조

프로젝트 루트는 `C:\dev_steeljoon\dev_laravel` 입니다 (다른 언어 스택을 추가하면 `dev_steeljoon` 아래 형제 디렉토리로 분리할 예정, 예: `dev_python`).

```
dev_laravel/
├── docker-compose.yml       # nginx + app(PHP8-FPM+Laravel) + db(MariaDB) 3개 서비스
├── .env.example              # APP_PORT, DB_* 값 (복사해서 .env로 사용)
├── .gitignore
├── README.md                 # 실행 방법, 도메인 설정, 배포 설정 안내 전부 포함
├── docker/
│   ├── php/
│   │   ├── Dockerfile        # php:8.2-fpm 기반, pdo_mysql/mbstring/gd/zip 등 설치
│   │   ├── apache-vhost.conf # 예전 Apache 구조 흔적, 지금은 어디서도 참조 안 함
│   │   └── entrypoint.sh     # 컨테이너 기동 시 실행되는 스크립트 (아래 참고)
│   └── nginx/
│       └── default.conf      # ServerName laravel.test, DocumentRoot -> public/, .php는 app:9000으로 fastcgi_pass
├── src/                       # Laravel 프로젝트 실체 (컨테이너가 최초 실행될 때 자동 생성됨, git으로 관리)
└── .github/workflows/deploy.yml   # main push 시 SSH로 운영 서버 배포
```

## entrypoint.sh 핵심 로직 (중요, 여러 번 디버깅한 부분)

1. `artisan` 파일이 없으면 `composer create-project laravel/laravel`로 최초 1회 생성
2. `.env`의 `DB_*` 값을 docker-compose 환경변수(MariaDB 접속 정보)로 덮어씀
3. `APP_KEY`는 비어있을 때만 생성 (매번 새로 만들면 재시작마다 세션이 깨짐)
4. **`SESSION_DRIVER`는 반드시 `file`로 고정** — Laravel 최신 버전 기본값인 `database`로 두면 sessions 테이블 마이그레이션이 기본 스캐폴드에 없어서 500 에러가 나고, `php artisan session:table`로 자동 생성하려 하면 재실행 시 "Migration already exists"로 죽어서 컨테이너가 무한 재시작하는 문제가 있었음. 이 방식으로 근본적으로 회피함.
5. 매번 `php artisan migrate --force`로 MariaDB에 마이그레이션 적용 (users/cache/jobs 테이블)
6. jQuery는 CDN 방식으로 `resources/views/welcome.blade.php`에 자동 삽입 (회사 스택과 동일하게 npm/Vite 없이 legacy 방식 사용)
7. 마지막 줄은 `exec apache2-foreground`가 아니라 `exec php-fpm` — 웹서버(nginx)가 별도 컨테이너로 분리됐기 때문에 이 컨테이너는 PHP-FPM 프로세스만 포그라운드로 띄움

## 로컬 도메인

`www.dev.coz`는 회사 내부 주소라 쓰지 않기로 했고, Laravel 진영 표준인 `laravel.test`로 접속하도록 구성했습니다 (Windows hosts 파일에 `127.0.0.1 laravel.test` 등록 필요, 이미 완료됨). 포트는 80번을 그대로 사용합니다.

## 배포 (GitHub Actions)

`.github/workflows/deploy.yml`은 `main` 브랜치 push 시 SSH로 운영 서버에 접속해 `git pull` → `composer install` → `migrate` → 캐시 재생성을 하는 방식입니다. **이건 운영 서버가 Docker가 아니라 서버에 직접 PHP가 설치된 전통적인 방식이라는 가정 하에 만든 것**이라, 실제 운영 서버가 Docker 기반이면 이미지 빌드 후 push/pull하는 방식으로 다시 설계해야 합니다. 아직 확인 안 된 부분입니다.

## 현재 상태

Apache 구조에서는 `docker compose up --build -d` 후 http://laravel.test 접속까지 정상 확인했습니다. 방금 nginx + PHP-FPM 구조로 바꿨는데, 이 변경 이후로는 아직 재빌드/재확인 전입니다. 이 프로젝트를 열면 가장 먼저 `docker compose up --build -d`로 새 이미지를 빌드하고 http://laravel.test 접속이 정상인지, `docker compose logs nginx`와 `docker compose logs app`에 에러가 없는지 확인해 주세요.
