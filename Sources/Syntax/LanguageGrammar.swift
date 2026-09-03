import Foundation

/// How one family of languages is tokenised.
///
/// Deliberately coarse: a viewer needs code to be *readable at a glance*, not
/// parsed. A table-driven scanner covers far more languages per line of code
/// than a real grammar would, and degrades to plain text rather than to
/// something wrong.
struct LanguageGrammar {
    var lineComments: [String] = []
    var blockComments: [(open: String, close: String)] = []
    var stringDelimiters: Set<Character> = ["\"", "'"]
    /// Delimiters that may span lines, such as Swift/JS backticks.
    var multilineStringDelimiters: Set<Character> = []
    var escapeCharacter: Character? = "\\"
    var keywords: Set<String> = []
    /// Built-in types, constants and literals — coloured as `.type`.
    var types: Set<String> = []
    var caseInsensitiveKeywords = false
    /// `key:` and `key =` are highlighted as attributes (JSON, YAML, CSS).
    var highlightsAssignmentKeys = false
    /// Tag-structured markup rather than code.
    var isMarkup = false

    func isKeyword(_ word: String) -> Bool {
        caseInsensitiveKeywords ? keywords.contains(word.lowercased()) : keywords.contains(word)
    }

    func isType(_ word: String) -> Bool {
        caseInsensitiveKeywords ? types.contains(word.lowercased()) : types.contains(word)
    }
}

enum Grammars {

    /// Maps a fence's language tag to a grammar. Unknown tags return nil and
    /// the block renders unhighlighted.
    static func grammar(for language: String?) -> LanguageGrammar? {
        guard let raw = language?.lowercased().trimmingCharacters(in: .whitespaces),
              !raw.isEmpty
        else { return nil }
        return byName[raw]
    }

    private static let cFamilyKeywords: Set<String> = [
        "abstract", "as", "assert", "async", "await", "break", "case", "catch",
        "class", "const", "constructor", "continue", "declare", "default",
        "defer", "delete", "do", "else", "enum", "export", "extends", "extension",
        "final", "finally", "for", "from", "func", "function", "get", "guard",
        "if", "impl", "implements", "import", "in", "init", "instanceof",
        "interface", "internal", "is", "let", "match", "mod", "module", "mut",
        "namespace", "new", "of", "open", "operator", "override", "package",
        "private", "protected", "protocol", "public", "pub", "readonly", "record",
        "return", "sealed", "set", "static", "struct", "super", "switch",
        "synchronized", "this", "throw", "throws", "trait", "try", "type",
        "typealias", "typeof", "union", "unsafe", "use", "var", "virtual", "void",
        "where", "while", "with", "yield", "fn", "lazy", "inout", "some", "any",
        "required", "convenience", "deinit", "subscript", "willSet", "didSet",
        "associatedtype", "indirect", "nonisolated", "actor", "throw",
    ]

    private static let cFamilyTypes: Set<String> = [
        "Array", "Bool", "Character", "Dictionary", "Double", "Float", "Int",
        "Int8", "Int16", "Int32", "Int64", "UInt", "String", "Set", "Optional",
        "Void", "Data", "Date", "URL", "Error", "Result", "Task", "Never",
        "boolean", "byte", "char", "double", "float", "int", "long", "number",
        "object", "short", "string", "symbol", "unknown", "undefined", "null",
        "nil", "true", "false", "self", "Self", "None", "usize", "i8", "i16",
        "i32", "i64", "u8", "u16", "u32", "u64", "f32", "f64", "str", "String",
        "Vec", "Option", "Box", "HashMap", "error", "interface{}",
    ]

    private static let cLike = LanguageGrammar(
        lineComments: ["//"],
        blockComments: [("/*", "*/")],
        stringDelimiters: ["\"", "'"],
        multilineStringDelimiters: ["`"],
        keywords: cFamilyKeywords,
        types: cFamilyTypes
    )

    private static let python = LanguageGrammar(
        lineComments: ["#"],
        blockComments: [("\"\"\"", "\"\"\""), ("'''", "'''")],
        keywords: [
            "and", "as", "assert", "async", "await", "break", "class", "continue",
            "def", "del", "elif", "else", "except", "finally", "for", "from",
            "global", "if", "import", "in", "is", "lambda", "nonlocal", "not",
            "or", "pass", "raise", "return", "try", "while", "with", "yield",
            "match", "case",
        ],
        types: [
            "True", "False", "None", "self", "cls", "int", "float", "str", "bool",
            "list", "dict", "set", "tuple", "bytes", "object", "type", "Any",
            "Optional", "List", "Dict", "Union", "Callable",
        ]
    )

