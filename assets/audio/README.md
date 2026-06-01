# Session Music audio

Layered session audio, organised one folder per layer:

```
assets/audio/01/001.mp3 … 020.mp3   (layer 1, chunks 1–20)
assets/audio/02/001.mp3 … 020.mp3   (layer 2)
assets/audio/03/...                 (layer 3)
assets/audio/04/...                 (layer 4)
assets/audio/05/...                 (layer 5)
```

- Folder name = layer, zero-padded to 2 digits (`01`–`05`).
- File name = chunk, zero-padded to 3 digits (`001`–`020`), `.mp3`.
- The same chunk number across layers should be the *same* musical passage with
  progressively richer instrumentation (stems), ideally the *same length* — a
  layer change keeps the current playback position and swaps in the fuller mix.

Each layer folder is registered individually under `flutter: assets:` in
`pubspec.yaml` (Flutter does not include subfolders recursively). The playback
engine (`lib/providers/session_music_provider.dart`) resolves paths from the
live layer/chunk state via `sessionMusicAssetPath()`.
