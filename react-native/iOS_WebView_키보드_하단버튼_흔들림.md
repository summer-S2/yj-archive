# iOS WebView 앱에서 키보드 표시·숨김 시 하단 고정 버튼 흔들림 정리 (React Native)

React Native 앱이 웹 화면을 WebView로 띄우는 구조에서, iOS 키보드가 올라오거나 내려갈 때 **웹의 하단 고정 버튼과 바텀시트가 흔들리는 문제**를 고친 기록.

> 표기 규칙: `<...>` 는 프로젝트마다 다른 값으로 바꿔서 사용
> - React Native 0.73 (New Architecture), `react-native-webview`, iOS 실기기 기준
> - `<WebView 화면>`: WebView를 감싸는 RN 화면 컴포넌트

---

## 한눈에 보기

| | 내용 |
|---|---|
| 증상 1 | 키보드가 올라와도 WebView 높이가 그대로라 하단 고정 버튼이 키보드에 가려짐 |
| 증상 2 | `KeyboardAvoidingView`로 감싸면 버튼은 올라오지만, 키보드가 뜨고 질 때 버튼·바텀시트가 출렁임 |
| 원인 | WebView 높이가 키보드 애니메이션 동안 **매 프레임 조금씩** 바뀜 → 웹은 프레임마다 레이아웃을 다시 잡음 |
| 해결 | 키보드 이벤트(`keyboardWillShow` 등)에서 **최종 높이를 한 번에** padding으로 적용, 숨길 때 0 |
| 결과 | 키보드 표시·숨김 시 WebView 크기가 한 번만 바뀜 → 흔들림 없음 |

---

## 1. 먼저 알아야 할 것: iOS WKWebView와 키보드

- iOS의 WKWebView는 키보드가 올라와도 **자기 frame(높이)을 줄이지 않는다.** 대신 내부적으로 visual viewport만 줄이고 문서를 스크롤한다.
- 그래서 웹에서 `position: fixed; bottom: 0` 버튼은 키보드 **뒤에** 그대로 있고, 웹이 알아서 키보드 위로 올려 주지 않는다.
- Android WebView는 `adjustResize`로 WebView 자체가 줄어들어서 이 문제가 없다. → **iOS에서만 처리**한다.

---

## 2. 처음 시도: KeyboardAvoidingView

```tsx
<KeyboardAvoidingView behavior="padding" style={{ flex: 1 }}>
  <WebView ... />
</KeyboardAvoidingView>
```

- 버튼이 키보드 위로 올라오긴 한다.
- 그런데 키보드가 뜨고 질 때 **하단 버튼이 바닥에 붙으면서 살짝 튀고**, 바텀시트(예: 선택 목록 시트)도 같이 출렁인다.

### 측정해서 확인한 것

Safari Web Inspector로 웹에 프로브를 넣어 `window.innerHeight` / `visualViewport.height` 변화를 프레임 단위로 찍었다.

- WebView 높이가 키보드 애니메이션 동안 **프레임마다 약 12px씩 선형으로** 줄었다 (약 0.4초).
- 키보드 자체 애니메이션(약 0.25초)보다 늦게 끝났다.
- 끝에서 한 번 **넘쳤다가 되돌아오는** 값도 보였다 (예: 756 → 733 → 759).

→ 웹은 높이가 바뀔 때마다 `fixed` 요소·`100dvh` 요소를 다시 배치하므로, 이 매 프레임 변화가 그대로 흔들림으로 보인다.
(왜 선형으로 바뀌는지는 RN 쪽 레이아웃 애니메이션 때문으로 **추정**, 확인은 못 함)

---

## 3. 해결: 최종 높이를 한 번에 적용

`KeyboardAvoidingView`를 빼고, 키보드 이벤트를 직접 받아 **WebView를 감싼 View의 paddingBottom을 한 번에** 바꾼다.

```tsx
import React, { useEffect, useRef, useState } from 'react';
import { Keyboard, KeyboardEvent, Platform, View } from 'react-native';

const <WebView 화면> = () => {
  const containerRef = useRef<View>(null);
  const [keyboardPadding, setKeyboardPadding] = useState(0);
  const keyboardShownRef = useRef(false);

  useEffect(() => {
    if (Platform.OS !== 'ios') return;
    // 키보드에 가려지는 만큼만 padding
    const onWillShow = (e: KeyboardEvent) => {
      keyboardShownRef.current = true;
      const keyboardTop = e.endCoordinates.screenY;
      containerRef.current?.measureInWindow((_x, y, _w, h) => {
        setKeyboardPadding(Math.max(0, Math.round(y + h - keyboardTop)));
      });
    };
    const subs = [
      Keyboard.addListener('keyboardWillShow', onWillShow),
      // 키보드 높이 변경 (서드파티 키보드, 예측 입력 바 토글 등)
      Keyboard.addListener('keyboardWillChangeFrame', (e) => {
        if (keyboardShownRef.current) onWillShow(e);
      }),
      Keyboard.addListener('keyboardWillHide', () => {
        keyboardShownRef.current = false;
        setKeyboardPadding(0);
      }),
    ];
    return () => subs.forEach((s) => s.remove());
  }, []);

  return (
    <View ref={containerRef} style={{ flex: 1, paddingBottom: keyboardPadding }}>
      <WebView ... />
    </View>
  );
};
```

