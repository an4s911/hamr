pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root
    
    readonly property var matchType: ({
        EXACT: 3,
        PREFIX: 2,
        FUZZY: 1,
        NONE: 0
    })
    
    function getFrecencyScore(historyItem) {
        if (!historyItem) return 0;
        const now = Date.now();
        const hoursSinceUse = (now - historyItem.lastUsed) / (1000 * 60 * 60);
        
        let recencyMultiplier;
        if (hoursSinceUse < 1) recencyMultiplier = 4;
        else if (hoursSinceUse < 24) recencyMultiplier = 2;
        else if (hoursSinceUse < 168) recencyMultiplier = 1;
        else recencyMultiplier = 0.5;
        
        return historyItem.count * recencyMultiplier;
    }
    
    function getMatchType(query, target) {
        if (!query || !target) return root.matchType.NONE;
        const q = query.toLowerCase();
        const t = target.toLowerCase();
        if (t === q) return root.matchType.EXACT;
        if (t.startsWith(q)) return root.matchType.PREFIX;
        return root.matchType.FUZZY;
    }
    
    // Single composite score for efficient sorting (avoids multi-field comparison)
    // fuzzyScore is in 0-1 range (normalized), frecency is typically 0-50
    function getCompositeScore(matchType, fuzzyScore, frecency) {
        // Base score from fuzzy match (0-1 range, scale up for precision)
        let score = fuzzyScore * 1000;
        
        // Match type bonuses (moderate - shouldn't completely override good fuzzy scores)
        if (matchType === root.matchType.EXACT) {
            score += 500;  // Exact history term match
        } else if (matchType === root.matchType.PREFIX) {
            score += 200;
        }
        
        // Frecency bonus (scaled appropriately)
        // frecency typically ranges 0-50 (count * recencyMultiplier)
        // Cap at 300 to not overwhelm fuzzy score differences
        score += Math.min(frecency * 5, 300);
        
        return score;
    }
    
    // Compare using composite scores (faster than multi-field comparison)
    function compareByCompositeScore(a, b) {
        return b.compositeScore - a.compositeScore;
    }
}
