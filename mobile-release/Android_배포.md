# React Native Android 앱 배포 (Play Store + Firebase 테스트 배포)

버전 올리기 → 빌드(AAB/APK) → Firebase App Distribution 테스트 배포 → Play Console 출시까지.

> 표기 규칙: `<...>`는 프로젝트마다 다른 값으로 바꿔서 사용
> - `<프로젝트 경로>`: RN 프로젝트 루트
> - `<flavor>`: 환경별 productFlavor 이름 (예: `prod`, `dev`)
> - `<패키지명>`: applicationId

---

## 전체 흐름 한눈에

```
1. 버전 올리기
2. 빌드
   - 테스트용: APK  (Firebase / 폰 직접 설치)
   - 스토어용: AAB  (Play Console)
3. (테스트) Firebase App Distribution에 APK 업로드 → 테스터 설치
4. (출시) Play Console에 AAB 업로드 → 내부 테스트 → 프로덕션 출시
```

| 용도 | 파일 | 올리는 곳 |
|------|------|-----------|
| 팀 테스트 | **APK** | Firebase App Distribution |
| 스토어 출시 | **AAB** | Google Play Console |

---

## 0. 사전 준비 (처음 한 번)

| 항목 | 설치 / 확인 |
|------|-------------|
| JDK | 프로젝트의 Android Gradle Plugin(AGP)이 요구하는 버전. 예: `brew install openjdk@17` |
| Android Studio | `brew install --cask android-studio` → 첫 실행 마법사 **Standard** |
| SDK 추가 설치 | Android Studio → Settings(`⌘,` 또는 메뉴 Android Studio → Settings…) → Languages & Frameworks → **Android SDK** |
| | • SDK Platforms 탭: `compileSdkVersion`과 같은 API 레벨 |
| | • SDK Tools 탭: **Show Package Details** 체크 → `ndkVersion`과 같은 **NDK (Side by side)** |
| | • Apply → 라이선스 **Accept** |
| `android/local.properties` | `sdk.dir=/Users/<사용자>/Library/Android/sdk` (gitignore 대상, 커밋 X) |
| 서명 키 | 업로드 키스토어 파일 + `gradle.properties`(또는 별도 파일)에 서명 정보 |

> 필요한 SDK/NDK 버전은 `android/build.gradle`의 `compileSdkVersion`, `buildToolsVersion`, `ndkVersion`에서 확인.
>
> 구글 로그인은 **필요 없다** (Gemini·Firebase 연동 등 부가 기능용). 건너뛰어도 빌드·서명 다 됨.

---

## 1. 버전 올리기

`android/app/build.gradle`

```gradle
versionCode 26100701      // 정수, 올릴 때마다 반드시 증가 (예: YYMMDDNN)
versionName '1.2.3'       // 사용자에게 보이는 버전 (iOS와 맞추는 게 일반적)
```

- **versionCode는 이전보다 무조건 커야 한다.** 같거나 작으면 Play Console이 거부.
- iOS도 같이 올리기 → [iOS_App_Store_배포.md](./iOS_App_Store_배포.md) 1번.

---

## 2. 빌드

### 2-A. 터미널 (추천)

```bash
export JAVA_HOME=$(/usr/libexec/java_home -v 17)   # 또는 brew 경로: /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
cd <프로젝트 경로>/android

# 스토어용 AAB
./gradlew bundle<Flavor>Release        # 예: bundleProdRelease
# → app/build/outputs/bundle/<flavor>Release/*.aab

# 테스트용 APK
./gradlew assemble<Flavor>Release      # 예: assembleProdRelease
# → app/build/outputs/apk/<flavor>/release/*.apk
```

- flavor가 없는 프로젝트는 `bundleRelease` / `assembleRelease`.
- 첫 빌드는 10~30분, 이후엔 몇 분. `BUILD SUCCESSFUL` 나오면 성공.

### 2-B. Android Studio (GUI)

1. **Open** → `<프로젝트 경로>/android` 폴더 열기 (Gradle Sync 끝날 때까지 대기)
2. 왼쪽 아래 **Build Variants** → `app` 모듈을 **`<flavor>Release`**로
3. **Build → Generate Signed App Bundle / APK…**
   - Android App Bundle(스토어용) 또는 APK(테스트용)
   - Key store path / 비밀번호 / alias 입력 (팀 내부 보관 정보 참고)
   - Build Variant: `<flavor>Release` → Create

### 2-C. 서명 확인 (선택)

```bash
~/Library/Android/sdk/build-tools/<버전>/apksigner verify --print-certs <APK 경로>   # APK
keytool -printcert -jarfile <AAB 경로>                                               # AAB
```

