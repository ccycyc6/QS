## Deep Research Request: Low-Latency Android-CV Hybrid Controller for RPGs

<context>
I am a developer building a custom "phygital" game controller to play high-stakes Action RPGs (e.g., Dark Souls, Sekiro) on Windows.
The system uses a PC Webcam for body pose estimation (actions like attacking) and an Android phone for movement (virtual joystick).

**System Architecture:**
1.  **Mobile (Sender):** Android App (Native Java) -> Reads Touch/IMU -> Sends OSC packets via UDP.
2.  **Network:** Local Area Network (UDP).
3.  **PC (Receiver & Processor):** Python (Multiprocessing) -> Receives UDP + Runs CV (MediaPipe/OpenCV with CUDA) -> Fuses Data.
4.  **Output:** Simulates Xbox 360 Controller using `vgamepad` (ViGEmBus) driver.

**Critical Constraints:**
- **Latency:** Must be minimized (<20ms target) for "Soulslike" gameplay.
- **Hardware:** PC has NVIDIA GPU (available for CUDA acceleration).
- **Scope:** Windows PC + Android (.apk) only. No Web/iOS.
</context>

<instructions>
### Research Objectives:
I need a technical implementation guide that solves the concurrency challenges on PC and provides a robust, low-latency OSC sender on Android.

### Specific Technical Questions:

**1. PC Architecture (Python Multiprocessing):**
- Design a `multiprocessing` pattern where the UDP Receiver (IO-bound) and CV Inference (CPU/GPU-bound) run in separate processes to prevent blocking.
- How to share state data (joystick coordinates + trigger flags) between processes with microsecond latency? (Compare `multiprocessing.Queue` vs `multiprocessing.shared_memory`).
- Provide a code skeleton for this producer-consumer pattern.

**2. Latency Compensation (Kalman Filter) - *Deep Dive Requested*:**
- Provide the mathematical model and Python implementation of a Kalman Filter specifically tuned for **human hand/thumb trajectory prediction**.
- How should I tune the Q (Process Noise) and R (Measurement Noise) covariance matrices to balance "jitter reduction" vs "input lag"?
- **Goal:** Smooth out network jitter without adding the "floaty" feeling that ruins precision platforming.

**3. Android Sender (Java/Native):**
- Identify the most lightweight Java OSC library (e.g., `JavaOSC` or `NetUtil`) compatible with modern Android APIs.
- Provide a code snippet for a high-frequency UDP sender loop (60Hz+) that avoids Garbage Collection (GC) pauses (e.g., reusing packet objects).

**4. Input Simulation (ViGEm/vgamepad):**
- Provide the exact mapping logic to convert normalized Touch coordinates (0.0-1.0) into `vgamepad` Xbox 360 short values (-32768 to 32767) with a configurable Deadzone.
- How to handle "Safety Disconnect": Detect if the phone stops sending packets (UDP timeout) and auto-release all keys to prevent the character from running off cliffs.

### Scope Definition:
- **Include:** Windows (Python), Android (Java), OSC protocol, ViGEmBus, MediaPipe (Python).
- **Exclude:** iOS, Linux, Web technologies, AI Model Training (use pre-trained), UI Frameworks (Keep UI raw/simple).

### Sources Priority:
1.  Official Documentation (ViGEmBus, OSC specs)
2.  GitHub Repositories (Low-latency UDP examples)
3.  Academic Papers (Kalman Filter application in tracking)
4.  Technical Blogs (Python Multiprocessing optimization)

### Required Deliverables:
1.  **Architecture Diagram:** A Mermaid.js or text description of the Python Process flow.
2.  **Code Blocks:**
    - Android Java OSC Sender (Boilerplate).
    - Python Multiprocessing Skeleton (Receiver + CV + Main Loop).
    - Kalman Filter Class (Python).
3.  **Optimization Checklist:** Specific OS-level network settings (e.g., Windows socket buffer sizes) or Nagle's algorithm settings to disable.
</instructions>

<output_format>
- Provide robust, copy-pasteable code examples (Python & Java).
- Use **bold** for critical configuration parameters.
- Cite sources/libraries used.
- Explicitly warn about potential bottlenecks (e.g., Python GIL, UDP packet ordering).
</output_format>
