<?php

namespace LibreNMS\AiAssistant\Support;

use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use RuntimeException;

final class ProviderClient
{
    public function chat(
        array $provider,
        array $model,
        string $effort,
        array $messages,
        int $maxOutputTokens,
        int $maxResponseBytes,
        int $timeout,
        int $connectTimeout
    ): array {
        $url = $this->endpointUrl($provider);
        $client = $this->client($provider, $timeout, $connectTimeout, $maxResponseBytes);
        $driver = (string) $provider['driver'];
        $payload = match ($driver) {
            'openai_compatible' => $this->openAiChatPayload($provider, $model, $effort, $messages, $maxOutputTokens),
            'openai_responses' => $this->openAiResponsesPayload($model, $effort, $messages, $maxOutputTokens),
            'anthropic' => $this->anthropicPayload($model, $effort, $messages, $maxOutputTokens),
            default => throw new RuntimeException('The configured provider driver is unsupported.'),
        };

        $response = $client->post($url, $payload);
        if (! $response->successful()) {
            throw new RuntimeException('The AI provider returned HTTP '.$response->status().'.');
        }

        $body = $response->body();
        if (strlen($body) > $maxResponseBytes) {
            throw new RuntimeException('The AI provider response exceeded the configured size limit.');
        }

        $json = json_decode($body, true);
        if (! is_array($json)) {
            throw new RuntimeException('The AI provider returned an invalid JSON response.');
        }

        $answer = match ($driver) {
            'openai_compatible' => $this->openAiChatText($json),
            'openai_responses' => $this->openAiResponsesText($json),
            'anthropic' => $this->anthropicText($json),
        };

        if ($answer === '') {
            throw new RuntimeException('The AI provider returned no displayable text.');
        }

        return ['answer' => $answer, 'usage' => $this->usage($json)];
    }

    private function client(array $provider, int $timeout, int $connectTimeout, int $maxResponseBytes): PendingRequest
    {
        $headers = ['Accept' => 'application/json', 'Content-Type' => 'application/json'];
        $apiKey = (string) ($provider['api_key'] ?? '');
        $auth = (string) ($provider['auth'] ?? 'bearer');

        if ($auth === 'bearer') {
            $this->assertHeader('Authorization', 'Bearer '.$apiKey);
            $headers['Authorization'] = 'Bearer '.$apiKey;
        } elseif (in_array($auth, ['x-api-key', 'api-key'], true)) {
            $this->assertHeader($auth, $apiKey);
            $headers[$auth] = $apiKey;
        } elseif ($auth === 'custom') {
            $name = (string) ($provider['auth_header'] ?? 'Authorization');
            $prefix = (string) ($provider['auth_prefix'] ?? '');
            $this->assertHeader($name, $prefix.$apiKey);
            $headers[$name] = $prefix.$apiKey;
        } elseif ($auth !== 'none') {
            throw new RuntimeException('The configured authentication mode is unsupported.');
        }

        if ((string) $provider['driver'] === 'anthropic') {
            $anthropicVersion = (string) ($provider['anthropic_version'] ?? '2023-06-01');
            $this->assertHeader('anthropic-version', $anthropicVersion);
            $headers['anthropic-version'] = $anthropicVersion;
        }

        foreach ((array) ($provider['headers'] ?? []) as $name => $value) {
            if (in_array(strtolower((string) $name), ['authorization', 'x-api-key', 'api-key', 'anthropic-version'], true)) {
                throw new RuntimeException('A fixed provider header cannot override a managed authentication header.');
            }
            $this->assertHeader((string) $name, (string) $value);
            $headers[(string) $name] = (string) $value;
        }

        return Http::withHeaders($headers)
            ->acceptJson()
            ->asJson()
            ->timeout($timeout)
            ->connectTimeout($connectTimeout)
            ->withOptions([
                'verify' => (bool) ($provider['verify_tls'] ?? true),
                'allow_redirects' => false,
                'progress' => static function ($downloadTotal, $downloadedBytes) use ($maxResponseBytes): void {
                    if ($downloadedBytes > $maxResponseBytes) {
                        throw new RuntimeException('The AI provider response exceeded the configured size limit.');
                    }
                },
            ]);
    }

