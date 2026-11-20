# notion-worklog 설정 (예시)

이 파일을 같은 폴더에 `config.local.md`로 복사해 값을 채운다. `config.local.md`는 `.gitignore` 대상이라 커밋되지 않는다.

## 노션

| 대상 | 값 |
|---|---|
| 작업 DB data source | `collection://<작업 DB data source ID>` |
| 작업 DB '오늘' 뷰 | `view://<뷰 ID>` |
| 작업 DB '날짜별' 뷰 | `view://<뷰 ID>` |
| 프로젝트 DB data source | `collection://<프로젝트 DB data source ID>` |
| 프로젝트 DB 기본 뷰 | `view://<뷰 ID>` |

## 시간대

UTC+9 (날짜 경계 판단과 `sessions.py --tz` 값)

## 프로젝트 매칭

세션의 작업 폴더·레포 이름이나 작업 성격으로 프로젝트를 고른다. 여기 없는 작업은 새 프로젝트를 만들지 않고 미리보기에서 묻는다.

| 프로젝트 | 페이지 ID | 매칭 기준 |
|---|---|---|
| `<프로젝트명>` | `<페이지 ID>` | `<레포·폴더 이름, 작업 성격>` |
