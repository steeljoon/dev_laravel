# 로컬 개발 환경 (PHP8 + Laravel + Nginx + MariaDB)

회사 실무 스택(PHP8 + Laravel 컨테이너, 웹서버, MariaDB)을 로컬 Docker 환경으로 재현한 프로젝트입니다.
웹서버는 처음엔 Apache로 시작했다가 nginx + PHP-FPM 구조로 전환했습니다. 형상관리는 GitLab 대신 GitHub를 사용합니다.

`dev_steeljoon/dev_laravel/` 위치에 있으며, 다른 언어/스택 개발환경(예: `dev_python/`)은
상위 `dev_steeljoon/` 아래 형제 디렉토리로 분리해서 운영합니다.

## 구조

```
.
├── docker-compose.yml
├── .env.example
├── docker/
│   ├── php/
│   │   ├── Dockerfile          # PHP8.2-FPM + Laravel (웹서버 없음, php-fpm만 실행)
│   │   ├── entrypoint.sh       # 최초 구동 시 Laravel 프로젝트 자동 생성
│   │   └── apache-vhost.conf   # 예전 Apache 구조 흔적, 지금은 어디서도 참조하지 않음
│   └── nginx/
│       ├── default.conf        # 로컬용. api.steeljoon.test 게이트웨이 + 운영 도메인 HTTP→HTTPS 리다이렉트
│       └── ssl.conf            # 운영 서버 전용 HTTPS 설정 (아래 "운영 서버 배포" 참고)
├── src/                         # Laravel 프로젝트가 생성되는 위치 (최초 1회는 비어있음)
└── .github/workflows/deploy.yml # main push 시 운영 서버 자동 배포
```

`nginx` 컨테이너가 80/443번 포트를 받아서 정적 파일은 직접 서빙하고, `.php` 요청만 `app` 컨테이너(PHP-FPM, 9000번 포트)로 넘깁니다.

## 사전 준비

- Docker Desktop (WSL2 백엔드) - 설치 완료
- VS Code - 설치 완료

## 실행 방법

1. 환경 변수 파일 생성

   ```bash
   cp .env.example .env
   ```

   필요하면 `.env`의 포트/DB 계정 값을 수정합니다.

2. 빌드 및 실행

   ```bash
   docker compose up --build -d
   ```

   최초 실행 시 컨테이너 안에서 `composer create-project laravel/laravel`이 자동으로 실행되어
   `src/` 폴더에 실제 Laravel 프로젝트 파일이 생성됩니다. 이 과정은 인터넷 상황에 따라 수 분이 걸릴 수 있습니다.

3. 접속 확인 (아래 "로컬 도메인 설정"을 먼저 해야 합니다)

   | 주소 | 응답 |
   |---|---|
   | http://api.steeljoon.test/ | 사용 가능한 경로 안내 JSON |
   | http://api.steeljoon.test/laravel/ | 실제 Laravel 앱 (welcome 화면) |
   | http://api.steeljoon.test/python/ | 자리표시 JSON (Python 서비스는 아직 붙지 않음) |

   - DB(호스트에서 접속 시): `localhost:3306`, 계정은 `.env`의 `DB_USERNAME` / `DB_PASSWORD`
   - DB(컨테이너 간 접속 시): host는 `db`

4. 로그 확인 / 종료

   ```bash
   docker compose logs -f app     # PHP-FPM 쪽 로그 (마이그레이션, 에러 등)
   docker compose logs -f nginx   # 웹서버 접속 로그
   docker compose down
   ```

## 로컬 도메인 설정 (api.steeljoon.test)

`.test`는 Laravel 진영(Valet, Herd 등)에서 로컬 개발용으로 쓰는 표준 TLD입니다. 실제 등록된
도메인과 충돌하지 않고, `.dev`처럼 브라우저가 강제로 HTTPS를 요구하지도 않아 로컬 환경에 적합합니다.
운영 도메인이 `steeljoon.store`이기 때문에, 로컬에서도 같은 이름 규칙을 따라 `api.steeljoon.test`를 씁니다.
Docker나 이 프로젝트 파일로는 hosts 등록을 할 수 없고, Windows에서 직접 해야 하는 작업입니다.

