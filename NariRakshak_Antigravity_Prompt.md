# NariRakshak — Build Prompt for Google Antigravity

Copy everything below into Antigravity as your project brief / initial agent prompt.

---

## PROJECT BRIEF

Build **NariRakshak**, a three-layer AI-powered women's commute-safety companion app, using **Flutter (Dart)** for the mobile client and **Firebase** for backend/auth/realtime data. Follow the specification below exactly. Work in phases, scaffold the project first, then implement feature-by-feature, and stop after each phase for review before moving to the next.

### Tagline
"Never alone, never silent, never undetected."

### Core Concept
NariRakshak is a defense-in-depth safety app for daily commutes (walking, autos, cabs, public transport) built around three layers that automatically hand off to each other if one doesn't resolve the situation:

1. **Layer 1 — Safety Pods (Prevention):** Users on similar routes/timings are auto-matched into a temporary "pod." Live location is shared within the pod until every member marks "reached safely." A missed check-in auto-notifies pod members + emergency contacts with no manual action required.
2. **Layer 2 — Silent SOS (Conscious Escalation):** A discreet trigger (power-button pattern, in-app shake gesture, or paired Bluetooth wearable tap) instantly shares live GPS, a short audio clip, and an alert with pod members, emergency contacts, and (where integrated) local emergency services (e.g., 112 India). A decoy UI (fake incoming call / lock screen) displays so an aggressor doesn't realize SOS was triggered.
3. **Layer 3 — Passive Distress Audio Detection (Automatic Detection):** An opt-in, on-device audio model runs only during active commute sessions. A lightweight CNN/LSTM classifier trained on scream vs. non-scream audio detects distress sounds in near real-time and auto-triggers the same SOS pipeline as Layer 2 — covering cases where the user can't act manually.

### Escalation Table (implement this logic in the decision layer)

| Trigger | Immediate Action | Escalation If Unresolved |
|---|---|---|
| Pod check-in missed | Notify pod + emergency contacts | Escalate to SOS pipeline |
| Manual SOS gesture | Location + audio clip + alert sent | Escalate to control room / police |
| AI detects distress audio | Auto-trigger SOS pipeline | Same escalation as manual SOS |

---

## TECH STACK (use these exact choices)

- **Mobile App:** Flutter (Dart), cross-platform (Android + iOS)
- **Backend / Realtime:** Firebase (Firestore for data, Firebase Auth for phone/OTP login, Firebase Cloud Messaging for push notifications)
- **Audio ML:** On-device inference via **TensorFlow Lite**; note that model training itself (Python/Librosa/TensorFlow-Keras, CNN/LSTM) happens outside the Flutter app — the Flutter app only needs to load and run a pre-trained `.tflite` scream-classifier model using `tflite_flutter` (or `google_ml_kit`/`tflite_flutter_helper` as fallback) on sliding 2–3 second audio windows.
- **Maps & Geolocation:** `google_maps_flutter` + `geolocator` + `geocoding` packages
- **SMS fallback (low-connectivity):** Twilio API (called from a Firebase Cloud Function, not directly from the client)
- **State management:** Riverpod (preferred) or Provider
- **Database:** Firebase Firestore (users, pods, incidents, emergency contacts)

---

## APP STRUCTURE — SCREENS TO BUILD

1. **Onboarding / Auth** — Phone number + OTP verification (Firebase Auth), basic profile setup, add emergency contacts.
2. **Home / Commute Dashboard** — "Start Commute" button, current pod status (if any), quick access to Silent SOS.
3. **Pod Matching Screen** — "Join nearest active pod" logic based on route/time similarity; shows other pod members' live location on a map; "Mark reached safely" button.
4. **Silent SOS Flow** — Gesture/shake/power-button-pattern trigger; on activation, silently dispatch location + audio clip + alert; show a **decoy UI** (fake incoming call screen or fake lock screen) so it looks like nothing happened.
5. **Live Alert / SOS Active Screen** (for recipients — pod members/emergency contacts) — Shows the triggering user's live location, audio clip playback, and a "respond / call / navigate to them" action.
6. **Audio Detection Settings** — Opt-in toggle for passive distress detection, explanation of on-device/privacy-first processing, model status.
7. **Emergency Contacts Management** — Add/edit/remove trusted contacts.
8. **Incident History / Risk Heatmap (stretch goal)** — Opt-in log of past incidents/check-ins visualized as a map heatmap.
9. **Settings & Privacy** — Permissions management (mic, location, notifications), data/privacy controls.