### 포인트

| 항목 | 이유 |
|---|---|
| `keyboardWill*` 이벤트 사용 | `Did*`보다 먼저 와서 키보드 애니메이션과 거의 같이 바뀜 |
| `endCoordinates.screenY` + `measureInWindow` | 키보드 높이를 그대로 빼면 화면 아래 탭바·safe area만큼 더 올라감. **가려지는 만큼만** 계산 |
| `keyboardWillChangeFrame` 도 처리 | 키보드 높이가 바뀌는 경우 (서드파티 키보드 등) |
| 숨김 시 바로 0 | 키보드보다 먼저 내려가도 버튼이 바닥에 한 번에 붙어서 흔들림 없음 |

### 같이 넣은 WebView 옵션 (iOS)

```tsx
<WebView
  automaticallyAdjustContentInsets={false}
  contentInsetAdjustmentBehavior="never"   // WebView 자체 inset 조정과 이중 적용 방지
  hideKeyboardAccessoryView={true}         // 키보드 위 ^ v 완료 바 숨김
/>
```

---

## 4. (선택) 웹 쪽 보조 처리

앱 수정만으로 흔들림은 잡혔다. 아래는 **입력 중 스크롤** 관련 보조 처리.

### 4-1. 줄어든 높이를 웹에 알려 스크롤 범위 보정

WebKit이 줄어들기 전 높이 기준으로 문서 끝을 넘겨 스크롤하는 경우가 있어, 앱에서 줄어든 높이를 넘기고 넘친 스크롤을 되돌린다.

```ts
webViewRef.current?.injectJavaScript(`(function(){
  window.__kbViewportHeight = ${height};   // 키보드 숨김 시 0
  if (!window.__kbScrollClamp) {
    window.__kbScrollClamp = function(){
      var h = window.__kbViewportHeight;
      if (!h) return;
      var se = document.scrollingElement || document.documentElement;
      var max = Math.max(0, se.scrollHeight - h);
      if (window.scrollY > max) window.scrollTo(0, max);
    };
    window.addEventListener('scroll', window.__kbScrollClamp);
    window.visualViewport?.addEventListener('resize', window.__kbScrollClamp);
  }
  window.__kbScrollClamp();
})(); true;`);
```

`height`는 WebView를 감싼 View의 `onLayout` 높이.

### 4-2. 문서 대신 내용 영역만 스크롤 (레이아웃 옵션)

입력 중 스크롤할 수 없는 곳을 끌면 WebView 전체가 출렁이는 문제용. 화면 단위로 켜는 옵션으로 만들었다 (iOS 앱 WebView에서만 동작).

```css
html.layout-inner-scroll,
html.layout-inner-scroll body {
  height: 100%;
  overflow: hidden;
  overscroll-behavior: none;
}
```

- 레이아웃 루트: `h-[100dvh] overflow-hidden flex flex-col`
- 내용 영역: `flex-1 min-h-0 overflow-y-auto overscroll-contain`
- 하단 고정 버튼 높이를 `ResizeObserver`로 재서 내용 영역 `paddingBottom`으로 사용 (내용이 버튼에 가려지지 않게)
- 입력 중(`activeElement`가 input/textarea)일 때, 스크롤 가능한 요소 밖에서의 `touchmove`는 `preventDefault()`

---

## 5. 해 봤지만 필요 없었던 것

| 시도 | 결과 |
|---|---|
| 바텀시트 열릴 때 준비 상태(ready) 기다렸다가 애니메이션 | 효과 없음. 흔들림 원인이 시트가 아니라 WebView 높이 변화라서. 앱 수정 후 제거 |
| 웹에서 `visualViewport` 따라 버튼 위치 옮기기 | 매 프레임 높이 변화를 따라가므로 같이 흔들림 |

---

## 6. 확인 방법

### 웹 상태 찍어 보기 (Safari Web Inspector)

1. WebView에 `webviewDebuggingEnabled={true}` (확인 후 제거)
2. 맥 Safari → 개발자용 → `<기기 이름>` → 해당 WebView
3. 콘솔에서 프로브:
   ```js
   (function(){
     const t0 = performance.now();
     const log = () => console.log('[kb]', Math.round(performance.now()-t0),
       innerHeight, visualViewport.height, scrollY);
     visualViewport.addEventListener('resize', log);
     addEventListener('resize', log);
   })();
   ```
4. 입력창 포커스·해제하면서 높이가 **한 번에** 바뀌는지, 여러 번 찍히는지 본다.

### 화면 녹화로 보기

화면 녹화를 프레임 단위로 넘겨 보면 버튼이 몇 px 튀는지 보인다. 수정 전후를 같은 동작으로 녹화해 비교한다.

### 체크리스트

- [ ] 입력창 포커스 → 하단 버튼이 키보드 바로 위에 붙는지
- [ ] 키보드 내릴 때 버튼이 바닥에 한 번에 붙는지 (튀지 않는지)
- [ ] 키보드 떠 있는 상태에서 바텀시트 열기·닫기
- [ ] 서드파티 키보드 / 키보드 높이 바뀌는 경우
- [ ] 키보드 떠 있는 상태에서 다른 화면으로 이동했다 돌아왔을 때 아래 빈 공간 남지 않는지
- [ ] Android는 기존과 동일한지
