# 로컬 개발 환경 (PHP8 + Laravel + Apache + MariaDB)

회사 실무 스택(PHP8 + Laravel 컨테이너, Apache, MariaDB)을 로컬 Docker 환경으로 재현한 프로젝트입니다.
형상관리는 GitLab 대신 GitHub를 사용합니다.

`dev_steeljoon/dev_laravel/` 위치에 있으며, 다른 언어/스택 개발환경(예: `dev_python/`)은
상위 `dev_steeljoon/` 아래 형제 디렉토리로 분리해서 운영합니다.

## 구조

```
.
├── docker-compose.yml
├── .env.example
├── docker/
│   └── php/
│       ├── Dockerfile          # PHP8.2 + Apache + Laravel
│       ├── apache-vhost.conf   # DocumentRoot -> public/
│       └── entrypoint.sh       # 최초 구동 시 Laravel 프로젝트 자동 생성
└── src/                        # Laravel 프로젝트가 생성되는 위치 (최초 1회는 비어있음)
```

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

3. 접속 확인

   - 웹: http://laravel.test (아래 "로컬 도메인 설정"을 먼저 해야 합니다. 안 했다면 http://localhost 로도 접속됩니다)
   - DB(호스트에서 접속 시): `localhost:3306`, 계정은 `.env`의 `DB_USERNAME` / `DB_PASSWORD`
   - DB(컨테이너 간 접속 시): host는 `db`

4. 로그 확인 / 종료

   ```bash
   docker compose logs -f app
   docker compose down
   ```

## 로컬 도메인 설정 (laravel.test)

`.test`는 Laravel 진영(Valet, Herd 등)에서 로컬 개발용으로 쓰는 표준 TLD입니다. 실제 등록된
도메인과 충돌하지 않고, `.dev`처럼 브라우저가 강제로 HTTPS를 요구하지도 않아 로컬 환경에 적합합니다.
`laravel.test`로 접속하려면 Windows hosts 파일에 한 줄을 추가해야 합니다. Docker나 이 프로젝트
파일로는 할 수 없고, Windows에서 직접 해야 하는 작업입니다.

1. 메모장을 **관리자 권한으로 실행** (시작 메뉴에서 메모장 우클릭 → 관리자 권한으로 실행)
2. `C:\Windows\System32\drivers\etc\hosts` 파일 열기
3. 맨 아래에 다음 줄 추가 후 저장

   ```
   127.0.0.1 laravel.test
   127.0.0.1 www.laravel.test
   ```

4. `docker compose up -d`로 컨테이너가 떠 있는 상태에서 브라우저로 http://laravel.test 접속 확인

   80번 포트가 이미 다른 프로그램(IIS, 사내 VPN 클라이언트 등)에 쓰이고 있으면 컨테이너가
   뜨지 않습니다. 이때는 `netstat -ano | findstr :80`으로 확인하고, `.env`의 `APP_PORT`를
   8080 등으로 바꾼 뒤 http://laravel.test:8080 처럼 포트를 붙여서 접속하면 됩니다.

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

GitLab CI로 하던 배포를 `.github/workflows/deploy.yml`로 옮겨뒀습니다. `main` 브랜치에 push하면
GitHub Actions가 SSH로 운영 서버에 접속해 `git pull` → `composer install` → `migrate` → 캐시 갱신을
자동으로 수행합니다.

**전제:** 운영 서버에 이 GitHub 저장소가 이미 `git clone`되어 있고, 서버 안에 PHP/Composer가
설치되어 있는 방식(회사 GitLab CI와 동일한 방식)입니다. 운영 서버도 Docker로 띄우는 구조라면
`git pull` 대신 이미지를 빌드해서 레지스트리에 push하고 서버에서 pull하는 방식으로 바꿔야 하니,
서버 환경을 알려주시면 그에 맞게 다시 구성해 드릴 수 있습니다.

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

## 참고

- GitLab 대신 GitHub + GitHub Actions로 형상관리와 배포를 구성했습니다.
- 컨테이너 안에서 artisan 명령을 쓰려면: `docker compose exec app php artisan <command>`
- hosts 파일 수정, GitHub Secrets 값 입력은 파일로 대신할 수 없어 위 안내대로 직접 해야 합니다.
