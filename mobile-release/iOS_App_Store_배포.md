# React Native iOS 앱 App Store 배포

버전 올리기 → Archive → Upload → App Store Connect 심사 제출까지의 전체 절차.

> 표기 규칙: `<...>`는 프로젝트마다 다른 값으로 바꿔서 사용
> - `<프로젝트 경로>`, `<워크스페이스>`, `<prod 스킴>`, `<prod 번들 ID>`

---

## 전체 흐름 한눈에

```
1. 버전 올리기
2. pod install → (필요 시) bitcode 제거
3. Xcode Archive
4. Distribute App → Upload
5. App Store Connect 빌드 처리 대기 (10~30분)
6. (선택) TestFlight 내부 테스트
7. 배포(App Store) 탭에서 새 버전 만들고 빌드 선택 → 심사 제출
8. 심사 통과 → 출시
```

> ⚠️ **TestFlight ≠ 심사 제출.** 업로드하면 빌드가 TestFlight에 뜨지만, 실제 출시 심사는 **배포(App Store) 탭**에서 버전을 만들어 따로 제출해야 한다.

---

## 1. 버전 올리기

`ios/<워크스페이스>.xcodeproj/project.pbxproj` — 빌드 구성(스킴 × Debug/Release)마다 값이 따로 있으므로 **전부** 수정:

| 항목 | 의미 | 예시 |
|------|------|------|
| `MARKETING_VERSION` | 사용자에게 보이는 버전 | `1.2.3` |
| `CURRENT_PROJECT_VERSION` | 빌드 번호 (예: `YYMMDDNN` 규칙) | `26100701` |

- Xcode GUI: TARGETS → General → **Version / Build**. 구성별로 따로일 수 있으니 `git diff`로 전부 바뀌었는지 확인.
- 같은 날 두 번 올리면 빌드 번호 끝자리 +1. **App Store Connect는 같은 버전+빌드 번호 재업로드를 거부한다.**
- Android도 같이 올리는 게 일반적 → [Android_배포.md](./Android_배포.md) 1번.

---

## 2. Pods 설치 + bitcode 제거

```bash
cd <프로젝트 경로>/ios
pod install
```

- Xcode 15+는 bitcode를 지원하지 않는다. 오래된 서드파티 바이너리(일부 SDK의 `.framework`)에 bitcode가 남아 있으면 **업로드 단계에서 실패**할 수 있다.
- 프로젝트에 bitcode 제거 스크립트가 있으면 **`pod install` 직후 항상 실행**.
- 직접 확인 (아무것도 안 나오면 OK — tvOS/macOS/시뮬레이터용 슬라이스는 앱에 안 들어가므로 무관):
  ```bash
  for f in $(find Pods -path "*ios-arm64/*.framework" -type d); do b="$f/$(basename "$f" .framework)"; otool -l "$b" 2>/dev/null | grep -q __LLVM && echo "BITCODE: $b"; done
  ```
- 직접 제거:
  ```bash
  xcrun bitcode_strip <바이너리> -r -o <바이너리>_stripped && mv <바이너리>_stripped <바이너리>
  ```

---

## 3. Archive

1. `open ios/<워크스페이스>.xcworkspace`
2. 스킴: **`<prod 스킴>`**
3. 기기: **Any iOS Device (arm64)**
4. **Product → Archive** (5~10분)
5. 완료되면 Organizer 창이 뜸 (안 뜨면 **Window → Organizer**)

Organizer에서 아카이브의 버전/빌드 번호가 맞는지 확인.

---

## 4. Distribute (업로드)

Organizer에서 아카이브 선택 →

1. **Distribute App**
2. **App Store Connect** → Next
3. **Upload** → Next
4. 옵션 기본값 → Next
5. 서명: **Automatically manage signing** → Next
6. 요약 확인 → **Upload**
7. `Upload Successful` 나오면 완료

---

## 5. App Store Connect 처리 대기

