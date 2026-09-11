# LibreNMS AI Assistant

The optional AI assistant is a LibreNMS v2 Composer plugin deployed by the
`librenms_ai_assistant` role. It adds an **AI Assistant** entry under the
LibreNMS Plugins menu and, when enabled, a shortcut on device overview pages.
It is disabled by default.

The assistant is intentionally read-only. It sends text and a small optional
monitoring summary to one operator-configured model endpoint, displays the
returned text, and offers links chosen from a fixed set of LibreNMS paths. It
does not expose LibreNMS write APIs, shell commands, model tools, or automatic
redirects.

## Protocol coverage

Three adapters cover most local and hosted text-generation services:

| Driver | Request API | Typical uses |
|---|---|---|
| `openai_compatible` | `POST /chat/completions` | Ollama, LocalAI, LM Studio, llama.cpp server, vLLM, SGLang, TGI-compatible gateways, text-generation-webui, KoboldCpp, Jan, GPT4All, MLX-LM, Aphrodite, TabbyAPI, and hosted OpenAI-compatible APIs |
| `openai_responses` | `POST /responses` | OpenAI and compatible servers that implement the Responses API |
| `anthropic` | `POST /v1/messages` | Anthropic or an Anthropic-compatible gateway |

The first adapter can also be used with hosted services such as Azure OpenAI,
Google Gemini's OpenAI compatibility layer, Mistral, Groq, xAI, DeepSeek,
OpenRouter, Together, Fireworks, Cerebras, Perplexity, GitHub Models, NVIDIA
NIM, SambaNova, Cloudflare AI Gateway, or an internal API gateway when that
service exposes a compatible non-streaming chat-completions endpoint.

Compatibility is protocol-based, not a promise that every model supports every
parameter. Configure only model IDs and effort values tested against your
endpoint. For a server that rejects `reasoning_effort`, expose only `none` for
that model. Ollama, vLLM, LocalAI, and LM Studio all document OpenAI-compatible
HTTP endpoints:

- <https://docs.ollama.com/api/openai-compatibility>
- <https://docs.vllm.ai/en/latest/serving/online_serving/openai_compatible_server/>
- <https://localai.io/docs/>
- <https://lmstudio.ai/docs/developer/openai-compat>

## Complete model scope

The complete supported model set is endpoint-defined; the plugin has no
built-in model-name allowlist. A model is usable when all of these conditions
are true:

1. The configured endpoint accepts one of the three request APIs above.
2. It accepts non-streaming text input and returns text in the corresponding
   OpenAI chat-completions, OpenAI Responses, or Anthropic Messages shape.
3. Its exact model ID is present in the operator-managed `models` allowlist.
4. Any configured effort, temperature, and token-limit options are accepted by
   that endpoint and model.

This includes text and chat variants in the GPT, Claude, Gemini, Llama,
Mistral/Mixtral/Codestral, Qwen, DeepSeek, Grok, Phi, Gemma, Granite, Command,
Nemotron, GLM, Yi, Falcon, InternLM, MiniCPM, StarCoder, Code Llama, and DBRX
families when a configured endpoint serves them through a compatible API. It
also includes custom or fine-tuned text models served by any compatible local
runtime or gateway listed above.

The plugin does not automatically discover models. Query the provider's model
catalog, then copy only approved IDs into the Ansible configuration. Most
OpenAI-compatible endpoints expose `GET /models`; for example:

```bash
curl -fsS -H "Authorization: Bearer ${API_KEY}" "${BASE_URL}/models"
curl -fsS http://127.0.0.1:11434/v1/models
```

Image-only, embedding, moderation, transcription, speech, and realtime-only
models are outside the plugin's text-chat contract. Streaming-only endpoints,
tool-call-only responses, and nonstandard response bodies require a compatible
gateway or an additional adapter.

## Security boundary

- All plugin routes require an authenticated LibreNMS session. Chat is a POST
  route protected by Laravel CSRF middleware and a ten-requests-per-minute
  throttle.
- Users need `global-read` by default. Set
  `librenms_ai_assistant_authorization: admin` for administrators only.
- Provider URLs, headers, and API keys are loaded from
  `/etc/librenms-ai-assistant/config.json`, owned by `root:librenms` with mode
  `0640`. They are never included in page data or API responses.
- Provider and model IDs are selected from the server-side allowlist. Browser
  input cannot supply an arbitrary endpoint, header, or model.
- Remote providers must use HTTPS with certificate verification. Plain HTTP is
  accepted only when that provider has `local: true`.
- Redirect following is disabled for provider calls. Custom `Host`,
  `Content-Length`, `Connection`, and `Transfer-Encoding` headers are rejected.
- Provider downloads are aborted at a configurable byte ceiling even if an
  endpoint ignores the requested output-token limit.
- Model text is inserted with DOM `textContent`; it is not interpreted as HTML
  or Markdown. Navigation URLs are generated from fixed server-side paths and
  checked as same-origin again in the browser.
- Prompts are kept only in browser memory. The plugin does not create a chat
  table or log prompt/response bodies. The selected provider may retain data;
  review its policy before enabling monitoring context.

The optional context contains aggregate device counts, active-alert count, and
basic fields for a selected device. It excludes passwords, API keys, SNMP
credentials, configuration files, and raw database records. The model receives
an explicit instruction to treat monitoring fields as untrusted data.

## Configure a local server

This example expects Ollama on every LibreNMS web node. In HA, replace
`127.0.0.1` with a protected shared inference endpoint when only one model
server exists.

