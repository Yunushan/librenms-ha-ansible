<?php

namespace LibreNMS\AiAssistant\Support;

use App\Models\Device;
use Illuminate\Support\Facades\DB;
use Throwable;

final class ContextBuilder
{
    public function build(?Device $device): array
    {
        $context = [
            'generated_at' => now()->toIso8601String(),
            'scope' => 'read-only monitoring summary',
        ];

        try {
            $context['devices'] = [
                'total' => DB::table('devices')->count(),
                'enabled' => DB::table('devices')->where('disabled', 0)->count(),
                'up' => DB::table('devices')->where('disabled', 0)->where('status', 1)->count(),
                'down' => DB::table('devices')->where('disabled', 0)->where('status', 0)->count(),
            ];
        } catch (Throwable) {
            $context['devices'] = ['status' => 'unavailable'];
        }

        try {
            $context['active_alerts'] = DB::table('alerts')->where('state', 1)->count();
        } catch (Throwable) {
            $context['active_alerts'] = 'unavailable';
        }

        if ($device !== null) {
            $context['selected_device'] = [
                'device_id' => (int) $device->device_id,
                'hostname' => (string) $device->hostname,
                'display_name' => (string) ($device->sysName ?: $device->hostname),
                'status' => (bool) $device->status ? 'up' : 'down',
                'disabled' => (bool) $device->disabled,
                'os' => (string) $device->os,
                'hardware' => (string) $device->hardware,
                'purpose' => (string) $device->purpose,
                'uptime_seconds' => (int) $device->uptime,
                'last_polled' => (string) $device->last_polled,
                'last_discovered' => (string) $device->last_discovered,
            ];
        }

        return $context;
    }
}
