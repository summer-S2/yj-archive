# yj-archive

개인 작업 아카이브. 개발하면서 정리한 가이드, 작업 절차, 기능별 기획·구현 메모를 모아 두는 곳이다. 실제 코드는 여기 없다.

> 이 레포는 **public**이다. 작성·커밋 규칙은 [CLAUDE.md](./CLAUDE.md)를 따른다.
> 커밋·push 시 `scripts/check-public.sh` 검사가 자동으로 실행되며, 통과하지 못하면 커밋·push가 차단된다.

---

## 폴더 구조

```
yj-archive/
├── CLAUDE.md          # 작성·커밋 규칙 (public 레포 규칙 포함)
├── README.md          # 이 파일
├── .githooks/         # pre-commit / pre-push 훅
├── scripts/           # 공개 정보 검사 스크립트
├── mobile-release/    # React Native iOS/Android 빌드·배포 가이드
├── react-router/      # React Router 관련 정리
├── frontend-deploy/   # 프론트 배포·도메인 연결 정리
├── app-web/           # 프로젝트별 작업 메모
│   ├── CHECKLIST.md   # 작업 체크리스트
│   ├── templates/     # SPEC.md / PLAN.md 템플릿
│   └── 기능명/        # 기능별 SPEC.md / PLAN.md
├── fa/                # 프로젝트별 작업 메모
└── sqld/              # SQLD 자격증 기출 개념 정리
```

---

## 처음 클론한 뒤 (필수)

```bash
git config core.hooksPath .githooks
```

---

## 커밋·push 전 체크 사항

### 자동 검사 (`scripts/check-public.sh` — 커밋·push 시 훅이 실행)

- 로컬 절대경로 (`/Users/…`, `/home/…`)
- 이슈·MR 번호 (`#<번호>`, 이슈·MR URL)
- 브랜치명 (`feature/…`, `fix/…` 등)
- 번들 ID·패키지명, 스토어 앱 ID, Firebase 앱 ID
- 기기 UDID, IP 주소
- 이메일, 전화번호, 주민번호
- 키·토큰, 비밀번호·PIN·서명 정보
- 허용 목록(`scripts/url-allowlist.txt`)에 없는 URL
- 이미지 등 바이너리 파일 (직접 열어 본 뒤 `PUBLIC_GUARD_REVIEWED_BINARIES=1`로 통과)

### 직접 확인 (자동 검사로 못 잡음 — 파일을 전부 읽고 확인)

- 회사명·서비스명·앱 이름·제품명, 이름에 이들이 들어간 코드 식별자·파일 경로
- 회사 레포·GitHub 조직·내부 프로젝트 이름
- 제휴사·증권사·데이터 제공처·외부 업체명
- 내부 코드 체계 (약관 코드, 상태 코드, 화면 ID 등)
- 사람 이름
- 사용 중인 보안 솔루션·분석 도구 구성
- 실제 데이터 (고객·종목 보유 내역, 내부 집계 수치, 실제 포트폴리오 샘플)
- 이미지·HTML 안의 위 항목

대신 쓸 표현은 [CLAUDE.md](./CLAUDE.md)의 public 레포 규칙 표를 따른다.

---

## 작업 메모 쓰는 법

1. 해당 폴더의 `CHECKLIST.md` 확인
2. `기능명/` 폴더 생성 (이슈 번호 사용 금지)
3. `templates/SPEC.md` 형식으로 `SPEC.md` 작성
4. `templates/PLAN.md` 형식 + `SPEC.md` 내용으로 `PLAN.md` 작성
