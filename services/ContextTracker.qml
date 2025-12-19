pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // Current Hyprland context
    readonly property string currentWorkspace: Hyprland.focusedMonitor?.activeWorkspace?.name ?? ""
    readonly property int currentWorkspaceId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? -1
    readonly property string currentMonitor: Hyprland.focusedMonitor?.name ?? ""
    
    // Session tracking
    property bool isNewSession: false
    property real sessionStartTime: 0
    
    // DPMS tracking (screen on/off for idle detection)
    property bool dpmsWasOff: false
    property real dpmsOnTime: 0
    readonly property int dpmsResumeWindowMs: 5 * 60 * 1000  // 5 minutes after screen on
    
    // Last launched app tracking (for sequence detection)
    property string lastLaunchedApp: ""
    property real lastLaunchTime: 0
    readonly property int sequenceWindowMs: 10 * 60 * 1000  // 10 minutes
    
    // Running apps context (for co-occurrence suggestions)
    readonly property var runningAppIds: {
        const apps = new Set();
        const workspaces = Hyprland.workspaces?.values ?? [];
        for (const ws of workspaces) {
            const toplevels = ws.toplevels?.values ?? [];
            for (const toplevel of toplevels) {
                const appClass = toplevel.lastIpcObject?.class ?? "";
                if (appClass) {
                    apps.add(appClass.toLowerCase());
                }
            }
        }
        return Array.from(apps);
    }
    
    // Check if we're within the sequence window of the last launch
    function isWithinSequenceWindow() {
        if (!lastLaunchedApp || lastLaunchTime === 0) return false;
        return (Date.now() - lastLaunchTime) < sequenceWindowMs;
    }
    
    // Record an app launch for sequence tracking
    function recordLaunch(appId) {
        lastLaunchedApp = appId;
        lastLaunchTime = Date.now();
    }
    
    // Check if this is the first launch of the session
    function isSessionStart() {
        if (!isNewSession) return false;
        const timeSinceSessionStart = Date.now() - sessionStartTime;
        return timeSinceSessionStart < 5 * 60 * 1000;  // Within 5 minutes of session start
    }
    
    // Check if user just returned from idle (DPMS was off, now on)
    function isResumeFromIdle() {
        if (!dpmsWasOff || dpmsOnTime === 0) return false;
        const timeSinceResume = Date.now() - dpmsOnTime;
        return timeSinceResume < dpmsResumeWindowMs;
    }
    
    // Get context object for suggestion calculation
    function getContext() {
        const now = new Date();
        return {
            currentHour: now.getHours(),
            currentDay: now.getDay() === 0 ? 6 : now.getDay() - 1,  // Monday=0, Sunday=6
            workspace: currentWorkspace,
            workspaceId: currentWorkspaceId,
            monitor: currentMonitor,
            lastApp: isWithinSequenceWindow() ? lastLaunchedApp : "",
            isSessionStart: isSessionStart(),
            isResumeFromIdle: isResumeFromIdle(),
            runningApps: runningAppIds
        };
    }
    
    // Initialize session tracking
    Component.onCompleted: {
        if (Persistent.isNewHyprlandInstance) {
            isNewSession = true;
            sessionStartTime = Date.now();
        }
    }
    
    // Listen for Hyprland events for additional context
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const eventName = event.name;
            
            if (eventName === "dpms") {
                // DPMS event format: "dpms>>STATE,MONITOR" where STATE is 0 (off) or 1 (on)
                const data = event.data ?? "";
                const parts = data.split(",");
                const state = parts[0];
                
                if (state === "0") {
                    // Screen turned off - user going idle
                    root.dpmsWasOff = true;
                } else if (state === "1" && root.dpmsWasOff) {
                    // Screen turned on after being off - user returning from idle
                    root.dpmsOnTime = Date.now();
                }
            }
        }
    }
}
