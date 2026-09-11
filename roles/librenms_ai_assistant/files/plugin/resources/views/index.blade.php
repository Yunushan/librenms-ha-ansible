@extends('layouts.librenmsv1')

@section('title', 'AI Assistant')

@section('content')
<div class="container-fluid ai-assistant" id="ai-assistant">
    <div class="row">
        <div class="col-lg-10 col-lg-offset-1">
            <div class="panel panel-default">
                <div class="panel-heading ai-assistant__heading">
                    <div>
                        <strong><i class="fa fa-comments" aria-hidden="true"></i> AI Assistant</strong>
                        @if($device)
                            <span class="text-muted">/ {{ $device->displayName() }}</span>
                        @endif
                    </div>
                    <span class="label label-default" id="assistant-status">Ready</span>
                </div>

                <div class="panel-body ai-assistant__controls">
                    <div class="row">
                        <div class="col-sm-4 form-group">
                            <label for="assistant-provider">Provider</label>
                            <select class="form-control" id="assistant-provider"></select>
                        </div>
                        <div class="col-sm-4 form-group">
                            <label for="assistant-model">Model</label>
                            <select class="form-control" id="assistant-model"></select>
                        </div>
                        <div class="col-sm-4 form-group">
                            <label>Reasoning effort</label>
                            <div class="btn-group btn-group-sm ai-assistant__efforts" id="assistant-efforts" role="group" data-toggle="buttons"></div>
                        </div>
                    </div>
                </div>

                <div class="ai-assistant__conversation" id="assistant-conversation" aria-live="polite">
                    <div class="ai-assistant__empty text-muted" id="assistant-empty">Conversation is empty.</div>
                </div>

                <form class="panel-footer ai-assistant__composer" id="assistant-form">
                    @csrf
                    <input type="hidden" id="assistant-device-id" value="{{ $device?->device_id }}">
                    <label class="sr-only" for="assistant-prompt">Message</label>
                    <textarea class="form-control" id="assistant-prompt" rows="3" maxlength="{{ (int) $maxPromptChars }}" required></textarea>
                    <div class="ai-assistant__actions">
                        <label class="checkbox-inline">
                            <input type="checkbox" id="assistant-context"> Include monitoring context
                        </label>
                        <div>
                            <button class="btn btn-default" type="button" id="assistant-clear" title="Clear conversation">
                                <i class="fa fa-trash" aria-hidden="true"></i><span class="sr-only">Clear conversation</span>
                            </button>
                            <button class="btn btn-primary" type="submit" id="assistant-send">
                                <i class="fa fa-paper-plane" aria-hidden="true"></i> Send
                            </button>
                        </div>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>

