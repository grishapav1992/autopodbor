# Local LLM profile guard (llama.cpp + Qwen2.5-7B-Instruct)

## 1) Start local server

```powershell
cd C:\Users\grish\Downloads\llama-b7922-bin-win-cpu-x64

.\llama-server.exe `
  -m C:\llm\models\qwen2.5-7b-instruct\qwen2.5-7b-instruct-q4_k_m-00001-of-00002.gguf `
  --ctx-size 4096 `
  --threads 8 `
  --host 127.0.0.1 `
  --port 8080
```

If your CPU has more/less cores, tune `--threads`.

## 2) Quick endpoint check

```powershell
$body = @{
  model = "local-guard"
  temperature = 0
  max_tokens = 80
  messages = @(
    @{ role = "system"; content = "Ответь кратко." },
    @{ role = "user"; content = "Напиши OK" }
  )
} | ConvertTo-Json -Depth 6

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:8080/v1/chat/completions" `
  -ContentType "application/json" `
  -Body $body
```

## 3) App integration status

The app now calls local endpoint:

- desktop/web: `http://127.0.0.1:8080/v1/chat/completions`
- Android emulator: `http://10.0.2.2:8080/v1/chat/completions`

When AI detects hidden contacts, profile save is blocked with detailed errors.
