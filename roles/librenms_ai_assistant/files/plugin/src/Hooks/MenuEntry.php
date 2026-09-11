<?php

namespace LibreNMS\AiAssistant\Hooks;

use Illuminate\Support\Facades\Auth;
use LibreNMS\AiAssistant\Support\ConfigRepository;
use LibreNMS\Interfaces\Plugins\Hooks\MenuEntryHook;

final class MenuEntry implements MenuEntryHook
{
    public function authorize(): bool
    {
        return app(ConfigRepository::class)->authorized(Auth::user());
    }

    public function handle(string $pluginName): array
    {
        return ["$pluginName::menu", []];
    }
}