- 업로드 직후엔 안 보인다. Apple 처리에 **10~30분** (길면 1시간+).
- 처리 완료 시 Apple 계정 메일로 알림.
- **TestFlight** 탭 → 빌드 목록에 새 버전이 뜨면 처리 완료.
- 수출 규정(암호화) 질문: `Info.plist`에 `ITSAppUsesNonExemptEncryption = NO`(false)를 넣어 두면 자동 처리됨. "Missing Compliance"가 뜨면 표준 암호화(HTTPS 등)만 쓰는 경우 **아니요** 선택.

---

## 6. (선택) TestFlight로 먼저 테스트

- **내부 테스트**: 팀원 그룹에 빌드 추가 → 심사 없이 바로 설치 (TestFlight 앱).
- **외부 테스트**: 외부 테스터 배포 시 Beta App Review(간단 심사) 필요. 출시 심사와는 별개.

---

## 7. App Store 심사 제출 ← 실제 "심사 올리기"

1. appstoreconnect.apple.com → **앱** → 내 앱 선택
2. 상단 탭 중 **배포**(구 이름 `App Store`, 영문 `Distribution`) — TestFlight 아님
3. 왼쪽 **iOS 앱** 옆 **+** → 새 버전 번호 입력 (`MARKETING_VERSION`과 동일)
4. **이 버전의 새로운 기능** 작성
5. **빌드** 섹션 → **+** → 5번에서 처리 완료된 빌드 선택
6. 출시 방법
   - 수동 출시: 심사 통과 후 "출시" 버튼을 눌러야 나감
   - 자동 출시: 심사 통과 즉시 출시
7. 오른쪽 위 **심사에 추가** → **심사 제출**

### 심사 상태

| 상태 | 의미 |
|------|------|
| 제출 준비 중 | 버전만 만들고 아직 제출 안 함 → "심사에 추가 → 심사 제출" 필요 |
| 심사 대기 중 | 제출 완료, 대기 (이때 **+ 버튼이 안 보임** — 한 번에 한 버전만 심사 가능) |
| 심사 중 | Apple 검토 중 |
| 출시 대기 중 | 통과, 수동 출시 설정 → 직접 "출시" 클릭 |
| 판매 준비 완료 | 출시됨 |
| 거부됨 | 사유 확인 → 수정 후 재제출 |

심사는 보통 24~48시간. 상태 변경 시 메일 알림.

---

## 자주 만난 에러

| 에러 | 원인 / 해결 |
|------|-------------|
| `Unable to process request - PLA Update available` | Apple 개발자 약관 갱신. **팀의 Account Holder**가 developer.apple.com에서 약관 동의해야 함 (본인만 가능). 동의 후에도 같은 에러면 Xcode → Settings → Accounts → 팀 선택 → Download Manual Profiles, 또는 Xcode 재시작 |
| `No signing certificate "iOS Distribution" found` / `No profiles for '<번들 ID>'` | 위 PLA 문제로 자동 서명이 막힌 경우가 대부분. PLA 해결 후 재시도. 그래도 안 되면 내 계정 권한이 **Admin 이상**인지 확인 (배포 인증서 생성 권한) |
| `The archive did not include a dSYM for the hermes.framework` | **경고일 뿐, 무시해도 됨.** RN Hermes 엔진은 dSYM 없이 배포됨. 업로드·심사 영향 없음 (Hermes 내부 크래시만 심볼 없이 표시) |
| `The sandbox is not in sync with the Podfile.lock` | `cd ios && pod install` (→ 이어서 bitcode 제거) |
| `all-product-headers.yaml not found` (Archive 실패) | 빌드 캐시 꼬임. **Product → Clean Build Folder** (`⇧⌘K`) 후 재Archive. 터미널 빌드와 Xcode 빌드를 동시에 돌리지 말 것 |
| 업로드 시 bitcode 관련 에러 | 2번 bitcode 제거 안 한 것. 제거 후 재Archive |
| `Redundant Binary Upload` / 빌드 번호 중복 | `CURRENT_PROJECT_VERSION` +1 후 재Archive |

---

## 정리

- 아카이브는 개당 수백 MB. Organizer에서 우클릭 → Delete, 또는 `~/Library/Developer/Xcode/Archives/` 정리.
- 후처리 스크립트가 만드는 임시 파일은 커밋하지 않는다.
