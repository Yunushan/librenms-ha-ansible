<div class="panel panel-default panel-condensed">
    <div class="panel-heading">
        <strong>AI Assistant</strong>
    </div>
    <div class="panel-body">
        <a class="btn btn-default btn-sm" href="{{ route('librenms-ai-assistant.index', ['device_id' => $device->device_id]) }}">
            <i class="fa fa-comments" aria-hidden="true"></i>
            Ask about {{ $device->displayName() }}
        </a>
    </div>
</div>
