# Gemini Streaming Chat Demo (Flutter)

A Flutter chat application integrating **Google Gemini** via streaming API responses, similar to ChatGPT-style token-by-token rendering. Built to gain hands-on, production-style experience with LLM integration in mobile apps.

## Features

- **Streaming responses** — model output renders incrementally as it's generated, not all at once
- **Persistent chat session** — conversation history is automatically maintained across turns using Gemini's `ChatSession`
- **System instruction** — model behaviour is configured via a system prompt
- **Configurable generation parameters** — temperature and max output tokens are tunable
- **Clean chat UI** — user/model message bubbles, auto-scroll, loading indicators
- **Secure API key handling** — key is loaded from a local `.env` file, excluded from version control

## Tech Stack

- **Flutter** & **Dart**
- **google_generative_ai** — official Gemini Dart/Flutter SDK
- **flutter_dotenv** — environment variable management for secure API key storage

## How It Works

1. On app start, the Gemini API key is loaded from `.env` and a `GenerativeModel` is initialized with a system instruction and generation config
2. A `ChatSession` is started, which automatically tracks conversation history across turns
3. When the user sends a message, `sendMessageStream()` is called instead of a single blocking request
4. The response arrives as a stream of text chunks; each chunk is appended to the current message in real time, creating a streaming/typing effect
5. UI auto-scrolls and shows a small loading indicator while a response is still streaming

## Setup

1. Get a free Gemini API key from [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Create a `.env` file in the project root:
   ```
   GEMINI_API_KEY=your_actual_api_key_here
   ```
3. Add `.env` to `.gitignore` (never commit API keys)
4. Run:
   ```bash
   flutter pub get
   flutter run
   ```

## Why This Project

Built to gain real, hands-on experience integrating a Large Language Model into a Flutter mobile application — specifically focused on streaming response handling, chat session/state management, and secure API key practices, which are common requirements in modern AI-augmented mobile engineering roles.

## Possible Extensions

- Persist chat history locally (Hive/SQLite) across app restarts
- Add image input support (Gemini supports multimodal prompts)
- Add a "Retrieval-Augmented Generation" layer — feed in a custom document and have the model answer questions grounded in it
- Add markdown rendering for formatted model responses