    private static let shell = LanguageGrammar(
        lineComments: ["#"],
        keywords: [
            "if", "then", "else", "elif", "fi", "for", "while", "until", "do",
            "done", "case", "esac", "function", "return", "in", "select", "time",
            "export", "local", "readonly", "declare", "source", "alias", "set",
            "unset", "trap", "shift", "exit",
        ],
        types: [
            "echo", "cd", "ls", "cp", "mv", "rm", "mkdir", "cat", "grep", "sed",
            "awk", "curl", "wget", "git", "npm", "npx", "yarn", "pnpm", "brew",
            "docker", "sudo", "chmod", "chown", "find", "xargs", "make", "swift",
            "python", "python3", "pip", "node", "cargo", "go", "kubectl",
        ]
    )

    private static let sql = LanguageGrammar(
        lineComments: ["--"],
        blockComments: [("/*", "*/")],
        stringDelimiters: ["'", "\""],
        keywords: [
            "select", "from", "where", "insert", "into", "values", "update",
            "set", "delete", "create", "alter", "drop", "table", "index", "view",
            "join", "inner", "left", "right", "full", "outer", "on", "group",
            "by", "order", "having", "limit", "offset", "union", "all", "as",
            "and", "or", "not", "in", "exists", "between", "like", "is", "null",
            "distinct", "case", "when", "then", "else", "end", "with", "returning",
            "primary", "foreign", "key", "references", "constraint", "default",
            "cascade", "begin", "commit", "rollback", "transaction",
        ],
        types: [
            "int", "integer", "bigint", "smallint", "serial", "varchar", "text",
            "char", "boolean", "bool", "date", "time", "timestamp", "timestamptz",
            "numeric", "decimal", "real", "double", "json", "jsonb", "uuid",
            "true", "false",
        ],
        caseInsensitiveKeywords: true
    )

    private static let json = LanguageGrammar(
        stringDelimiters: ["\""],
        keywords: ["true", "false", "null"],
        highlightsAssignmentKeys: true
    )

    private static let yaml = LanguageGrammar(
        lineComments: ["#"],
        keywords: ["true", "false", "null", "yes", "no", "on", "off"],
        highlightsAssignmentKeys: true
    )

    private static let css = LanguageGrammar(
        blockComments: [("/*", "*/")],
        keywords: [
            "important", "media", "import", "keyframes", "supports", "charset",
            "font-face", "include", "mixin", "extend", "use", "root",
        ],
        highlightsAssignmentKeys: true
    )

    private static let markup = LanguageGrammar(
        blockComments: [("<!--", "-->")],
        isMarkup: true
    )

    private static let ruby = LanguageGrammar(
        lineComments: ["#"],
        keywords: [
            "def", "end", "class", "module", "if", "elsif", "else", "unless",
            "while", "until", "for", "in", "do", "begin", "rescue", "ensure",
            "return", "yield", "require", "include", "extend", "attr_accessor",
            "attr_reader", "attr_writer", "puts", "then", "case", "when", "self",
            "lambda", "proc", "raise", "next", "break",
        ],
        types: ["true", "false", "nil", "String", "Integer", "Array", "Hash", "Symbol"]
    )

    private static let byName: [String: LanguageGrammar] = {
        var map: [String: LanguageGrammar] = [:]
        func register(_ grammar: LanguageGrammar, _ names: [String]) {
            for name in names { map[name] = grammar }
        }
        register(cLike, [
            "swift", "javascript", "js", "jsx", "typescript", "ts", "tsx",
            "java", "kotlin", "kt", "c", "cpp", "c++", "cc", "h", "hpp",
            "csharp", "cs", "c#", "go", "golang", "rust", "rs", "scala",
            "dart", "php", "groovy", "objc", "objective-c", "m", "zig",
        ])
        register(python, ["python", "py", "python3"])
        register(shell, ["bash", "sh", "shell", "zsh", "console", "terminal", "fish"])
        register(sql, ["sql", "postgres", "postgresql", "mysql", "sqlite"])
        register(json, ["json", "json5", "jsonc"])
        register(yaml, ["yaml", "yml", "toml", "ini", "conf", "properties"])
        register(css, ["css", "scss", "sass", "less"])
        register(markup, ["html", "xml", "svg", "vue", "svelte", "xhtml"])
        register(ruby, ["ruby", "rb", "gemfile"])
        return map
    }()
}
