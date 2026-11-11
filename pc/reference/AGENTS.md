# AGENTS.md - Master Plan for Immersive Controller

## 🎯 Project Overview
**App:** Immersive Controller
**Goal:** Play Dark Souls 3 with body movements (<20ms latency) using phone & webcam.
**Stack:** Python (PC Host), Android (Java), UDP/Wi-Fi, MediaPipe (CV).
**Current Phase:** Phase 3 - Integration & Polish

## 🧠 How I Should Think (Vibe-Coder Edition)
1. **Performance First**: Every line of code must be fast. If it adds latency, reject it.
2. **Explain the "Why"**: Tell the user *why* we are using Multiprocessing or UDP before writing it.
3. **Small Steps**: Build one piece (e.g., just the UDP listener) and verify it works before adding CV.
4. **Safety Always**: Ensure the "Watchdog" (auto-stop on disconnect) is in mind for every feature.

## 📁 Context Files
- `agent_docs/tech_stack.md`: The specific libraries for low-latency IO.
- `agent_docs/product_requirements.md`: The PRD and user stories.
- `agent_docs/code_patterns.md`: The critical "Shared Memory" architecture.

## 🔄 Current State (Update This!)
**Last Updated:** 2025-12-29
**Working On:** Final Polish & Documentation
**Recently Completed:** Parry Gesture, Dodge Gesture (Duck), Dodge Sensitivity, Android UI Refactoring
**Blocked By:** None

## 🚀 Roadmap
### Phase 1: Foundation & Connection
- [x] Set up Python virtual environment & install dependencies (MediaPipe, vgamepad)
- [x] Create basic Android project structure
- [x] Implement "Hello World" UDP connection (Phone -> PC)

### Phase 2: Core Inputs
- [x] Implement PC Multiprocessing Architecture (Network vs CV processes)
- [x] Build Android Virtual Joystick & IMU Sender
- [x] Integrate MediaPipe for simple hand tracking

### Phase 3: Integration & Polish
- [x] Map inputs to Virtual Xbox 360 Controller (ViGEmBus)
- [x] Implement "Zero-Point Calibration"
- [x] End-to-End Latency Test (<20ms verified)
- [x] Implement Advanced Gestures (Wave Attack, Raise-Grip Heal)
- [x] Android UX Polish (Visual Joystick, Locale Fix)
- [x] Switch Camera Control to IMU/Gyro (Motion Aiming)
- [x] Refactor UI: Settings Page & Layout Editor improvements
- [x] Implement AIM Toggle/Hold Logic
- [x] Add Joystick Size Configuration
- [x] Add Shoulder Buttons (LB/RB, LT/RT)
- [x] Polish Default Layout (Stacked Shoulders, Smaller Joystick)
- [x] Feature: Arm Skeleton Visualization
- [x] Feature: Shield Block Gesture (Left Arm Flexion)
- [x] Feature: Parry Gesture (Left Arm Outward Flick)
- [x] Feature: Dodge Gesture (Head Vertical Duck)
- [x] Feature: Dodge Sensitivity Settings UI

### Phase 4: Release
- [ ] Create detailed README/Install Guide
- [ ] Final Code Cleanup (Remove debug prints)

## ⚠️ What NOT To Do
- Do NOT use HTTP/TCP for controller data (Too slow! Use UDP).
- Do NOT run Computer Vision and Network Listening in the same thread/process.
- Do NOT make the Android UI complex (Keep it ugly but fast).
- Do NOT assume the network is perfect (Handle packet loss gracefully).
- Do NOT use absolute positioning (Ensure the UI adapts correctly to different screen sizes and aspect ratios).
