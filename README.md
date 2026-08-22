# map - 수도권 지하철 무장애 경로 안내 (PHP8 + Laravel + Nginx + MariaDB)

수도권 지하철 Open API를 활용해, 유모차/휠체어 등의 이유로 엘리베이터·에스컬레이터를 필수로
이용해야 하는 사람들에게 A역에서 B역까지의 최적 경로를 안내하는 서비스입니다. 메인 서버는
라라벨(PHP8 + Laravel 컨테이너, nginx + PHP-FPM 웹서버, MariaDB)로 구성했습니다.
형상관리는 GitHub를 사용합니다.

`dev_steeljoon/map/` 위치에 있으며, 같은 라라벨 스택으로 만들 다른 토이 프로젝트나
다른 언어 스택 프로젝트(예: `dev_python/`)는 상위 `dev_steeljoon/` 아래 형제 디렉토리로
분리해서 운영합니다. 프로젝트별로 저장소가 완전히 독립되어 있고, nginx(서브도메인 라우팅)와
MariaDB 서버만 여러 프로젝트가 공유하는 구조입니다 (아래 "서브도메인 라우팅 구조" 참고).

## 구조

```
.
├── docker-compose.yml
├── .env.example
├── docker/
│   ├── php/
│   │   ├── Dockerfile          # PHP8.2-FPM + Laravel (웹서버 없음, php-fpm만 실행)
│   │   └── entrypoint.sh       # 최초 구동 시 Laravel 프로젝트 자동 생성
│   └── nginx/
│       ├── default.conf        # 로컬용. 서브도메인별 서버 블록 + 운영 도메인 HTTP→HTTPS 리다이렉트
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
   | http://steeljoon.test/ | 프로젝트 목록 안내 JSON |
   | http://map.steeljoon.test/ | 실제 Laravel 앱 (welcome 화면) |

   - DB(호스트에서 접속 시): `localhost:3306`, 계정은 `.env`의 `DB_USERNAME` / `DB_PASSWORD`
   - DB(컨테이너 간 접속 시): host는 `db`

4. 로그 확인 / 종료

   ```bash
   docker compose logs -f app     # PHP-FPM 쪽 로그 (마이그레이션, 에러 등)
   docker compose logs -f nginx   # 웹서버 접속 로그
   docker compose down
   ```

## 로컬 도메인 설정 (steeljoon.test)

`.test`는 Laravel 진영(Valet, Herd 등)에서 로컬 개발용으로 쓰는 표준 TLD입니다. 실제 등록된
도메인과 충돌하지 않고, `.dev`처럼 브라우저가 강제로 HTTPS를 요구하지도 않아 로컬 환경에 적합합니다.
운영 도메인이 `steeljoon.store`이기 때문에, 로컬에서도 같은 이름 규칙을 따라 `steeljoon.test`를 씁니다.
Docker나 이 프로젝트 파일로는 hosts 등록을 할 수 없고, Windows에서 직접 해야 하는 작업입니다.

1. 메모장을 **관리자 권한으로 실행** (시작 메뉴에서 메모장 우클릭 → 관리자 권한으로 실행)
2. `C:\Windows\System32\drivers\etc\hosts` 파일 열기
3. 맨 아래에 다음 줄들을 추가 후 저장

   ```
   127.0.0.1 steeljoon.test
   127.0.0.1 map.steeljoon.test
   ```

   서브도메인 방식이라, 새 토이 프로젝트가 생길 때마다 그 프로젝트의 서브도메인을 여기에 한 줄씩 추가해야 합니다.

4. `docker compose up -d`로 컨테이너가 떠 있는 상태에서 브라우저로 http://map.steeljoon.test/ 접속 확인

   80번 포트가 이미 다른 프로그램(IIS, 사내 VPN 클라이언트 등)에 쓰이고 있으면 컨테이너가
   뜨지 않습니다. 이때는 `netstat -ano | findstr :80`으로 확인하고, `.env`의 `APP_PORT`를
   8080 등으로 바꾼 뒤 http://map.steeljoon.test:8080 처럼 포트를 붙여서 접속하면 됩니다.

## 서브도메인 라우팅 구조

`steeljoon.test`(로컬)/`steeljoon.store`(운영)는 프로젝트마다 서브도메인을 하나씩 쓰는 구조로 되어 있습니다. 나중에 다른 토이 프로젝트(예: 버스 경로 서비스)가 추가되면, `default.conf`/`ssl.conf`에 그 프로젝트만의 서버 블록(`bus_navi.steeljoon.test` 등)을 하나 더 추가하는 방식으로 계속 확장합니다.

- **`steeljoon.test`/`steeljoon.store` (루트 도메인)**: 실제 서비스로 보내지 않고, 어떤 서브도메인들이 있는지 안내하는 JSON만 응답합니다.
- **`map.steeljoon.test`/`map.steeljoon.store`**: 이 저장소(지하철 무장애 경로 안내)의 Laravel 앱(`src/`)으로 연결됩니다. 서브도메인이라 이 앱은 자기가 그냥 도메인 루트(`/`)에서 돌고 있다고 알면 되고, `route:cache`도 그대로 사용합니다.

`default.conf`(로컬)와 `ssl.conf`(운영)는 이 구조를 반드시 동일하게 유지해야 합니다. 한쪽만 고치면 로컬과 운영 동작이 어긋나므로, 라우팅 관련 수정은 항상 두 파일에 같이 반영합니다.

인증서는 프로젝트가 늘어날 때마다 `certbot --expand`로 그 서브도메인을 추가해야 하고, DNS(Cafe24)에도 그 서브도메인의 A레코드를 등록해야 합니다. 자세한 내용은 아래 "운영 도메인 구조" 참고.

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
   git commit -m "Initial commit: PHP8 + Laravel + Nginx + MariaDB dev env"
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
docker compose up -d --force-recreate nginx
docker compose up -d --force-recreate app
docker compose exec -T app php artisan migrate --force
docker compose exec -T app php artisan config:cache
docker compose exec -T app php artisan route:cache
docker compose exec -T app php artisan view:cache
```

