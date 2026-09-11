<?php

namespace LibreNMS\AiAssistant\Support;

use Illuminate\Contracts\Auth\Authenticatable;
use RuntimeException;

final class ConfigRepository
{
    private ?array $config = null;

    public function authorized(?Authenticatable $user): bool
    {
        if ($user === null || ! method_exists($user, 'can')) {
            return false;
        }

        return (bool) $user->can($this->authorization());
    }

    public function authorization(): string
    {
        $permission = (string) ($this->all()['authorization'] ?? 'global-read');

        return in_array($permission, ['global-read', 'admin'], true) ? $permission : 'admin';
    }

    public function providersForUi(): array
    {
        $providers = [];

        foreach ($this->providers() as $provider) {
            $models = [];
            foreach ($provider['models'] as $model) {
                $efforts = array_values(array_intersect(
                    (array) ($model['efforts'] ?? ['none']),
                    ['none', 'minimal', 'low', 'medium', 'high', 'xhigh']
                ));
                $models[] = [
                    'id' => (string) $model['id'],
                    'label' => (string) ($model['label'] ?? $model['id']),
                    'efforts' => $efforts ?: ['none'],
                    'default_effort' => (string) ($model['default_effort'] ?? 'none'),
                ];
            }

            $providers[] = [
                'id' => (string) $provider['id'],
                'label' => (string) ($provider['label'] ?? $provider['id']),
                'description' => (string) ($provider['description'] ?? ''),
                'default_model' => (string) $provider['default_model'],
                'context_enabled' => (bool) ($provider['context_enabled'] ?? false),
                'models' => $models,
            ];
        }

        return $providers;
    }

    public function provider(string $providerId): array
    {
        foreach ($this->providers() as $provider) {
            if (hash_equals((string) $provider['id'], $providerId)) {
                return $provider;
            }
        }

        throw new RuntimeException('The selected provider is not configured.');
    }

    public function model(array $provider, string $modelId): array
    {
        foreach ($provider['models'] as $model) {
            if (hash_equals((string) $model['id'], $modelId)) {
                return $model;
            }
        }

        throw new RuntimeException('The selected model is not configured for this provider.');
    }

    public function validateEffort(array $model, string $effort): string
    {
        $allowed = (array) ($model['efforts'] ?? ['none']);

        if (! in_array($effort, $allowed, true)) {
            throw new RuntimeException('The selected reasoning effort is not configured for this model.');
        }

        return $effort;
    }

    public function contextEnabled(array $provider): bool
    {
        return (bool) ($this->all()['context']['enabled'] ?? false)
            && (bool) ($provider['context_enabled'] ?? false);
    }

    public function deviceOverviewEnabled(): bool
    {
        return (bool) ($this->all()['context']['device_overview_enabled'] ?? false);
    }

    public function systemPrompt(): string
    {
        return trim((string) ($this->all()['system_prompt'] ?? ''));
    }

    public function limit(string $name, int $default): int
    {
        return max(1, (int) ($this->all()['limits'][$name] ?? $default));
    }

    private function providers(): array
    {
        $providers = $this->all()['providers'] ?? [];

        if (! is_array($providers) || $providers === []) {
            throw new RuntimeException('No AI providers are configured.');
        }

        return $providers;
    }

    private function all(): array
    {
        if ($this->config !== null) {
            return $this->config;
        }

        $path = getenv('LIBRENMS_AI_ASSISTANT_CONFIG') ?: '/etc/librenms-ai-assistant/config.json';
        if (! is_readable($path)) {
            throw new RuntimeException('The AI assistant server configuration is unavailable.');
        }

        $decoded = json_decode((string) file_get_contents($path), true);
        if (! is_array($decoded) || ($decoded['version'] ?? null) !== 1) {
            throw new RuntimeException('The AI assistant server configuration is invalid.');
        }

        return $this->config = $decoded;
    }
}