1. 메모장을 **관리자 권한으로 실행** (시작 메뉴에서 메모장 우클릭 → 관리자 권한으로 실행)
2. `C:\Windows\System32\drivers\etc\hosts` 파일 열기
3. 맨 아래에 다음 줄 추가 후 저장

   ```
   127.0.0.1 api.steeljoon.test
   ```

4. `docker compose up -d`로 컨테이너가 떠 있는 상태에서 브라우저로 http://api.steeljoon.test/ 접속 확인

   80번 포트가 이미 다른 프로그램(IIS, 사내 VPN 클라이언트 등)에 쓰이고 있으면 컨테이너가
   뜨지 않습니다. 이때는 `netstat -ano | findstr :80`으로 확인하고, `.env`의 `APP_PORT`를
   8080 등으로 바꾼 뒤 http://api.steeljoon.test:8080 처럼 포트를 붙여서 접속하면 됩니다.

## API 게이트웨이 구조 (`/laravel`, `/python`)

`api.steeljoon.test`(로컬)와 `api.steeljoon.store`(운영)는 하나의 도메인 아래에서 경로(path)로 서비스를 구분하는 게이트웨이 형태로 되어 있습니다.

- **`/` (루트)**: 실제 서비스로 보내지 않고, 어떤 경로를 쓸 수 있는지 안내하는 JSON만 응답합니다. 방문자가 도메인만 입력했을 때 라라벨 화면이 뜨는 것을 막기 위한 의도적인 설계입니다.
- **`/laravel/`**: 이 저장소의 Laravel 앱(`src/`)으로 연결됩니다. nginx가 `SCRIPT_NAME`을 `/laravel/index.php`로 지정해서 넘기면, Laravel(Symfony)이 요청 URI와 SCRIPT_NAME을 비교해 자기 base path를 `/laravel`로 스스로 계산합니다. 이 방식 덕분에 nginx 쪽 변수를 억지로 덮어쓰지 않고도 `/laravel/xxx` 형태의 하위 경로가 안정적으로 라우팅됩니다.
- **`/python/`**: 아직 실제 서비스가 없어 자리표시 JSON만 응답합니다. 나중에 Python 컨테이너를 추가하면 이 위치에 `proxy_pass`로 교체하면 됩니다.

`default.conf`(로컬)와 `ssl.conf`(운영)는 이 구조를 반드시 동일하게 유지해야 합니다. 한쪽만 고치면 로컬과 운영 동작이 어긋나므로, 라우팅 관련 수정은 항상 두 파일에 같이 반영합니다.

## jQuery

회사 스택과 동일하게 CDN 방식으로 붙였습니다. 최초 구동 시 `resources/views/welcome.blade.php`에
jQuery CDN 스크립트 태그가 자동으로 삽입됩니다. 다른 뷰에서 쓰려면 레이아웃 blade 파일에 아래 한 줄을 추가하면 됩니다.

```html
<script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
```

## GitHub 연동

1. GitHub에서 새 저장소 생성 (README/gitignore 없이 빈 저장소로)
2. 아래 명령으로 초기 커밋 및 푸시

   ```bash
   git add .
   git commit -m "Initial commit: PHP8 + Laravel + Apache + MariaDB dev env"
   git branch -M main
   git remote add origin https://github.com/<github-id>/<repo-name>.git
   git push -u origin main
   ```

   `src/vendor`, `src/node_modules`, `.env` 등은 `.gitignore`에 이미 제외되어 있습니다.

## 운영 서버 배포 (GitHub Actions)

운영 서버(AWS Lightsail, ap-northeast-2)도 로컬과 동일하게 Docker Compose로 떠 있습니다. `main` 브랜치에 push하면 `.github/workflows/deploy.yml`이 SSH로 운영 서버에 접속해 아래 순서를 자동으로 수행합니다.

```bash
git pull origin main
docker compose up -d --build
docker compose exec -T nginx nginx -s reload
docker compose exec -T app php artisan migrate --force
docker compose exec -T app php artisan config:cache
docker compose exec -T app php artisan route:cache
docker compose exec -T app php artisan view:cache
```