```yaml
librenms_ai_assistant_enabled: true
librenms_ai_assistant_authorization: global-read
librenms_ai_assistant_providers:
  - id: ollama
    label: Local Ollama
    description: On-node private inference
    driver: openai_compatible
    base_url: http://127.0.0.1:11434/v1
    local: true
    auth: none
    verify_tls: false
    context_enabled: true
    default_model: llama3.2
    models:
      - id: llama3.2
        label: Llama 3.2
        efforts: [none, low, medium, high]
        default_effort: none
```

Other common local base URLs are:

| Server | Example base URL |
|---|---|
| LocalAI | `http://127.0.0.1:8080/v1` |
| LM Studio | `http://127.0.0.1:1234/v1` |
| llama.cpp server | `http://127.0.0.1:8080/v1` |
| vLLM | `http://127.0.0.1:8000/v1` |
| SGLang | `http://127.0.0.1:30000/v1` |

Bind a local server to loopback when it runs on the LibreNMS node. For a shared
server, use firewall rules, authentication, and preferably internal TLS. This
role integrates endpoints; it does not install or lifecycle-manage model
runtimes.

## Configure hosted APIs

Put credentials in `inventories/ha/group_vars/vault.yml` or the corresponding
standalone vault file:

```yaml
vault_librenms_ai_openai_api_key: REPLACE_WITH_SECRET
vault_librenms_ai_anthropic_api_key: REPLACE_WITH_SECRET
```

Encrypt the file before committing it:

```bash
ansible-vault encrypt inventories/ha/group_vars/vault.yml
```

OpenAI Responses example:

```yaml
librenms_ai_assistant_providers:
  - id: openai
    label: OpenAI
    driver: openai_responses
    base_url: https://api.openai.com/v1
    auth: bearer
    api_key: "{{ vault_librenms_ai_openai_api_key }}"
    verify_tls: true
    context_enabled: false
    default_model: REPLACE_WITH_APPROVED_MODEL_ID
    models:
      - id: REPLACE_WITH_APPROVED_MODEL_ID
        label: Approved OpenAI model
        efforts: [none, low, medium, high]
        default_effort: medium
```

Anthropic Messages example:

```yaml
librenms_ai_assistant_providers:
  - id: anthropic
    label: Anthropic
    driver: anthropic
    base_url: https://api.anthropic.com
    auth: x-api-key
    api_key: "{{ vault_librenms_ai_anthropic_api_key }}"
    anthropic_version: "2023-06-01"
    verify_tls: true
    context_enabled: false
    default_model: REPLACE_WITH_APPROVED_MODEL_ID
    models:
      - id: REPLACE_WITH_APPROVED_MODEL_ID
        label: Approved Anthropic model
        efforts: [none]
        default_effort: none
```

For Anthropic extended thinking, add effort values and explicit token budgets
below the model. A budget is applied only when it is positive and smaller than
`librenms_ai_assistant_max_output_tokens`:

```yaml
        efforts: [none, low, medium]
        default_effort: low
        thinking_budgets:
          low: 512
          medium: 900
```

Azure-style endpoints can use `auth: api-key` and an endpoint containing a
reviewed API-version query string. Custom gateways can use `auth: custom` with
`auth_header` and `auth_prefix`, plus a `headers` mapping. All values remain in
the protected server-side file.

## Deploy

Run the focused playbook after the provider configuration and vault are ready:

```bash
make ai-assistant-ask-become-pass \
  PLAYBOOK_FLAGS="--ask-vault-pass"
```

The normal `make site` workflow also deploys the plugin when
`librenms_ai_assistant_enabled` is true. Both workflows process active web
nodes serially and exclude `maintenance_nodes`.

The role copies the bundled package to
`/opt/librenms-local-plugins/librenms-ai-assistant`, registers its Composer path
repository through LibreNMS, enables `librenms-ai-assistant`, rebuilds the route
cache, and verifies both plugin routes. Open **Overview > Plugins > AI
Assistant** after the play completes.

## Provider options

| Key | Required | Meaning |
|---|---:|---|
| `id`, `label` | yes | Stable internal ID and displayed name |
| `driver` | yes | `openai_compatible`, `openai_responses`, or `anthropic` |
| `base_url` | yes | Operator-controlled API root without credentials, query, or fragment; never accepted from a browser |
| `endpoint` | no | Override the driver's default path and optional reviewed query string |
| `local` | no | Allows HTTP for a trusted local/private endpoint |
| `auth` | no | `none`, `bearer`, `x-api-key`, `api-key`, or `custom` |
| `api_key` | when authenticated | Secret value, normally supplied by Ansible Vault |
| `headers` | no | Additional fixed server-side headers |
| `verify_tls` | remote providers | Must be true for remote endpoints |
| `context_enabled` | no | Allows the context checkbox for this provider |
| `default_model`, `models` | yes | Exact operator-approved model allowlist |

An OpenAI-compatible model may set `token_parameter` to `max_tokens` or
`max_completion_tokens`, and may set a numeric `temperature`. Each model has an
`efforts` list selected from `none`, `minimal`, `low`, `medium`, `high`, and
`xhigh`.

Global request bounds are controlled by
`librenms_ai_assistant_max_messages`, `librenms_ai_assistant_max_prompt_chars`,
`librenms_ai_assistant_max_output_tokens`,
`librenms_ai_assistant_max_response_bytes`, and the connect/request timeout
settings. Monitoring context is always unchecked until the user explicitly
enables it for a configured provider.

## Disable

Disable the plugin on one active application node; the shared LibreNMS database
stores the plugin state for all web nodes:

```bash
sudo -u librenms /opt/librenms/lnms plugin:disable librenms-ai-assistant
sudo -u librenms php /opt/librenms/artisan route:clear
```

Then set `librenms_ai_assistant_enabled: false`. The protected provider file is
left in place so disabling the feature does not destroy vaulted configuration
or force an unreviewed Composer removal during a normal site run.
