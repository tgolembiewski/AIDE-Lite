// ============================================================================
// AIDE Lite - WebView Communication Bridge
// C# <-> JS message passing via WebView2 (Windows) or WKWebView (macOS).
// ============================================================================
(function (AIDE) {
    'use strict';

    var state = AIDE.state;
    var isWebView2 = !!(window.chrome && window.chrome.webview);
    var isWebKit = !!(window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.studioPro);

    AIDE.sendToBackend = function (type, payload) {
        var msg = { message: type, data: payload || {} };
        if (isWebView2) {
            window.chrome.webview.postMessage(msg);
        } else if (isWebKit) {
            window.webkit.messageHandlers.studioPro.postMessage(JSON.stringify(msg));
        } else {
            console.log('WebView bridge not available. Message:', type, payload);
        }
    };

    AIDE.handleMessage = function (event) {
        var envelope = (typeof event === 'string') ? JSON.parse(event) : (event.data || event);
        if (!envelope || typeof envelope.message !== 'string') return;
        var type = envelope.message;
        var data = envelope.data;
        AIDE.handleBackendMessage(type, data);
    };

    AIDE.handleBackendMessage = function (type, data) {
        switch (type) {
            case 'chat_streaming':
                AIDE.handleStreamChunk(data);
                break;
            case 'tool_start':
                AIDE.handleToolStart(data);
                break;
            case 'tool_result':
                AIDE.handleToolResult(data);
                break;
            case 'context_loaded':
                AIDE.handleContextLoaded(data);
                break;
            case 'microflow_created':
                AIDE.handleMicroflowCreated(data);
                break;
            case 'model_changed':
                AIDE.handleModelChanged(data);
                break;
            case 'token_usage':
                AIDE.handleTokenUsage(data);
                break;
            case 'retry_wait':
                AIDE.handleRetryWait(data);
                break;
            case 'history_list':
                AIDE.handleHistoryList(data);
                break;
            case 'conversation_loaded':
                AIDE.handleConversationLoaded(data);
                break;
            case 'error':
                AIDE.handleError(data);
                break;
            case 'load_settings':
                AIDE.handleLoadSettings(data);
                break;
            case 'settings_saved':
                AIDE.handleSettingsSaved(data);
                break;
            case 'skip_auto_load':
                state.set('skipAutoLoadConversation', true);
                state.set('autoLoadPending', false);
                break;
            case 'active_document_changed':
                AIDE.handleActiveDocumentChanged(data);
                break;
            case 'auto_explain':
                AIDE.handleAutoExplain(data);
                break;
            case 'document_referenced':
                AIDE.handleDocumentReferenced(data);
                break;
            case 'consent_required':
                AIDE.handleConsentRequired();
                break;
            case 'consent_saved':
                AIDE.handleConsentSaved();
                break;
            case 'set_view_mode':
                AIDE.handleSetViewMode(data);
                break;
            case 'toast':
                AIDE.showToast(data.message);
                break;
            case 'restore_view_state':
                AIDE.handleRestoreViewState(data);
                break;
        }
    };

    AIDE.initBridge = function () {
        if (isWebView2) {
            window.chrome.webview.addEventListener('message', AIDE.handleMessage);
        } else if (isWebKit) {
            // WKWebView batches evaluateJavaScript calls and executes them
            // all before yielding to the render loop. Buffer messages and
            // drain one per animation frame for visible streaming output.
            var wkQueue = [];
            var wkDraining = false;
            function wkDrain() {
                if (wkQueue.length === 0) { wkDraining = false; return; }
                AIDE.handleMessage(wkQueue.shift());
                requestAnimationFrame(wkDrain);
            }
            window.WKPostMessage = function (json) {
                wkQueue.push(json);
                if (!wkDraining) { wkDraining = true; requestAnimationFrame(wkDrain); }
            };
        }
        AIDE.sendToBackend('MessageListenerRegistered');
    };

})(window.AIDE = window.AIDE || {});
