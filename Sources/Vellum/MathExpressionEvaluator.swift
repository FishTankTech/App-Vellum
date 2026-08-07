import Foundation

// MARK: - Tokens

private enum MathToken: Equatable {
    case number(Double)
    case identifier(String)
    case plus, minus, star, slash, caret, percent
    case lparen, rparen
}

private enum MathTokenizer {
    /// Returns nil the moment it hits a character that isn't part of a math
    /// expression. This is also the primary "is this line even math?" filter —
    /// prose, bullet points, and most non-math text will contain a character
    /// (a letter outside a known function name, a colon, a comma, etc.) that
    /// fails tokenization immediately.
    static func tokenize(_ input: String) -> [MathToken]? {
        var tokens: [MathToken] = []
        let chars = Array(input)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if c.isWhitespace {
                i += 1
                continue
            }

            if c.isNumber || (c == "." && i + 1 < chars.count && chars[i + 1].isNumber) {
                var numStr = ""
                var sawDot = false

                while i < chars.count, chars[i].isNumber || (chars[i] == "." && !sawDot) {
                    if chars[i] == "." { sawDot = true }
                    numStr.append(chars[i])
                    i += 1
                }

                guard let value = Double(numStr) else { return nil }
                tokens.append(.number(value))
                continue
            }

            if c.isLetter {
                var word = ""

                while i < chars.count, chars[i].isLetter {
                    word.append(chars[i])
                    i += 1
                }

                tokens.append(.identifier(word.lowercased()))
                continue
            }

            switch c {
            case "+": tokens.append(.plus)
            case "-": tokens.append(.minus)
            case "*", "\u{00D7}": tokens.append(.star) // allow "*" as multiply
            case "/", "\u{00F7}": tokens.append(.slash) // allow "÷" as divide
            case "^": tokens.append(.caret)
            case "%": tokens.append(.percent)
            case "(": tokens.append(.lparen)
            case ")": tokens.append(.rparen)
            default:
                return nil
            }

            i += 1
        }

        return tokens
    }
}

// MARK: - Parser

/// Simple recursive-descent parser/evaluator.
/// Grammar (lowest to highest precedence):
///   expression := term (('+' | '-') term)*
///   term       := power (('*' | '/' | '%') power)*
///   power      := unary ('^' power)?        (right-associative)
///   unary      := ('-' | '+')? primary
///   primary    := number | constant | function '(' expression ')' | '(' expression ')'
private final class MathParser {
    private let tokens: [MathToken]
    private var pos = 0

    private static let constants: [String: Double] = [
        "pi": Double.pi,
        "e": M_E
    ]

    private static let functions: Set<String> = [
        "sqrt", "abs", "sin", "cos", "tan",
        "asin", "acos", "atan", "log", "ln",
        "exp", "round", "floor", "ceil"
    ]

    init(_ tokens: [MathToken]) {
        self.tokens = tokens
    }

    private var current: MathToken? {
        pos < tokens.count ? tokens[pos] : nil
    }

    /// Parses the full token stream. Returns nil on any malformed or
    /// partial expression (e.g. "3 +", "(4 * 2", "sqrt(") rather than
    /// throwing, so callers can treat "not valid yet" as a normal case
    /// while the person is mid-keystroke.
    func parse() -> Double? {
        guard let value = parseExpression(), pos == tokens.count else {
            return nil
        }
        return value
    }

    private func parseExpression() -> Double? {
        guard var left = parseTerm() else { return nil }

        while let op = current, op == .plus || op == .minus {
            pos += 1
            guard let right = parseTerm() else { return nil }
            left = (op == .plus) ? left + right : left - right
        }

        return left
    }

    private func parseTerm() -> Double? {
        guard var left = parsePower() else { return nil }

        while let op = current, op == .star || op == .slash || op == .percent {
            pos += 1
            guard let right = parsePower() else { return nil }

            switch op {
            case .star:
                left *= right
            case .slash:
                guard right != 0 else { return nil }
                left /= right
            case .percent:
                guard right != 0 else { return nil }
                left = left.truncatingRemainder(dividingBy: right)
            default:
                break
            }
        }

        return left
    }

