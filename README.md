# Apple On-Device OpenAI API Enhanced with Multi-Server Functionality

A SwiftUI application that creates an OpenAI-compatible API server using Apple's on-device Foundation Models. This allows you to use Apple Intelligence models locally through familiar OpenAI API endpoints.

<br></br>
## Screenshots with Configurations and Open-Webui Usage
- [Link to SCREENSHOT-SAMPLES.md](SCREENSHOT-SAMPLES.md)

<br></br>
## Features

- **OpenAI Compatible API**: Drop-in replacement for OpenAI API with chat completions endpoint
- **Streaming Support**: Real-time streaming responses compatible with OpenAI's streaming format
- **On-Device Processing**: Uses Apple's Foundation Models for completely local AI processing
- **Model Availability Check**: Automatically checks Apple Intelligence availability on startup
- **🚧 Tool Using (WIP)**: Function calling capabilities for extended AI functionality

<br></br>
## Requirements

- **macOS**: 26 beta 2 or greater
- **Apple Intelligence**: Must be enabled in Settings > Apple Intelligence & Siri
- **Xcode**: 26 beta 2 or greater ***(MUST match OS version for building)***

<br></br>
## Building and Installation
- [Link to BUILDING-or-INSTALLATION.md](BUILDING-or-INSTALLATION.md)

<br></br>
## Why a GUI App Instead of Command Line?

This project is implemented as a GUI application rather than a command-line tool due to **Apple's rate limiting policies** for Foundation Models:

> "An app that has UI and runs in the foreground doesn't have a rate limit when using the models; a macOS command line tool, which doesn't have UI, does."
> 
> — Apple DTS Engineer ([Source](https://developer.apple.com/forums/thread/787737))

**⚠️ Important Note**: You may still encounter rate limits due to current limitations in Apple FoundationModels. If you experience rate limiting, please restart the server.

**⚠️ 重要提醒**: 由于苹果 FoundationModels 当前的限制，您仍然可能遇到速率限制。如果遇到这种情况，请重启服务器。

<br></br>
## Usage

### Starting the Server

1. Launch the app
2. Configure server settings (default: `127.0.0.1:11535`)
3. Click "Start Server"
4. Server will be available at the configured address

<br></br>
### Available Endpoints

Once the server is running, you can access these OpenAI-compatible endpoints:

- `GET /health` - Health check
- `GET /status` - Model availability and status
- `GET /v1/models` - List available models
- `POST /v1/chat/completions` - Chat completions (streaming and non-streaming)

<br></br>
### Example Usage

#### Using curl:

```bash
curl -X POST http://127.0.0.1:11535/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple-on-device",
    "messages": [
      {"role": "user", "content": "Hello, how are you?"}
    ],
    "temperature": 0.7,
    "stream": false
  }'
```

<br></br>
#### Using OpenAI Python client:

```python
from openai import OpenAI

# Point to your local server
client = OpenAI(
    base_url="http://127.0.0.1:11535/v1",
    api_key="not-needed"  # API key not required for local server
)

response = client.chat.completions.create(
    model="apple-on-device",
    messages=[
        {"role": "user", "content": "Hello, how are you?"}
    ],
    temperature=0.7,
    stream=True  # Enable streaming
)

for chunk in response:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

<br></br>
## OpenAI Compatability and Tips
- [Link to OPENAI-TIPS.md](OPENAI-TIPS.md)

<br></br>
## Testing and Development Notes
- [Link to TESTING-and-DEVELOPMENT-NOTES.md](TESTING-and-DEVELOPMENT-NOTES.md)

<br></br>
## License

This project is licensed under the MIT License - see the LICENSE file for details.

<br></br>
## References

- [Apple Foundation Models Documentation](https://developer.apple.com/documentation/foundationmodels)
- [OpenAI API Documentation](https://platform.openai.com/docs/api-reference) 

<br></br>
