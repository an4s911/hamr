pragma Singleton
import Quickshell

/**
 * Calculator utilities for detecting and preprocessing math expressions.
 * Works with qalc (qalculate) for evaluation.
 * 
 * Supports:
 *   - Basic math: "2+2", "sqrt(16)", "sin(pi/2)"
 *   - Temperature: "10c", "34f", "10 celsius to fahrenheit"
 *   - Currency: "$50", "S$100", "100 USD to EUR", "€50 in JPY"
 *   - Units: "10ft to m", "5 miles to km", "100kg to lb"
 *   - Percentages: "20% of 32", "15% off 100"
 *   - Time: "10:30 + 2h"
 */
Singleton {
    id: root

    // ==================== PATTERNS ====================
    
    // Math functions
    readonly property var mathFunctionPattern: /^(sin|cos|tan|asin|acos|atan|sinh|cosh|tanh|sqrt|cbrt|log|ln|exp|abs|ceil|floor|round|factorial|rand)\s*\(/i
    
    // Basic math expression with operators
    readonly property var mathExpressionPattern: /^[\d\.\(\)\+\-\*\/\^\%\s]*([\+\-\*\/\^\%][\d\.\(\)\+\-\*\/\^\%\s]*)+$/

    // Temperature: "10c", "34f", "-5°C", "10 celsius"
    readonly property var temperaturePattern: /^-?\d+\.?\d*\s*°?[cf](\s|$)|^-?\d+\.?\d*\s*(celsius|fahrenheit)/i

    // Currency symbols (single character)
    readonly property var currencySymbolsSimple: /^[$€£¥₹₽₩₪฿₫₴₸₺₼₾]/

    // Currency with country prefix: "S$", "HK$", "A$", "C$", "NZ$", "NT$", "R$", "MX$"
    readonly property var currencySymbolsPrefixed: /^(S|HK|A|C|NZ|NT|R|MX)\$\s*\d/i

    // ISO currency codes (with optional space: "USD 100", "USD100", "VND 1,000,000")
    readonly property var currencyCodesPattern: /^(USD|EUR|GBP|JPY|CNY|SGD|AUD|CAD|CHF|HKD|NZD|SEK|NOK|DKK|KRW|INR|RUB|BRL|MXN|ZAR|TRY|THB|MYR|IDR|PHP|VND|PLN|CZK|HUF|ILS|AED|SAR|TWD|BTC|ETH)\s*[\d,]/i

    // Number followed by currency code
    readonly property var numberCurrencyPattern: /^\d+\.?\d*\s*(USD|EUR|GBP|JPY|CNY|SGD|AUD|CAD|CHF|HKD|NZD|SEK|NOK|DKK|KRW|INR|RUB|BRL|MXN|ZAR|TRY|THB|MYR|IDR|PHP|VND|PLN|CZK|HUF|ILS|AED|SAR|TWD|BTC|ETH)\b/i

    // Unit patterns: "10ft", "5 miles", "100kg"
    readonly property var unitPattern: /^\d+\.?\d*\s*(ft|feet|foot|in|inch|inches|mi|mile|miles|yd|yard|yards|m|meter|meters|metre|metres|cm|km|mm|nm|kg|kilogram|kilograms|g|gram|grams|lb|lbs|pound|pounds|oz|ounce|ounces|L|liter|liters|litre|litres|ml|gal|gallon|gallons|pt|pint|pints|cup|cups|tbsp|tsp|mph|km\/h|kmh|kph|m\/s|knot|knots|hp|kw|watt|watts|joule|joules|cal|calorie|calories|btu|byte|bytes|kb|mb|gb|tb|bit|bits|kbit|mbit|gbit)\b/i

    // Percentage with "of": "20% of 32"
    readonly property var percentOfPattern: /\d+\.?\d*\s*%\s*(of|off)\s+/i

    // Time arithmetic: "10:30 + 2h", "5pm"
    readonly property var timePattern: /^\d{1,2}:\d{2}(:\d{2})?\s*[\+\-]|^\d{1,2}\s*(am|pm)\b/i

    // ==================== CURRENCY MAPS ====================
    
    // Simple currency symbols -> ISO codes
    readonly property var currencySymbolMap: ({
        '$': 'USD',
        '€': 'EUR',
        '£': 'GBP',
        '¥': 'JPY',
        '₹': 'INR',
        '₽': 'RUB',
        '₩': 'KRW',
        '₪': 'ILS',
        '฿': 'THB',
        '₫': 'VND',
        '₴': 'UAH',
        '₸': 'KZT',
        '₺': 'TRY',
        '₼': 'AZN',
        '₾': 'GEL'
    })

    // Prefixed currency symbols -> ISO codes
    readonly property var currencyPrefixMap: ({
        'S$': 'SGD',
        'HK$': 'HKD',
        'A$': 'AUD',
        'C$': 'CAD',
        'NZ$': 'NZD',
        'NT$': 'TWD',
        'R$': 'BRL',
        'MX$': 'MXN'
    })

    // ==================== DETECTION ====================

    /**
     * Check if query looks like a math/calculator expression.
     * @param {string} query - The search query
     * @param {string} mathPrefix - The math prefix (e.g., "=")
     * @returns {boolean}
     */
    function isMathExpression(query, mathPrefix) {
        const trimmed = query.trim();
        if (!trimmed) return false;

        // Explicit math prefix always triggers math
        if (mathPrefix && trimmed.startsWith(mathPrefix)) return true;

        // Starts with digit or decimal point
        if (/^[\d\.]/.test(trimmed)) return true;

        // Starts with simple currency symbol ($, €, £, etc.)
        if (currencySymbolsSimple.test(trimmed)) return true;

        // Starts with prefixed currency symbol (S$, HK$, etc.)
        if (currencySymbolsPrefixed.test(trimmed)) return true;

        // Starts with operator (implies previous answer)
        if (/^[\+\-\*\/\^]/.test(trimmed)) return true;

        // Starts with opening parenthesis
        if (trimmed.startsWith('(')) return true;

        // Starts with math function
        if (mathFunctionPattern.test(trimmed)) return true;

        // Temperature pattern
        if (temperaturePattern.test(trimmed)) return true;

        // Currency code at start (e.g., "USD 100", "SGD 50")
        if (currencyCodesPattern.test(trimmed)) return true;

        // Time pattern
        if (timePattern.test(trimmed)) return true;

        // Contains math operators between numbers
        if (mathExpressionPattern.test(trimmed)) return true;

        return false;
    }

    // ==================== PREPROCESSING ====================

    /**
     * Preprocess a query into qalc-friendly syntax.
     * Normalizes natural language patterns.
     * @param {string} query - The search query
     * @param {string} mathPrefix - The math prefix to strip (e.g., "=")
     * @returns {string}
     */
    function preprocessExpression(query, mathPrefix) {
        let expr = query.trim();

        // Strip math prefix if present
        if (mathPrefix && expr.startsWith(mathPrefix)) {
            expr = expr.slice(mathPrefix.length).trim();
        }

        // Remove thousand separators from numbers: "1,000,000" -> "1000000"
        // Only remove commas between digits (not decimal commas in locales that use them)
        expr = preprocessThousandSeparators(expr);

        // Temperature shorthand: "10c" -> "10 celsius", "34f" -> "34 fahrenheit"
        expr = preprocessTemperature(expr);

        // Currency symbols to codes: "$50" -> "50 USD", "S$100" -> "100 SGD"
        expr = preprocessCurrency(expr);

        // Percentage operations: "20% of 32" -> "20% * 32"
        expr = preprocessPercentage(expr);

        // Normalize "in" to "to" for conversions
        expr = preprocessConversion(expr);

        return expr;
    }

    /**
     * Remove thousand separators from numbers.
     * "1,000,000" -> "1000000"
     * "1,000.50" -> "1000.50"
     */
    function preprocessThousandSeparators(expr) {
        // Match commas that are between digits (thousand separators)
        // Pattern: digit, comma, 3 digits (repeating)
        return expr.replace(/(\d),(?=\d{3}(?:,\d{3})*(?:\.\d+)?(?:\s|$|[a-zA-Z]))/g, '$1');
    }

    /**
     * Preprocess temperature shorthand.
     * "10c" -> "10 celsius to fahrenheit"
     * "34f" -> "34 fahrenheit to celsius"
     */
    function preprocessTemperature(expr) {
        // Match: 10c, 10C, 10°c, -5c, 10.5c (but not 10cm, 10cal, etc.)
        // Only match when c/f is at end or followed by space/conversion
        let result = expr;

        // "10c" or "10°c" at end or before space -> "10 celsius"
        result = result.replace(/^(-?\d+\.?\d*)\s*°?c(\s+to\s+|\s+in\s+|\s*$)/i, "$1 celsius$2");
        result = result.replace(/^(-?\d+\.?\d*)\s*°?f(\s+to\s+|\s+in\s+|\s*$)/i, "$1 fahrenheit$2");

        // Auto-add conversion target for standalone temperature
        if (/^-?\d+\.?\d*\s+celsius\s*$/i.test(result)) {
            result += " to fahrenheit";
        } else if (/^-?\d+\.?\d*\s+fahrenheit\s*$/i.test(result)) {
            result += " to celsius";
        }

        return result;
    }

    // All ISO currency codes for preprocessing
    readonly property var allCurrencyCodes: [
        'USD', 'EUR', 'GBP', 'JPY', 'CNY', 'SGD', 'AUD', 'CAD', 'CHF', 'HKD',
        'NZD', 'SEK', 'NOK', 'DKK', 'KRW', 'INR', 'RUB', 'BRL', 'MXN', 'ZAR',
        'TRY', 'THB', 'MYR', 'IDR', 'PHP', 'VND', 'PLN', 'CZK', 'HUF', 'ILS',
        'AED', 'SAR', 'TWD', 'BTC', 'ETH'
    ]

    /**
     * Preprocess currency symbols to ISO codes.
     * "$50" -> "50 USD"
     * "S$100" -> "100 SGD"
     * "sgd100" -> "100 SGD"
     * "USD20.20" -> "20.20 USD"
     * "VND 1,000,000" -> "1,000,000 VND" (commas removed by preprocessThousandSeparators)
     */
    function preprocessCurrency(expr) {
        let result = expr;

        // Handle prefixed symbols first (S$, HK$, etc.) - must be before simple $
        // Include comma in number pattern for thousand separators
        for (const [prefix, code] of Object.entries(currencyPrefixMap)) {
            // Escape the $ for regex
            const escapedPrefix = prefix.replace('$', '\\$');
            const regex = new RegExp(escapedPrefix + '\\s*([\\d,]+\\.?\\d*)', 'gi');
            result = result.replace(regex, `$1 ${code}`);
        }

        // Handle simple symbols ($, €, £, etc.)
        for (const [symbol, code] of Object.entries(currencySymbolMap)) {
            // Escape special regex characters
            const escaped = symbol.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const regex = new RegExp(escaped + '\\s*([\\d,]+\\.?\\d*)', 'g');
            result = result.replace(regex, `$1 ${code}`);
        }

        // Handle currency code before number without space: "sgd100" -> "100 SGD", "USD20.20" -> "20.20 USD"
        // Only at the start of expression to avoid matching in middle of text
        const codesPattern = allCurrencyCodes.join('|');
        const codeBeforeNumberRegex = new RegExp(`^(${codesPattern})\\s*([\\d,]+\\.?\\d*)`, 'i');
        const match = result.match(codeBeforeNumberRegex);
        if (match) {
            // Reorder: "SGD100" -> "100 SGD", "VND 1,000,000" -> "1,000,000 VND"
            result = result.replace(codeBeforeNumberRegex, `$2 ${match[1].toUpperCase()}`);
        }

        return result;
    }

    /**
     * Preprocess percentage operations.
     * "20% of 32" -> "20% * 32"
     * "15% off 100" -> "100 - 15%"
     */
    function preprocessPercentage(expr) {
        let result = expr;

        // "X% of Y" -> "X% * Y"
        result = result.replace(/(\d+\.?\d*\s*%)\s+of\s+/gi, "$1 * ");

        // "X% off Y" -> "Y - X%" (qalc's simplified percentage handles this)
        result = result.replace(/(\d+\.?\d*)\s*%\s+off\s+(\d+\.?\d*)/gi, "$2 - $1%");

        return result;
    }

    /**
     * Normalize "in" to "to" for unit/currency conversions.
     * "100 USD in EUR" -> "100 USD to EUR"
     */
    function preprocessConversion(expr) {
        // Only convert "in" to "to" when it looks like a conversion
        // (has a number before and unit/currency after)
        if (/\d.*\s+in\s+\w+$/i.test(expr) && !expr.toLowerCase().includes(' to ')) {
            return expr.replace(/\s+in\s+(\w+)$/i, " to $1");
        }
        return expr;
    }

    // ==================== RESULT VALIDATION ====================

    /**
     * Check if qalc result looks like an error or unhelpful response.
     * @param {string} result - The qalc output
     * @param {string} query - The original query
     * @returns {boolean} - true if result is valid/useful
     */
    function isValidResult(result, query) {
        if (!result || !result.trim()) return false;

        const trimmedResult = result.trim();
        const trimmedQuery = query.trim();

        // Result is same as input (no calculation happened)
        if (trimmedResult === trimmedQuery) return false;

        // qalc error indicators
        if (trimmedResult.startsWith('error:')) return false;
        if (trimmedResult.includes('was not found')) return false;

        return true;
    }
}