    private func parsePower() -> Double? {
        guard let base = parseUnary() else { return nil }

        if current == .caret {
            pos += 1
            guard let exponent = parsePower() else { return nil } // right-associative
            guard abs(exponent) <= 1000 else { return nil } // guard against absurd/hung formatting
            return pow(base, exponent)
        }

        return base
    }

    private func parseUnary() -> Double? {
        if current == .minus {
            pos += 1
            guard let value = parseUnary() else { return nil }
            return -value
        }

        if current == .plus {
            pos += 1
            return parseUnary()
        }

        return parsePrimary()
    }

    private func parsePrimary() -> Double? {
        guard let token = current else { return nil }

        switch token {
        case .number(let value):
            pos += 1
            return value

        case .lparen:
            pos += 1
            guard let value = parseExpression() else { return nil }
            guard current == .rparen else { return nil }
            pos += 1
            return value

        case .identifier(let name):
            pos += 1

            if let constant = Self.constants[name] {
                return constant
            }

            guard Self.functions.contains(name), current == .lparen else { return nil }
            pos += 1
            guard let arg = parseExpression() else { return nil }
            guard current == .rparen else { return nil }
            pos += 1

            switch name {
            case "sqrt": return arg >= 0 ? sqrt(arg) : nil
            case "abs": return abs(arg)
            case "sin": return sin(arg)
            case "cos": return cos(arg)
            case "tan": return tan(arg)
            case "asin": return (arg >= -1 && arg <= 1) ? asin(arg) : nil
            case "acos": return (arg >= -1 && arg <= 1) ? acos(arg) : nil
            case "atan": return atan(arg)
            case "log": return arg > 0 ? log10(arg) : nil
            case "ln": return arg > 0 ? log(arg) : nil
            case "exp": return exp(arg)
            case "round": return arg.rounded()
            case "floor": return arg.rounded(.down)
            case "ceil": return arg.rounded(.up)
            default: return nil
            }

        default:
            return nil
        }
    }
}

// MARK: - Public API

enum MathExpressionEvaluator {

    struct Result {
        let value: Double
        let formatted: String
    }

    // Pure numeric/operator strings that read as math to the tokenizer but
    // are almost always something else in a notes app. Reject them outright.
    private static let dateLikePattern = try! NSRegularExpression(
        pattern: #"^\d{1,4}[/-]\d{1,2}[/-]\d{1,4}$"#
    )

    private static let phoneLikePattern = try! NSRegularExpression(
        pattern: #"^\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}$"#
    )

    /// Evaluates a single line of text as a math expression, if it looks
    /// like one. Returns nil for anything that isn't confidently math:
    /// prose, partial/invalid expressions, bare numbers, dates, phone
    /// numbers, or anything that would divide by zero / go non-finite.
    static func evaluate(_ line: String) -> Result? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Allow a trailing "=" the person already typed, e.g. "12 + 3 ="
        var expression = trimmed
        if expression.hasSuffix("=") {
            expression.removeLast()
            expression = expression.trimmingCharacters(in: .whitespaces)
        }
        guard !expression.isEmpty else { return nil }

        guard !matches(dateLikePattern, expression),
              !matches(phoneLikePattern, expression) else {
            return nil
        }

        guard let tokens = MathTokenizer.tokenize(expression), tokens.count > 1 else {
            // Single-token lines (a bare number, a bare word) aren't
            // "expressions" worth evaluating.
            return nil
        }

        guard let value = MathParser(tokens).parse(), value.isFinite else {
            return nil
        }

        return Result(value: value, formatted: format(value))
    }

    private static func matches(_ regex: NSRegularExpression, _ string: String) -> Bool {
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }

    private static func format(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }

        var formatted = String(format: "%.6f", value)
        while formatted.hasSuffix("0") {
            formatted.removeLast()
        }
        if formatted.hasSuffix(".") {
            formatted.removeLast()
        }
        return formatted
    }
}