    private function endpointUrl(array $provider): string
    {
        $baseUrl = rtrim((string) $provider['base_url'], '/');
        $parts = parse_url($baseUrl);
        $scheme = strtolower((string) ($parts['scheme'] ?? ''));

        if (preg_match('/[\s@?#]/', $baseUrl)
            || ! in_array($scheme, ['http', 'https'], true)
            || empty($parts['host'])
            || isset($parts['user'])
            || isset($parts['pass'])
            || isset($parts['query'])
            || isset($parts['fragment'])) {
            throw new RuntimeException('The configured provider URL is invalid.');
        }

        if (! ($provider['local'] ?? false) && $scheme !== 'https') {
            throw new RuntimeException('Remote AI providers must use HTTPS.');
        }

        $defaultEndpoint = match ((string) $provider['driver']) {
            'openai_compatible' => '/chat/completions',
            'openai_responses' => '/responses',
            'anthropic' => '/v1/messages',
            default => '/',
        };
        $endpoint = (string) ($provider['endpoint'] ?? $defaultEndpoint);
        if (! str_starts_with($endpoint, '/') || preg_match('/[\s#]/', $endpoint)) {
            throw new RuntimeException('The configured provider endpoint is invalid.');
        }

        return $baseUrl.$endpoint;
    }

    private function openAiChatPayload(array $provider, array $model, string $effort, array $messages, int $maxTokens): array
    {
        $tokenParameter = (string) ($model['token_parameter'] ?? $provider['token_parameter'] ?? 'max_tokens');
        if (! in_array($tokenParameter, ['max_tokens', 'max_completion_tokens'], true)) {
            throw new RuntimeException('The configured token parameter is invalid.');
        }

        $payload = [
            'model' => (string) $model['id'],
            'messages' => $messages,
            'stream' => false,
            $tokenParameter => $maxTokens,
        ];
        if ($effort !== 'none') {
            $payload['reasoning_effort'] = $effort;
        }
        if (isset($model['temperature'])) {
            $payload['temperature'] = (float) $model['temperature'];
        }

        return $payload;
    }

    private function openAiResponsesPayload(array $model, string $effort, array $messages, int $maxTokens): array
    {
        $instructions = [];
        $input = [];
        foreach ($messages as $message) {
            if ($message['role'] === 'system') {
                $instructions[] = $message['content'];
            } else {
                $input[] = $message;
            }
        }

        $payload = [
            'model' => (string) $model['id'],
            'instructions' => implode("\n\n", $instructions),
            'input' => $input,
            'max_output_tokens' => $maxTokens,
            'stream' => false,
        ];
        if ($effort !== 'none') {
            $payload['reasoning'] = ['effort' => $effort];
        }

        return $payload;
    }

    private function anthropicPayload(array $model, string $effort, array $messages, int $maxTokens): array
    {
        $system = [];
        $conversation = [];
        foreach ($messages as $message) {
            if ($message['role'] === 'system') {
                $system[] = $message['content'];
            } else {
                $conversation[] = $message;
            }
        }

        $payload = [
            'model' => (string) $model['id'],
            'system' => implode("\n\n", $system),
            'messages' => $conversation,
            'max_tokens' => $maxTokens,
        ];
        $budget = (int) (($model['thinking_budgets'] ?? [])[$effort] ?? 0);
        if ($effort !== 'none' && $budget > 0 && $budget < $maxTokens) {
            $payload['thinking'] = ['type' => 'enabled', 'budget_tokens' => $budget];
        }

        return $payload;
    }

    private function openAiChatText(array $json): string
    {
        $content = $json['choices'][0]['message']['content'] ?? '';
        if (is_string($content)) {
            return trim($content);
        }

        return $this->contentParts($content);
    }

    private function openAiResponsesText(array $json): string
    {
        if (is_string($json['output_text'] ?? null)) {
            return trim($json['output_text']);
        }

        $parts = [];
        foreach ((array) ($json['output'] ?? []) as $output) {
            foreach ((array) ($output['content'] ?? []) as $content) {
                if (is_string($content['text'] ?? null)) {
                    $parts[] = $content['text'];
                }
            }
        }

        return trim(implode("\n", $parts));
    }

    private function anthropicText(array $json): string
    {
        return $this->contentParts($json['content'] ?? []);
    }

    private function contentParts(mixed $content): string
    {
        if (! is_array($content)) {
            return '';
        }

        $parts = [];
        foreach ($content as $part) {
            if (is_array($part) && is_string($part['text'] ?? null)) {
                $parts[] = $part['text'];
            }
        }

        return trim(implode("\n", $parts));
    }

    private function usage(array $json): array
    {
        $usage = (array) ($json['usage'] ?? []);
        $input = $usage['input_tokens'] ?? $usage['prompt_tokens'] ?? null;
        $output = $usage['output_tokens'] ?? $usage['completion_tokens'] ?? null;

        return [
            'input_tokens' => is_numeric($input) ? (int) $input : null,
            'output_tokens' => is_numeric($output) ? (int) $output : null,
        ];
    }

    private function assertHeader(string $name, string $value): void
    {
        $blocked = ['host', 'content-length', 'connection', 'transfer-encoding'];
        if (! preg_match('/^[A-Za-z0-9-]+$/', $name)
            || in_array(strtolower($name), $blocked, true)
            || preg_match('/[\r\n]/', $value)) {
            throw new RuntimeException('A configured provider header is invalid.');
        }
    }
}
