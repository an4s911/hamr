import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    // ==================== LAUNCHER STATE ====================
    property bool launcherOpen: false
    property bool superReleaseMightTrigger: true
    
    // ==================== IMAGE BROWSER ====================
    // Unified image browser that can be opened in standalone or workflow mode
    property bool imageBrowserOpen: false
    property var imageBrowserConfig: null  // { directory, title, extensions, actions, workflowId }
    property bool imageBrowserClosedBySelection: false  // Track if close was due to selection
    
    // Signal emitted when user selects an image in workflow mode
    signal imageBrowserSelected(string filePath, string actionId)
    
    // Open image browser for a workflow
    function openImageBrowserForWorkflow(config) {
        imageBrowserConfig = config;
        imageBrowserClosedBySelection = false;
        imageBrowserOpen = true;
    }
    
    // Close image browser (manual close via Escape or click-outside)
    function closeImageBrowser() {
        imageBrowserOpen = false;
        imageBrowserConfig = null;
    }
    
    // Called by ImageBrowserContent when user selects an image
    function imageBrowserSelection(filePath, actionId) {
        imageBrowserSelected(filePath, actionId);
        // Close after selection - mark that it was a selection close
        if (imageBrowserConfig?.workflowId) {
            imageBrowserClosedBySelection = true;
            closeImageBrowser();
        }
    }
}