`nginx -s reload` 단계가 중요합니다. `docker/nginx/*.conf`처럼 컨테이너에 그대로 마운트해서 쓰는 파일은 내용만 바뀌었을 뿐 컨테이너 자체 정의는 안 바뀌기 때문에, `docker compose up -d`만으로는 nginx가 새 설정을 읽지 않습니다. 이 단계가 그걸 강제로 다시 읽게 만듭니다.

1. 배포용 SSH 키 생성 (로컬 아무 터미널에서)

   ```bash
   ssh-keygen -t ed25519 -C "github-actions-deploy" -f deploy_key
   ```

   - `deploy_key` (개인키): GitHub Secret으로 등록
   - `deploy_key.pub` (공개키): 운영 서버의 `~/.ssh/authorized_keys`에 추가

2. GitHub 저장소 → Settings → Secrets and variables → Actions에서 아래 Secret 등록

   | Secret 이름 | 값 |
   |---|---|
   | `DEPLOY_HOST` | 운영 서버 IP 또는 도메인 |
   | `DEPLOY_USER` | 배포용 SSH 계정 |
   | `DEPLOY_SSH_KEY` | 위에서 만든 `deploy_key` 개인키 내용 전체 |
   | `DEPLOY_PORT` | SSH 포트 (기본 22면 22) |
   | `DEPLOY_PATH` | 서버에서 저장소가 clone된 경로 (예: `/var/www/myapp`) |

3. `main`에 push하면 Actions 탭에서 배포 진행 상황을 확인할 수 있습니다. Actions 탭에서 수동으로
   재실행(`workflow_dispatch`)도 가능합니다.

## 운영 도메인 구조

- **`steeljoon.store` / `www.steeljoon.store`**: 메인 Laravel 사이트. `/` 그대로 라라벨 앱으로 연결됩니다.
- **`api.steeljoon.store`**: 위 "API 게이트웨이 구조" 절에서 설명한 것과 동일한 구조(`/laravel/`, `/python/`)입니다.
- HTTPS는 Let's Encrypt(certbot) 인증서를 씁니다. 인증서/웹루트는 `docker-compose.yml`의 `certbot_etc`, `certbot_www` 볼륨으로 관리됩니다.
- `ssl.conf`는 로컬에는 인증서가 없어 nginx가 이 파일을 읽으면 죽기 때문에, 기본적으로 로드되지 않습니다. 운영 서버에서만 서버 전용 `docker-compose.override.yml`(이 저장소에는 포함되지 않음, `.gitignore`로 제외)에서 아래처럼 추가로 마운트해서 사용합니다.

  ```yaml
  services:
    nginx:
      volumes:
        - ./docker/nginx/ssl.conf:/etc/nginx/conf.d/ssl.conf:ro
  ```

## 참고

- GitLab 대신 GitHub + GitHub Actions로 형상관리와 배포를 구성했습니다.
- 웹서버는 Apache에서 nginx + PHP-FPM 구조로 바꿨습니다. `docker/php/apache-vhost.conf`는 예전 흔적으로 더 이상 쓰이지 않습니다.
- 컨테이너 안에서 artisan 명령을 쓰려면: `docker compose exec app php artisan <command>`
- `SESSION_DRIVER`는 `entrypoint.sh`에서 항상 `file`로 고정합니다. Laravel 최신 버전 기본값인 `database`로 두면 sessions 테이블이 기본 스캐폴드에 없어 500 에러가 나는 문제가 있었습니다.
- hosts 파일 수정, GitHub Secrets 값 입력은 파일로 대신할 수 없어 위 안내대로 직접 해야 합니다.
- 2026-08-16: steeljoon.store HTTPS 배포 및 GitHub Actions 자동 배포 파이프라인 동작 확인.
- 2026-08-17: `api.steeljoon.test`/`api.steeljoon.store`를 `/laravel`, `/python` 경로 기반 게이트웨이 구조로 재구성. `laravel.test` 도메인은 더 이상 쓰지 않습니다.