- 업로드 키의 인증서 정보(Owner/DN)가 나오면 정상.
- `CN=Android Debug`가 나오면 디버그 키로 잘못 서명된 것.

---

## 3. Firebase App Distribution (테스트 배포)

팀원/QA에게 스토어 없이 APK를 배포. 테스터는 메일 링크로 설치.

> **빌드한 flavor의 `google-services.json`에 적힌 Firebase 프로젝트에 올려야 한다.**
> 위치: `android/app/src/<flavor>/google-services.json` (또는 `android/app/google-services.json`)
> 안의 `project_id`와 `package_name` 확인. 패키지명이 다르면 업로드 거부됨.

### 업로드 (웹 콘솔)

1. https://console.firebase.google.com → 해당 프로젝트 선택
2. 왼쪽 메뉴 **App Distribution** (실행 및 모니터링 / Release & Monitor 그룹 아래)
3. 위쪽 앱 선택이 **Android / `<패키지명>`** 인지 확인
4. **APK 파일 드래그 업로드** (AAB도 되지만 Play 연동 필요 → 테스트는 APK가 간단)
5. **테스터 및 그룹** 추가 (이메일 또는 그룹)
6. **출시 노트** 작성
7. **배포** 클릭

### (선택) CLI로 업로드

```bash
npm install -g firebase-tools
firebase login
firebase appdistribution:distribute <APK 경로> \
  --app <Firebase Android 앱 ID> \
  --groups "<테스터 그룹>" \
  --release-notes "<출시 노트>"
```

- Firebase 앱 ID: 콘솔 → 프로젝트 설정 → 내 앱 → `1:xxxx:android:xxxx` 형태 (`google-services.json`의 `mobilesdk_app_id`).

### 테스터 쪽 (설치)

1. 초대 메일 → **Get started**
2. **App Tester** 앱 설치 (또는 브라우저 다운로드)
3. 빌드 선택 → **Download** → 설치 ("출처를 알 수 없는 앱 설치" 허용)

> ⚠️ **운영과 같은 패키지명의 APK는 폰의 Play 스토어 앱을 덮어쓴다.**
> 서명 키가 같으면 업데이트로 설치, 다르면 "앱이 설치되지 않음" → 기존 앱 삭제 후 설치.
> 운영 앱과 나란히 두려면 `applicationIdSuffix`가 붙은 dev flavor 사용.

### (참고) 폰에 직접 설치

폰 설정 → **개발자 옵션 → USB 디버깅** 켜고 USB 연결:

```bash
~/Library/Android/sdk/platform-tools/adb devices
~/Library/Android/sdk/platform-tools/adb install -r <APK 경로>
```

---

## 4. Play Console (스토어 출시)

https://play.google.com/console → 앱 선택

### 4-1. (권장) 내부 테스트 먼저

1. **테스트 및 출시 → 테스트 → 내부 테스트**
2. **새 버전 만들기**
3. **App Bundle 업로드** → AAB
4. 버전 이름 자동 입력 확인, **출시 노트** 작성
5. **다음 → 저장 → 출시**
6. 테스터 링크로 설치 → 정상 동작 확인 (특히 **실행 직후 꺼지지 않는지**)

### 4-2. 프로덕션 출시

1. **테스트 및 출시 → 프로덕션**
2. **새 버전 만들기** → 내부 테스트 빌드 재사용 시 **라이브러리에서 추가**
3. 출시 노트 작성
4. **다음** → 경고/오류 확인
5. (선택) **단계적 출시 비율** 설정 (예: 20% → 이상 없으면 100%)
6. **저장 → 게시 개요 → 검토를 위해 변경사항 전송**
7. 심사: 보통 몇 시간 ~ 1~2일

> 콘솔 메뉴 이름은 Google 업데이트에 따라 바뀔 수 있음.

---

## 자주 만난 에러

| 에러 | 원인 / 해결 |
|------|-------------|
| `Unable to locate a Java Runtime` / JDK 버전 오류 | `JAVA_HOME`을 AGP가 요구하는 JDK로 지정 후 재빌드 |
| `SDK location not found` | `android/local.properties`에 `sdk.dir=...` |
| `LicenceNotAcceptedException ... ndk;<버전>` | Android Studio SDK Manager에서 해당 NDK 설치 + 라이선스 Accept |
| Play Console: "버전 코드 ○○은 이미 사용되었습니다" | `versionCode` 올리고 재빌드 |
| Play Console: 서명 키 불일치 | 업로드 키로 서명됐는지 2-C로 확인 |
| Firebase: 패키지명 불일치 | flavor별 `google-services.json`의 프로젝트에 올렸는지 확인 |
| 폰 설치 시 "앱이 설치되지 않음" | 같은 패키지의 다른 서명 앱이 설치돼 있음 → 삭제 후 설치 |
