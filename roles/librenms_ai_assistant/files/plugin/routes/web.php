<?php

use Illuminate\Support\Facades\Route;
use LibreNMS\AiAssistant\Http\Controllers\AssistantController;

Route::middleware(['web', 'auth'])->prefix('plugin/ai-assistant')->name('librenms-ai-assistant.')->group(function (): void {
    Route::get('/', [AssistantController::class, 'index'])->name('index');
    Route::post('/chat', [AssistantController::class, 'chat'])
        ->middleware('throttle:10,1')
        ->name('chat');
});
