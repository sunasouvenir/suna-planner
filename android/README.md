# 수나 수브니르 안드로이드 앱

`projects.html`(사업 진행표 + 마감 달력)을 그대로 담은 안드로이드 앱이에요.
웹 파일과 폰트가 앱 안에 들어 있어서 인터넷 없이도 열려요.

- 설치 파일: `release/suna-souvenir-1.0.apk`
- 첫 화면: 사업 진행표 (아래 Planner 버튼으로 기존 플래너도 열 수 있어요)
- 데이터: 폰 안의 앱 저장공간에 저장돼요. 앱을 삭제하면 데이터도 지워져요.

## 다시 빌드하기

```bash
sudo apt-get install android-sdk-build-tools apksigner   # aapt2, dx, zipalign, apksigner
KEYSTORE=/path/to/suna-release.jks KS_PASS=비밀번호 ./android/build.sh
# 결과: android/build/suna-souvenir.apk
```

업데이트 APK는 **처음과 같은 서명 키(suna-release.jks)** 로 만들어야
기존 앱 위에 덮어서 설치돼요(데이터 유지). 키 파일은 저장소에 올리지 마세요.
새 버전을 낼 때는 `AndroidManifest.xml`의 `versionCode`를 1씩 올려주세요.
