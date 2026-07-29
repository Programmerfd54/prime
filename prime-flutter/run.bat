@echo off
set "PATH=C:\dev\flutter\bin;%PATH%"
cd /d "%~dp0"
flutter pub get
flutter run --dart-define=API_BASE_URL=http://2.26.86.88:8080 %*