<style>
    .ai-assistant { padding-top: 15px; }
    .ai-assistant__heading, .ai-assistant__actions { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
    .ai-assistant__controls { border-bottom: 1px solid #d6d9dc; padding-bottom: 5px; }
    .ai-assistant__efforts { display: flex; min-height: 30px; flex-wrap: wrap; }
    .ai-assistant__conversation { min-height: 320px; max-height: 58vh; overflow-y: auto; padding: 16px; background: #f7f8f9; }
    .dark .ai-assistant__conversation { background: #252a2e; }
    .ai-assistant__empty { padding: 80px 16px; text-align: center; }
    .ai-assistant__message { max-width: 86%; margin-bottom: 12px; padding: 10px 12px; border: 1px solid #d6d9dc; border-radius: 4px; white-space: pre-wrap; overflow-wrap: anywhere; background: #fff; }
    .dark .ai-assistant__message { background: #30363b; border-color: #4a5157; }
    .ai-assistant__message--user { margin-left: auto; border-left: 4px solid #337ab7; }
    .ai-assistant__message--assistant { margin-right: auto; border-left: 4px solid #3c8d40; }
    .ai-assistant__links { display: flex; flex-wrap: wrap; gap: 8px; margin: -4px 0 14px; }
    .ai-assistant__composer textarea { resize: vertical; min-height: 74px; }
    .ai-assistant__actions { margin-top: 10px; }
    @media (max-width: 767px) {
        .ai-assistant__heading, .ai-assistant__actions { align-items: flex-start; flex-direction: column; }
        .ai-assistant__message { max-width: 96%; }
        .ai-assistant__conversation { min-height: 260px; max-height: 50vh; }
    }
</style>

<script>
document.addEventListener('DOMContentLoaded', function () {
    'use strict';

    const providers = {{ Illuminate\Support\Js::from($providers) }};
    const endpoint = {{ Illuminate\Support\Js::from(route('librenms-ai-assistant.chat')) }};
    const maxMessages = {{ (int) $maxMessages }};
    const state = { messages: [] };
    const providerSelect = document.getElementById('assistant-provider');
    const modelSelect = document.getElementById('assistant-model');
    const efforts = document.getElementById('assistant-efforts');
    const form = document.getElementById('assistant-form');
    const prompt = document.getElementById('assistant-prompt');
    const conversation = document.getElementById('assistant-conversation');
    const empty = document.getElementById('assistant-empty');
    const send = document.getElementById('assistant-send');
    const status = document.getElementById('assistant-status');

    function option(value, label) {
        const item = document.createElement('option');
        item.value = value;
        item.textContent = label;
        return item;
    }

    function selectedProvider() {
        return providers.find(item => item.id === providerSelect.value) || providers[0];
    }

    function selectedModel() {
        const provider = selectedProvider();
        return provider.models.find(item => item.id === modelSelect.value) || provider.models[0];
    }

    function renderModels() {
        const provider = selectedProvider();
        modelSelect.replaceChildren();
        provider.models.forEach(model => modelSelect.appendChild(option(model.id, model.label)));
        modelSelect.value = provider.default_model;
        renderEfforts();
        document.getElementById('assistant-context').disabled = !provider.context_enabled;
    }

    function renderEfforts() {
        const model = selectedModel();
        efforts.replaceChildren();
        model.efforts.forEach((effort, index) => {
            const label = document.createElement('label');
            label.className = 'btn btn-default';
            const input = document.createElement('input');
            input.type = 'radio';
            input.name = 'assistant-effort';
            input.value = effort;
            input.autocomplete = 'off';
            const checked = effort === model.default_effort || (index === 0 && !model.efforts.includes(model.default_effort));
            input.checked = checked;
            if (checked) label.classList.add('active');
            label.appendChild(input);
            label.appendChild(document.createTextNode(' ' + effort));
            efforts.appendChild(label);
        });
    }

    function addMessage(role, content) {
        empty.hidden = true;
        const message = document.createElement('div');
        message.className = 'ai-assistant__message ai-assistant__message--' + role;
        message.textContent = content;
        conversation.appendChild(message);
        conversation.scrollTop = conversation.scrollHeight;
    }

    function addLinks(links) {
        if (!Array.isArray(links) || links.length === 0) return;
        const container = document.createElement('div');
        container.className = 'ai-assistant__links';
        links.forEach(link => {
            try {
                const target = new URL(link.url, window.location.origin);
                if (target.origin !== window.location.origin) return;
                const anchor = document.createElement('a');
                anchor.className = 'btn btn-default btn-xs';
                anchor.href = target.href;
                const icon = document.createElement('i');
                icon.className = 'fa ' + String(link.icon || 'fa-link');
                icon.setAttribute('aria-hidden', 'true');
                anchor.appendChild(icon);
                anchor.appendChild(document.createTextNode(' ' + String(link.label || 'Open')));
                container.appendChild(anchor);
            } catch (error) {
                return;
            }
        });
        if (container.childElementCount > 0) conversation.appendChild(container);
    }

    providers.forEach(provider => providerSelect.appendChild(option(provider.id, provider.label)));
    providerSelect.addEventListener('change', renderModels);
    modelSelect.addEventListener('change', renderEfforts);
    renderModels();

    document.getElementById('assistant-clear').addEventListener('click', function () {
        state.messages = [];
        conversation.querySelectorAll('.ai-assistant__message, .ai-assistant__links').forEach(node => node.remove());
        empty.hidden = false;
        prompt.focus();
    });

    form.addEventListener('submit', async function (event) {
        event.preventDefault();
        const content = prompt.value.trim();
        if (!content || send.disabled) return;

        state.messages.push({ role: 'user', content: content });
        state.messages = state.messages.slice(-maxMessages);
        addMessage('user', content);
        prompt.value = '';
        send.disabled = true;
        status.textContent = 'Working';
        status.className = 'label label-info';

        const selectedEffort = document.querySelector('input[name="assistant-effort"]:checked');
        try {
            const response = await fetch(endpoint, {
                method: 'POST',
                credentials: 'same-origin',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': form.querySelector('input[name="_token"]').value,
                    'X-Requested-With': 'XMLHttpRequest'
                },
                body: JSON.stringify({
                    provider: providerSelect.value,
                    model: modelSelect.value,
                    effort: selectedEffort ? selectedEffort.value : 'none',
                    messages: state.messages,
                    include_context: document.getElementById('assistant-context').checked,
                    device_id: document.getElementById('assistant-device-id').value || null
                })
            });
            const result = await response.json().catch(() => ({}));
            if (!response.ok) throw new Error(result.message || 'The request failed.');
            state.messages.push({ role: 'assistant', content: result.answer });
            state.messages = state.messages.slice(-maxMessages);
            addMessage('assistant', result.answer);
            addLinks(result.links);
            status.textContent = 'Ready';
            status.className = 'label label-success';
        } catch (error) {
            addMessage('assistant', error.message || 'The request failed.');
            status.textContent = 'Unavailable';
            status.className = 'label label-danger';
        } finally {
            send.disabled = false;
            prompt.focus();
        }
    });
});
</script>
@endsection
