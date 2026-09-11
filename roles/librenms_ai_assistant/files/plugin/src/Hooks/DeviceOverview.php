<?php

namespace LibreNMS\AiAssistant\Hooks;

use App\Models\Device;
use Illuminate\Contracts\View\View;
use Illuminate\Support\Facades\Auth;
use LibreNMS\AiAssistant\Support\ConfigRepository;
use LibreNMS\Interfaces\Plugins\Hooks\DeviceOverviewHook;

final class DeviceOverview implements DeviceOverviewHook
{
    public function authorize(Device $device): bool
    {
        $config = app(ConfigRepository::class);
        $user = Auth::user();

        return $config->deviceOverviewEnabled()
            && $config->authorized($user)
            && (bool) $user?->can('view', $device);
    }

    public function handle(Device $device): View
    {
        return view('librenms-ai-assistant::device-overview', ['device' => $device]);
    }
}
