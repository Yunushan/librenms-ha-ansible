<?php

namespace LibreNMS\AiAssistant\Support;

use App\Models\Device;

final class NavigationResolver
{
    private const DESTINATIONS = [
        ['terms' => ['alert', 'alarm'], 'label' => 'Alerts', 'path' => '/alerts', 'icon' => 'fa-exclamation-triangle'],
        ['terms' => ['device', 'host', 'node'], 'label' => 'Devices', 'path' => '/devices', 'icon' => 'fa-server'],
        ['terms' => ['poller', 'dispatcher'], 'label' => 'Pollers', 'path' => '/poller', 'icon' => 'fa-tasks'],
        ['terms' => ['port', 'interface'], 'label' => 'Ports', 'path' => '/ports', 'icon' => 'fa-exchange'],
        ['terms' => ['health', 'sensor', 'cpu', 'memory', 'storage'], 'label' => 'Health', 'path' => '/health', 'icon' => 'fa-heartbeat'],
        ['terms' => ['service'], 'label' => 'Services', 'path' => '/services', 'icon' => 'fa-cogs'],
        ['terms' => ['event', 'log'], 'label' => 'Event log', 'path' => '/eventlog', 'icon' => 'fa-bookmark'],
        ['terms' => ['map', 'topology'], 'label' => 'Availability map', 'path' => '/availability-map', 'icon' => 'fa-map'],
        ['terms' => ['inventory'], 'label' => 'Inventory', 'path' => '/inventory', 'icon' => 'fa-cube'],
        ['terms' => ['validate', 'diagnostic'], 'label' => 'Validate configuration', 'path' => '/validate', 'icon' => 'fa-check-circle'],
    ];

    public function suggest(string $prompt, ?Device $device, int $limit): array
    {
        $prompt = mb_strtolower($prompt);
        $links = [];

        if ($device !== null) {
            $links[] = $this->link(
                'Open '.($device->sysName ?: $device->hostname),
                '/device/'.(int) $device->device_id,
                'fa-server'
            );
        }

        foreach (self::DESTINATIONS as $destination) {
            foreach ($destination['terms'] as $term) {
                if (str_contains($prompt, $term)) {
                    $links[] = $this->link($destination['label'], $destination['path'], $destination['icon']);
                    break;
                }
            }

            if (count($links) >= $limit) {
                break;
            }
        }

        return array_slice($links, 0, $limit);
    }

    private function link(string $label, string $path, string $icon): array
    {
        if (! preg_match('#^/[A-Za-z0-9/_?&=.%:-]+$#', $path) || str_starts_with($path, '//')) {
            return [];
        }

        return ['label' => $label, 'url' => $path, 'icon' => $icon];
    }
}
