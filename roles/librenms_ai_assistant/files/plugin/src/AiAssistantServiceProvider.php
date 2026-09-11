<?php

namespace LibreNMS\AiAssistant;

use Illuminate\Foundation\Console\AboutCommand;
use Illuminate\Support\ServiceProvider;
use LibreNMS\AiAssistant\Hooks\DeviceOverview;
use LibreNMS\AiAssistant\Hooks\MenuEntry;
use LibreNMS\AiAssistant\Support\ConfigRepository;
use LibreNMS\Interfaces\Plugins\Hooks\DeviceOverviewHook;
use LibreNMS\Interfaces\Plugins\Hooks\MenuEntryHook;
use LibreNMS\Interfaces\Plugins\PluginManagerInterface;

final class AiAssistantServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(ConfigRepository::class, fn (): ConfigRepository => new ConfigRepository());
    }

    public function boot(PluginManagerInterface $pluginManager): void
    {
        $pluginName = 'librenms-ai-assistant';

        $pluginManager->publishHook($pluginName, MenuEntryHook::class, MenuEntry::class);
        $pluginManager->publishHook($pluginName, DeviceOverviewHook::class, DeviceOverview::class);

        if (! $pluginManager->pluginEnabled($pluginName)) {
            return;
        }

        AboutCommand::add('LibreNMS AI Assistant', fn (): array => ['Version' => '1.0.0']);
        $this->loadRoutesFrom(__DIR__.'/../routes/web.php');
        $this->loadViewsFrom(__DIR__.'/../resources/views', $pluginName);
    }
}
