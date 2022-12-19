### Whisper models

Whisper.cpp model files aren't included in this repo to keep the size down.

To download the models:
1. Clone [Whisper.cpp](https://github.com/ggerganov/whisper.cpp)
2. Run `bash ./models/download-ggml-model.sh [model name]` (smaller is faster)
3. Copy the model to [Xcode project root]/NeoPixel Tree/Whisper Models/
4. Update the path string in the call to instantiate `Transcriber`


### Running

Important note: For some reason debug builds are prohibitively slow on physical devices. Running a release build fixes this.

