# App Store Review Notes

## Demo access

- Test phone: `+79997777777`
- Login flow: enter the phone number, tap the primary action, then follow the call verification flow shown in the app.

## Payments

The current iOS app version does not sell goods, services, subscriptions, in-app purchases, or digital content inside the app.

## Account deletion

Account deletion is available in the app:

1. Open the Profile tab.
2. Open `Аккаунт`.
3. Tap `Удалить аккаунт`.
4. Confirm `Удалить`.

The app calls authenticated `Storage.DeactivateAccount`, clears saved auth tokens, and returns the user to login.

## Privacy and legal

- Privacy policy and terms are available in Profile -> `Правовая информация`.
- Support contact: `grishapav1992@gmail.com`.
- Operator: `ИНДИВИДУАЛЬНЫЙ ПРЕДПРИНИМАТЕЛЬ ПАВЛЕНКО ГРИГОРИЙ АЛЕКСАНДРОВИЧ`, INN `237305224179`, OGRNIP `322237500311981`.

## Permission usage

- Camera: scanning VIN and taking vehicle inspection/profile photos.
- Photo library: selecting vehicle inspection/profile images.
- Microphone: recording voice notes during inspection.
- Speech recognition: converting voice notes into text comments.
