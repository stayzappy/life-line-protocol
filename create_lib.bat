@echo off
echo Creating lib/ folder structure for lifeline...

REM === LIB ROOT ===
mkdir lib
type nul > lib\main.dart

REM === CONFIG ===
mkdir lib\config
type nul > lib\config\constants.dart
type nul > lib\config\routes.dart
type nul > lib\config\theme.dart

REM === MODELS ===
mkdir lib\models
type nul > lib\models\vault_model.dart

REM === PROVIDERS ===
mkdir lib\providers
type nul > lib\providers\vault_provider.dart
type nul > lib\providers\wallet_provider.dart

REM === SCREENS ===
mkdir lib\screens
mkdir lib\screens\auth
mkdir lib\screens\dashboard
mkdir lib\screens\onboarding
mkdir lib\screens\vault

type nul > lib\screens\auth\connect_wallet_screen.dart
type nul > lib\screens\dashboard\home_screen.dart
type nul > lib\screens\onboarding\onboarding_screen.dart
type nul > lib\screens\vault\create_vault_screen.dart

REM === SERVICES ===
mkdir lib\services
type nul > lib\services\biometric_service.dart
type nul > lib\services\email_service.dart
type nul > lib\services\encryption_service.dart
type nul > lib\services\storage_service.dart

REM === WIDGETS ===
mkdir lib\widgets
type nul > lib\widgets\responsive_wrapper.dart

REM === FIREBASE OPTIONS (placeholder, only if missing) ===
type nul > lib\firebase_options.dart

echo Done! lib/ directory scaffolded for lifeline.
pause
