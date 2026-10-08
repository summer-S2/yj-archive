# React Native iOS 앱을 내 아이폰에 prod 빌드로 설치하기

배포 전에 특정 브랜치를 **prod 환경**으로 빌드해서 내 아이폰에 직접 설치해 테스트하는 절차.

> 표기 규칙: `<...>`는 프로젝트마다 다른 값으로 바꿔서 사용
> - `<프로젝트 경로>`: RN 프로젝트 루트
> - `<워크스페이스>`: `ios/` 아래 `.xcworkspace` 이름
> - `<prod 스킴>`: prod 환경용 Xcode 스킴
> - `<prod 번들 ID>`: prod 앱의 Bundle Identifier

> ⚠️ **prod 번들 ID로 설치하면 폰에 깔린 App Store 운영 앱을 덮어쓴다.**
> - 앱 데이터는 보통 유지되지만 보장되지 않음
> - 운영 앱으로 되돌리려면 **앱 삭제 → App Store에서 재설치** (App Store 업데이트로는 안 바뀜)
> - 운영 앱과 나란히 두고 싶으면 번들 ID가 다른 dev 스킴을 사용

---

## 0. 사전 준비 (처음 한 번)

| 항목 | 확인 방법 |
|------|-----------|
| Xcode | App Store에서 설치 |
| Apple 계정 | Xcode → Settings → Accounts에 회사 팀 계정 로그인 |
| CocoaPods | `pod --version` |
| 패키지 매니저 | `pnpm` / `yarn` / `npm` 중 프로젝트에서 쓰는 것 |
| 아이폰 개발자 모드 | 설정 → 개인정보 보호 및 보안 → 개발자 모드 켜기 → 재부팅 |

---

## 1. 브랜치 체크아웃

```bash
cd <프로젝트 경로>
git status                 # 수정 중인 파일 없는지 확인 (있으면 커밋 또는 stash)
git fetch
git checkout <브랜치 이름>
git pull
```

브랜치 이름 일부로 찾기:

```bash
git branch -a | grep <키워드>
```

---

## 2. 의존성 설치

```bash
pnpm install               # 또는 yarn / npm install
cd ios && pod install && cd ..
```

- 브랜치를 바꿨거나 빌드 시 아래 에러가 나면 `pod install` 필수:
  ```
  error: The sandbox is not in sync with the Podfile.lock. Run 'pod install' ...
  ```
- `pod install` 후 `Podfile.lock`, `project.pbxproj`가 수정됨으로 뜰 수 있다. 체크섬·줄 순서 변경뿐이면 테스트용으로는 **커밋하지 말고** 두거나 `git checkout -- <파일>`로 되돌린다.
- bitcode 제거 같은 후처리 스크립트는 **archive/App Store 업로드 때만** 필요. 실기기 설치에는 불필요.

---

## 3. 아이폰 연결

1. USB로 맥에 연결
2. 아이폰 잠금 해제
3. "이 컴퓨터를 신뢰하겠습니까?" → **신뢰**

```bash
xcrun devicectl list devices
```

내 폰이 `connected`면 OK. `unavailable`이면 잠금 해제·케이블·신뢰 여부 확인.

---

## 4-A. Xcode(GUI)로 빌드 & 설치 (추천)

1. `open ios/<워크스페이스>.xcworkspace` (**.xcworkspace**로 열기, .xcodeproj 아님)
2. 상단 스킴 → **`<prod 스킴>`**
3. 기기 → **내 아이폰**
4. **Product → Scheme → Edit Scheme…** (`⌘<`) → Run → Info → **Build Configuration = Release**
   - Release여야 JS 번들이 앱에 포함돼 Metro 없이 단독 실행됨
5. (처음 한 번) 프로젝트 → TARGETS → **Signing & Capabilities** → Team 선택, "Automatically manage signing" 체크
6. **▶ (`⌘R`)** → 빌드 → 설치 → 자동 실행 (5~10분)

---

## 4-B. 터미널로 빌드 & 설치

### 기기 ID 확인

```bash
xcrun xctrace list devices
```

출력 예: `<기기 이름> (<iOS 버전>) (<UDID>)` → 마지막 괄호 값이 기기 ID.

### 빌드

```bash
cd <프로젝트 경로>

xcodebuild \
  -workspace ios/<워크스페이스>.xcworkspace \
  -scheme "<prod 스킴>" \
  -configuration Release \
  -destination "id=<UDID>" \
  -derivedDataPath build_dd \
  -allowProvisioningUpdates \
  build
```

`** BUILD SUCCEEDED **` 나오면 성공.

### 설치 & 실행

```bash
xcrun devicectl device install app --device <UDID> "build_dd/Build/Products/Release-iphoneos/<앱 이름>.app"
xcrun devicectl device process launch --device <UDID> <prod 번들 ID>
```

> `build_dd/`는 빌드 결과물 폴더. 끝나면 `rm -rf build_dd` (커밋 금지).

---

## 5. 폰에서 처음 실행이 막힐 때

| 증상 | 해결 |
|------|------|
| "신뢰하지 않는 개발자" | 설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 → 신뢰 |
| "개발자 모드 필요" | 설정 → 개인정보 보호 및 보안 → 개발자 모드 켜기 → 재부팅 |

---

## 6. 자주 나는 빌드 에러

| 에러 | 원인 / 해결 |
|------|-------------|
| `The sandbox is not in sync with the Podfile.lock` | `cd ios && pod install` |
| `Failed to launch AssetCatalogSimulatorAgent via CoreSimulator spawn` | 시뮬레이터 서비스 문제. Xcode를 한 번 열었다 닫거나 `xcrun simctl list runtimes` 실행 후 재빌드. 샌드박스 환경(자동화 도구 등)에서 돌릴 때도 발생 |
| Signing 에러 (No profiles / Team 없음) | Xcode → Settings → Accounts 로그인 확인, Signing & Capabilities에서 Team 선택 |
| 폰이 목록에 없음 / `unavailable` | 잠금 해제, 케이블 재연결, "신뢰" 허용 |

---

## 7. 테스트 끝난 뒤 정리

1. **운영 앱 복구**: 폰에서 앱 삭제 → App Store에서 재설치
2. **로컬 변경 정리** (`pod install`로 바뀐 파일)
   ```bash
   git status
   git checkout -- ios/Podfile.lock ios/<워크스페이스>.xcodeproj/project.pbxproj
   ```
3. 원래 브랜치로 복귀 후 Pods 다시 맞추기
   ```bash
   git checkout <원래 브랜치>
   cd ios && pod install && cd ..
   ```
