# GEMINI.md - Gemini CLI Configuration for Immersive Controller

## 🎯 Project Context
**App:** Immersive Controller
**Stack:** Python (Multiprocessing), Android (Java/UDP)
**Stage:** MVP Development
**User Level:** Vibe-Coder (I need simple explanations, but elite code performance)

## 📋 Directives
1.  **Master Plan:** ALWAYS read `AGENTS.md` first.
2.  **Strict Latency Rules:** If I ask for a feature that slows things down (like a heavy UI), warn me.
3.  **Process Separation:** Always keep CV and Networking in separate processes.
4.  **Hardware Helper:** When writing Python code, remind me to install the `ViGEmBus` driver if I haven't.
5.  **Simplicity:** Explain complex architecture with analogies (e.g., "The Shared Memory is like a whiteboard both processes can read").

## 🛠 Commands
- `python main.py` - Start the PC Server
- `gradlew installDebug` - Install Android App
- `pytest` - Run latency unit tests