- **nginx / app 강제 재생성**: `docker/nginx/*.conf`처럼 컨테이너에 파일 단위로 마운트해서 쓰는 파일은, `git pull`이 파일을 그 자리에서 덮어쓰지 않고 새 파일로 교체(unlink+생성)하기 때문에 기존 컨테이너의 마운트가 옛 파일을 계속 붙잡고 있게 됩니다. `nginx -s reload`로는 이 상태가 고쳐지지 않아 컨테이너 자체를 재생성합니다. `app` 컨테이너도 같은 이유로, 그리고 PHP-FPM 워커의 캐시 상태를 완전히 새로 시작하기 위해 재생성합니다.
- **route:cache**: 서브도메인 방식이라 이 앱은 도메인 루트(`/`)에서 정상적으로 동작하므로, 배포 때마다 `route:cache`로 라우트를 캐시합니다.

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

- **`steeljoon.store` / `www.steeljoon.store`**: `/`에서 프로젝트 목록을 안내하는 JSON만 응답합니다. 실제 서비스는 서브도메인에서 돕니다.
- **`map.steeljoon.store`**: 위 "서브도메인 라우팅 구조" 절에서 설명한 이 저장소의 Laravel 앱입니다.
- HTTPS는 Let's Encrypt(certbot) 인증서를 씁니다. 인증서/웹루트는 `docker-compose.yml`의 `certbot_etc`, `certbot_www` 볼륨으로 관리됩니다.
- `steeljoon.store` 도메인은 Cafe24에서 관리합니다. 새 서브도메인이 생기면 Cafe24 DNS 관리 화면에서 그 서브도메인의 A레코드(운영 서버 IP)를 등록해야 하고, DNS가 반영된 뒤 서버에서 `certbot --expand`로 인증서에 그 서브도메인을 추가해야 합니다. Cafe24는 DNS-01(와일드카드) 자동화를 지원하는 certbot 플러그인이 없어서, 서브도메인이 늘어날 때마다 이 과정을 한 번씩 반복합니다.
- `ssl.conf`는 로컬에는 인증서가 없어 nginx가 이 파일을 읽으면 죽기 때문에, 기본적으로 로드되지 않습니다. 운영 서버에서만 서버 전용 `docker-compose.override.yml`(이 저장소에는 포함되지 않음, `.gitignore`로 제외)에서 아래처럼 추가로 마운트해서 사용합니다.

  ```yaml
  services:
    nginx:
      volumes:
        - ./docker/nginx/ssl.conf:/etc/nginx/conf.d/ssl.conf:ro
  ```

## 참고

- GitHub + GitHub Actions로 형상관리와 배포를 구성했습니다.
- 컨테이너 안에서 artisan 명령을 쓰려면: `docker compose exec app php artisan <command>`
- `SESSION_DRIVER`는 `entrypoint.sh`에서 항상 `file`로 고정합니다. Laravel 기본값인 `database`로 두면 sessions 테이블이 없어 500 에러가 납니다.
- hosts 파일 수정, GitHub Secrets 값 입력은 파일로 대신할 수 없어 위 안내대로 직접 해야 합니다.
