# M2 Quality Assurance & UI/UX Verification Log
**Prepared by:** Nihat Avcı (230719001 - UI/UX Developer & QA Testing) & Oğuzhan Şükrü Keleş (230717016)

## 1. Static Code Analysis
- **Command:** `flutter analyze`
- **Result:** 0 critical issues, 0 errors.

## 2. Functional & Offline Fallback Test Cases
| Test ID | Scenario | Mode | Expected Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **TC-01** | Word capture via Android Share Intent | Online | Word translated in <1.5s with POS badges and saved to Hive | **PASS** |
| **TC-02** | Typo correction (`ephemral` -> `ephemeral`) | Online | Datamuse API returns yellow suggestion banner; clicking updates card | **PASS** |
| **TC-03** | Airplane Mode Translation Fallback | Offline | Connectivity check detects offline state; ML Kit translates locally and shows orange snackbar | **PASS** |
| **TC-04** | Theme Persistence (Light <-> Dark) | Offline | Toggling Material 3 theme updates `settings_box` and persists after app restart | **PASS** |
| **TC-05** | SM-2 Flashcard Swipe & TTS Audio | Offline | Right/Left swipes update `interval`, `repetition`, and `easeFactor` accurately | **PASS** |