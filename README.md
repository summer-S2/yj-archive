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
├── app-web/           # 프로젝트별 작업 메모
│   ├── CHECKLIST.md   # 작업 체크리스트
│   ├── templates/     # SPEC.md / PLAN.md 템플릿
│   └── 기능명/        # 기능별 SPEC.md / PLAN.md
└── fa/                # 프로젝트별 작업 메모
```

---

## 처음 클론한 뒤 (필수)

```bash
git config core.hooksPath .githooks
cp scripts/public-guard-patterns.example .public-guard-patterns   # 로컬 금지어 목록 작성 (커밋되지 않음)
```

---

## 작업 메모 쓰는 법

1. 해당 폴더의 `CHECKLIST.md` 확인
2. `기능명/` 폴더 생성 (이슈 번호 사용 금지)
3. `templates/SPEC.md` 형식으로 `SPEC.md` 작성
4. `templates/PLAN.md` 형식 + `SPEC.md` 내용으로 `PLAN.md` 작성
