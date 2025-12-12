import QtQuick
import Quickshell

QtObject {
    enum IconType { Material, Text, System, None }
    enum FontType { Normal, Monospace }
    enum ResultType { Standard, WorkflowEntry, WorkflowResult, Card }

    // Unique key for ScriptModel identity (prevents flicker on updates)
    property string key: id || name || ""
    
    // General stuff
    property string type: ""
    property var fontType: LauncherSearchResult.FontType.Normal
    property string name: ""
    property string rawValue: ""
    property string iconName: ""
    property var iconType: LauncherSearchResult.IconType.None
    property string verb: ""
    property bool blurImage: false
    property var execute: () => {
        print("Not implemented");
    }
    property var actions: []
    
    // Tab completion support
    property bool acceptsArguments: false  // True for quicklinks, actions that take args
    property string completionText: ""     // Text to complete to (e.g., "github " for quicklink)
    
    // Stuff needed for DesktopEntry 
    property string id: ""
    property bool shown: true
    property string comment: ""
    property bool runInTerminal: false
    property string genericName: ""
    property list<string> keywords: []

    // Extra stuff to allow for more flexibility
    property string category: type
    
    // ==================== WORKFLOW SUPPORT ====================
    // Result type for different rendering modes
    property var resultType: LauncherSearchResult.ResultType.Standard
    
    // Workflow identification (for workflow results)
    property string workflowId: ""      // ID of the workflow this result belongs to
    property string workflowItemId: ""  // ID of the item within workflow results
    
    // Card display (for ResultType.Card)
    property string cardTitle: ""
    property string cardContent: ""
    property bool cardMarkdown: false
    
    // Workflow actions (from workflow result's actions array)
    // Each action: { id, name, icon }
    property var workflowActions: []
    
    // Thumbnail image path (for workflow results with images)
    property string thumbnail: ""
}