---

## SYSTEM PIPELINE TO IMPLEMENT

1. **Sensing:** Capture mic audio stream, GPS location, and manual gesture input.
2. **On-device pre-processing:** Noise filtering + MFCC/spectrogram feature extraction from audio; location smoothing.
3. **AI Inference:** Run the CNN/LSTM scream classifier on sliding 2–3 second audio windows via TFLite, near real-time.
4. **Decision Layer:** A rule engine that fires when: manual trigger OR audio-model confidence exceeds a threshold OR a pod check-in times out.
5. **Alert Orchestration:** On trigger, push alerts to pod members, emergency contacts, and (if integrated) a control-room API; activate decoy UI.
6. **Logging & Feedback:** Log incidents + location (opt-in only) to Firestore to power a future community risk-heatmap.

---

## BUILD PHASES (ask Antigravity to work through these in order)

**Phase 1 — Setup & App Shell**
- Scaffold Flutter project with clean architecture (feature-first folder structure: `lib/features/auth`, `lib/features/pod`, `lib/features/sos`, `lib/features/audio_detection`, `lib/features/contacts`, `lib/core`, etc.)
- Firebase project setup: Auth (phone/OTP), Firestore schema for `users`, `pods`, `incidents`, `emergency_contacts`
- Basic navigation (go_router or Navigator 2.0), theming, onboarding flow

**Phase 2 — Silent SOS + Decoy UI**
- Implement gesture/shake trigger and power-button-pattern detection
- On trigger: capture GPS + short audio clip, push to Firestore/FCM, notify pod + contacts
- Build decoy UI (fake incoming call screen)

**Phase 3 — Pod Matching (simplified)**
- "Join nearest active pod" matching logic (by route/time proximity — simple radius + time-window matching is fine for MVP)
- Live location sharing UI within a pod (map view with member markers)
- "Reached safely" check-in + missed-check-in auto-escalation timer

**Phase 4 — Audio ML Integration**
- Integrate a pre-trained `.tflite` scream/non-scream classifier (assume model file will be provided separately — stub the inference call with a clear interface: `Future<double> classifyAudioWindow(List<double> samples)`)
- Wire sliding-window inference into an opt-in background/foreground service during active commute sessions
- On positive detection above threshold, auto-trigger the same pipeline as Layer 2

**Phase 5 — Alert Orchestration & Recipient Experience**
- Build the SOS-recipient screen (for pod members/contacts) showing live location + audio playback + response actions
- Add SMS fallback path (via a Cloud Function calling Twilio) for low-connectivity scenarios

**Phase 6 — Polish**
- Emergency contacts management screen, settings/privacy screen, incident history (stretch: heatmap)
- Handle permissions gracefully (mic, location, notifications, background execution)
- Add loading states, error handling, and basic empty/edge-case UI

---

## KEY NON-FUNCTIONAL REQUIREMENTS

- **Privacy-first:** Audio processing must be on-device only; raw audio is never uploaded unless an SOS is actually triggered. Everything (pod location sharing, audio detection, incident logging) must be explicitly opt-in.
- **Battery/data efficiency:** Only run continuous audio/GPS monitoring during an active commute session, using lightweight on-device models.
- **False-positive handling:** Use a confidence threshold + short confirmation window before full escalation on AI-detected distress, to reduce false triggers from ambient noise (traffic, laughter, etc.).
- **Offline resilience:** Ensure SOS alerts have an SMS-based fallback path for low-connectivity areas.
- **Trust/verification:** Pod eligibility should include phone/OTP verification (and leave a hook for optional ID verification later).

---

## INSTRUCTIONS FOR ANTIGRAVITY

1. Start by scaffolding the Flutter project structure and Firebase configuration files (placeholders where real keys are needed).
2. Implement Phase 1 fully and working end-to-end before moving to Phase 2.
3. For the audio ML piece, do NOT attempt to train a model — treat the `.tflite` file as an external dependency and build a clean, swappable inference interface instead.
4. Use mock/stub data where a live backend isn't yet wired up, so UI can be reviewed independently of backend completion.
5. After each phase, summarize what was built, list any assumptions made, and flag anything that needs my input (e.g., API keys, Firebase project credentials, Twilio credentials, the trained model file).
6. Keep code modular and well-commented so features can be demoed independently for a hackathon presentation.

---

*Reference: This prompt is based on the "NariRakshak — Nari Kavach Hackathon Project Report."*
