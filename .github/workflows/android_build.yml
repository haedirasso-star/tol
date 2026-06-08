name: TOTV+ Build — Release APK

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  build:
    name: Build Release APK (Phone + TV)
    runs-on: ubuntu-latest
    timeout-minutes: 70

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Setup Flutter 3.29.3
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.29.3'
          channel: 'stable'
          cache: true

      - name: Flutter pub get
        run: flutter pub get

      - name: Accept Android licenses
        run: yes | $ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager --licenses || true

      # نسخة الهاتف — APK شامل لكل الأجهزة
      - name: Build PHONE APK (Release)
        run: flutter build apk --release --no-shrink --flavor phone
        env:
          JAVA_OPTS: "-Xmx4096m"

      # نسخة الشاشات الذكية — TOTV Smart (leanback + ريموت)
      - name: Build TV APK (Release)
        run: flutter build apk --release --no-shrink --flavor tv
        env:
          JAVA_OPTS: "-Xmx4096m"

      - name: Collect APKs
        run: |
          mkdir -p release_apks
          cp build/app/outputs/apk/phone/release/app-phone-release.apk release_apks/TOTV-Phone.apk || \
            cp build/app/outputs/flutter-apk/app-phone-release.apk release_apks/TOTV-Phone.apk || true
          cp build/app/outputs/apk/tv/release/app-tv-release.apk release_apks/TOTV-Smart-TV.apk || \
            cp build/app/outputs/flutter-apk/app-tv-release.apk release_apks/TOTV-Smart-TV.apk || true
          echo "-- APKs --"; ls -lh release_apks/

      - name: Upload Phone APK
        uses: actions/upload-artifact@v4
        with:
          name: TOTV-Phone-APK
          path: release_apks/TOTV-Phone.apk
          retention-days: 30

      - name: Upload Smart TV APK
        uses: actions/upload-artifact@v4
        with:
          name: TOTV-Smart-TV-APK
          path: release_apks/TOTV-Smart-TV.apk
          retention-days: 30

      - name: Upload All
        uses: actions/upload-artifact@v4
        with:
          name: TOTV-All-APKs
          path: release_apks/
          retention-days: 30
