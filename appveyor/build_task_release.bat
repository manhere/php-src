@echo off
rem Based on official appveyor/build_task.bat (php-src 7.4 Windows CI).
rem Differences for release packaging only:
rem   - --enable-debug-pack instead of --disable-debug-pack (matches php.net release / phpinfo configure)
rem   - nmake snap at the end to produce the Win32 zip + debug-pack zip
rem   - test-ini excludes dropped (no test run in CI)

cd /D %APPVEYOR_BUILD_FOLDER%
if %errorlevel% neq 0 exit /b 3

rem official appveyor/build.bat creates these before invoking the task;
rem we call the task directly, so create them here (configure does not mkdir)
if not exist "%PHP_BUILD_CACHE_BASE_DIR%" mkdir "%PHP_BUILD_CACHE_BASE_DIR%"
if not exist "%PHP_BUILD_OBJ_DIR%" mkdir "%PHP_BUILD_OBJ_DIR%"

if /i "%APPVEYOR_REPO_BRANCH:~0,4%" equ "php-" (
	set BRANCH=%APPVEYOR_REPO_BRANCH:~4,3%
) else (
	set BRANCH=master
)
set STABILITY=staging
set DEPS_DIR=%PHP_BUILD_CACHE_BASE_DIR%\deps-%BRANCH%-%PHP_SDK_VS%-%PHP_SDK_ARCH%
if exist "%DEPS_DIR%\.deps-ready" (
	echo Dependencies pre-fetched, skipping phpsdk_deps
) else (
	echo Updating dependencies in %DEPS_DIR%
	cmd /c phpsdk_deps --update --no-backup --branch %BRANCH% --stability %STABILITY% --deps %DEPS_DIR% --crt %PHP_BUILD_CRT%
	if %errorlevel% neq 0 exit /b 3

	if not exist "%DEPS_DIR%" (
		cmd /c phpsdk_deps --update --force --no-backup --branch %BRANCH% --stability %STABILITY% --deps %DEPS_DIR%
	)
	if %errorlevel% neq 0 exit /b 3
)

cmd /c buildconf.bat --force
if %errorlevel% neq 0 exit /b 3

cmd /c configure.bat ^
	--enable-snapshot-build ^
	--enable-debug-pack ^
	--disable-zts ^
	--enable-com-dotnet=shared ^
	--without-analyzer ^
	--enable-object-out-dir=%PHP_BUILD_OBJ_DIR% ^
	--with-php-build=%DEPS_DIR%
if %errorlevel% neq 0 exit /b 3

nmake /NOLOGO
if %errorlevel% neq 0 exit /b 3

nmake /NOLOGO snap
if %errorlevel% neq 0 exit /b 3

rem success marker: the SDK starter bat swallows the task exit code,
rem the workflow checks for this file to make the step actually fail
echo ok > "%PHP_BUILD_CACHE_BASE_DIR%\.build-ok"

exit /b 0
