//
//  ProgrammingLanguage.swift
//  Better
//
//  Created by Diego Rivera on 22/11/25.
//

import SwiftUI

struct ProgrammingLanguage: Equatable, Codable, Hashable {
    let name: String
    let color: Color?
    
    private static let colorMap: [String: String] = [
        "Swift": "FF8A5B",
        "C": "A8B9CC",
        "C++": "659AD2",
        "C/C++": "659AD2",
        "TypeScript": "3178C6",
        "JavaScript": "F7C500",
        "PHP": "9B7FC5",
        "Shell": "7ED321",
        "Ruby": "E74C3C",
        "C#": "68C67A",
        "Java": "EA2D2E",
        "Python": "FFD43B",
        "Go": "00ADD8",
        "Rust": "F74C00",
        "Kotlin": "A97BFF",
        "SQL": "FF6B9D",
        "HTML": "FF6347",
        "CSS": "9B59B6",
        "SCSS": "E91E63",
        "JSON": "95A5A6",
        "Markdown": "083FA1",
        "YAML": "E74C3C",
        "Code": "7F8C8D"
    ]
    
    private enum CodingKeys: String, CodingKey {
        case name
        case colorHex
    }
    
    init(name: String) {
        self.name = name
        self.color = Self.colorMap[name].map { Color(hex: $0) }
    }
    
    private init(name: String, color: Color?) {
        self.name = name
        self.color = color
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        if let hexString = try container.decodeIfPresent(String.self, forKey: .colorHex) {
            color = Color(hex: hexString)
        } else {
            color = Self.colorMap[name].map { Color(hex: $0) }
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        if let color = color, let hexString = color.toHex() {
            try container.encode(hexString, forKey: .colorHex)
        }
    }
}

struct CodePattern {
    let pattern: String
    let language: ProgrammingLanguage
}

struct CommentPattern {
    let prefix: String
    let language: ProgrammingLanguage
}

let commentPatterns: [CommentPattern] = [
    CommentPattern(prefix: "<!--", language: ProgrammingLanguage(name: "HTML")),
    CommentPattern(prefix: "'''", language: ProgrammingLanguage(name: "Python")),
    CommentPattern(prefix: "\"\"\"", language: ProgrammingLanguage(name: "Python")),
    CommentPattern(prefix: "--", language: ProgrammingLanguage(name: "SQL")),
    CommentPattern(prefix: "//", language: ProgrammingLanguage(name: "C")),
    CommentPattern(prefix: "/*", language: ProgrammingLanguage(name: "C")),
    CommentPattern(prefix: "#", language: ProgrammingLanguage(name: "JavaScript"))
]

let codePatterns: [CodePattern] = [
    // Swift
    CodePattern(
        pattern: #"func\s+\w+<[^>]+>"#,
        language: ProgrammingLanguage(name: "Swift")
    ),
    CodePattern(
        pattern: #"(let|var)\s+\w+:\s*\[[^\]]+\]"#,
        language: ProgrammingLanguage(name: "Swift")
    ),
    CodePattern(
        pattern: #"import\s+(SwiftUI|UIKit|Foundation|Combine)"#,
        language: ProgrammingLanguage(name: "Swift")
    ),
    CodePattern(
        pattern: #"@\w+\s+(class|struct|func|var|let|actor|State|Binding|Published|ObservedObject|StateObject)"#,
        language: ProgrammingLanguage(name: "Swift")
    ),
    CodePattern(
        pattern: #"\.(padding|frame|background|foregroundColor|overlay)\("#,
        language: ProgrammingLanguage(name: "Swift")
    ),
    CodePattern(
        pattern: #"(guard|extension|protocol|where)\s+\w+"#,
        language: ProgrammingLanguage(name: "Swift")
    ),
    // C/C++ (check before TypeScript to avoid template<> matching type<>)
    CodePattern(
        pattern: #"#include\s*<[\w\.]+>"#,
        language: ProgrammingLanguage(name: "C/C++")
    ),
    CodePattern(
        pattern: #"template\s*<[^>]+>"#,
        language: ProgrammingLanguage(name: "C++")
    ),
    CodePattern(
        pattern: #"(std::|using\s+namespace|nullptr)"#,
        language: ProgrammingLanguage(name: "C++")
    ),
    CodePattern(
        pattern: #"#define\s+\w+"#,
        language: ProgrammingLanguage(name: "C")
    ),
    CodePattern(
        pattern: #"(printf|scanf|malloc|free)\s*\("#,
        language: ProgrammingLanguage(name: "C")
    ),
    CodePattern(
        pattern: #"(std::cout|std::cin|std::endl|std::vector|std::string|std::unordered_map)"#,
        language: ProgrammingLanguage(name: "C++")
    ),
    // TypeScript
    CodePattern(
        pattern: #"(interface|type)\s+\w+\s*[=\{<]"#,
        language: ProgrammingLanguage(name: "TypeScript")
    ),
    CodePattern(
        pattern: #":\s*(string|number|boolean|any|void|unknown|never)\s*[;,\)\}=]"#,
        language: ProgrammingLanguage(name: "TypeScript")
    ),
    CodePattern(
        pattern: #"(as|implements|namespace|declare|readonly)\s+\w+"#,
        language: ProgrammingLanguage(name: "TypeScript")
    ),
    // JavaScript
    CodePattern(
        pattern: #"(console\.(log|error|warn)|document\.|window\.)"#,
        language: ProgrammingLanguage(name: "JavaScript")
    ),
    CodePattern(
        pattern: #"navigator\.credentials\.get\s*\("#,
        language: ProgrammingLanguage(name: "JavaScript")
    ),
    CodePattern(
        pattern: #"(async|await)\s+(function|\w+\s*=>|\w+\s*\()"#,
        language: ProgrammingLanguage(name: "JavaScript")
    ),
    CodePattern(
        pattern: #"(const|let|var)\s+\w+\s*=\s*(\(.*\)|.*)\s*=>"#,
        language: ProgrammingLanguage(name: "JavaScript")
    ),
    CodePattern(
        pattern: #"(require|module\.exports|export\s+(default|const|function))"#,
        language: ProgrammingLanguage(name: "JavaScript")
    ),
    // PHP (check early - has distinctive <?php syntax)
    CodePattern(
        pattern: #"<\?php"#,
        language: ProgrammingLanguage(name: "PHP")
    ),
    CodePattern(
        pattern: #"\$\w+\s*=|function\s+\w+\([^)]*\)\s*\{|foreach\s*\([^)]+\)"#,
        language: ProgrammingLanguage(name: "PHP")
    ),
    CodePattern(
        pattern: #"(public|private|protected)\s+function|\$this->|echo\s+[^;]+;"#,
        language: ProgrammingLanguage(name: "PHP")
    ),
    // Shell/Bash (check early due to shebang being a strong indicator)
    CodePattern(
        pattern: #"^#!/bin/(bash|sh|zsh)"#,
        language: ProgrammingLanguage(name: "Shell")
    ),
    CodePattern(
        pattern: #"^\s*export\s+\w+=|\$\{[A-Z_][A-Z0-9_]*\}"#,
        language: ProgrammingLanguage(name: "Shell")
    ),
    CodePattern(
        pattern: #"(echo|grep|sed|awk|chmod|source|alias)\s+["'\-]"#,
        language: ProgrammingLanguage(name: "Shell")
    ),
    CodePattern(
        pattern: #"(\$@|\$\*|\$#|\$\?|\$!|\$\$|\$0)"#,
        language: ProgrammingLanguage(name: "Shell")
    ),
    // Ruby (check early - has distinctive def/end syntax)
    CodePattern(
        pattern: #"\bdef\s+\w+(\([^)]*\))?"#,
        language: ProgrammingLanguage(name: "Ruby")
    ),
    CodePattern(
        pattern: #"\bend\b"#,
        language: ProgrammingLanguage(name: "Ruby")
    ),
    CodePattern(
        pattern: #"\.each\s+(do|\{)|\bputs\b"#,
        language: ProgrammingLanguage(name: "Ruby")
    ),
    CodePattern(
        pattern: #":\w+\s*(=>|:)"#,
        language: ProgrammingLanguage(name: "Ruby")
    ),
    CodePattern(
        pattern: #"(require\s+['"]|class\s+\w+\s*<\s*\w+)"#,
        language: ProgrammingLanguage(name: "Ruby")
    ),
    CodePattern(
        pattern: #"(@\w+|attr_(reader|writer|accessor))"#,
        language: ProgrammingLanguage(name: "Ruby")
    ),
    // Kotlin (check before C# to avoid generic type confusion)
    CodePattern(
        pattern: #"fun\s+(<[^>]+>\s+)?\w+"#,
        language: ProgrammingLanguage(name: "Kotlin")
    ),
    CodePattern(
        pattern: #"\b(val|var)\s+\w+\s*(:\s*\w+)?\s*=\s*(mapOf|mutableMapOf|listOf|mutableListOf)"#,
        language: ProgrammingLanguage(name: "Kotlin")
    ),
    CodePattern(
        pattern: #"\bvararg\s+\w+:\s*\w+|data\s+class\s+\w+"#,
        language: ProgrammingLanguage(name: "Kotlin")
    ),
    CodePattern(
        pattern: #"(companion\s+object|sealed\s+class|when\s*\{)"#,
        language: ProgrammingLanguage(name: "Kotlin")
    ),
    CodePattern(
        pattern: #"\w+\s+to\s+\w+|\bprintln\s*\("#,
        language: ProgrammingLanguage(name: "Kotlin")
    ),
    // C# (check after Ruby/PHP/Kotlin due to similar keywords)
    CodePattern(
        pattern: #"(Dictionary|List|IEnumerable|ICollection)<[^>]+>"#,
        language: ProgrammingLanguage(name: "C#")
    ),
    CodePattern(
        pattern: #"(Console|StringBuilder|Linq)\.(WriteLine|ReadLine|AppendLine|Select|Where)"#,
        language: ProgrammingLanguage(name: "C#")
    ),
    CodePattern(
        pattern: #"\bvar\s+\w+\s*=\s*new\s+\w+(<[^>]+>)?\s*\("#,
        language: ProgrammingLanguage(name: "C#")
    ),
    CodePattern(
        pattern: #"using\s+(System|Microsoft|Unity)[\w\.]*;"#,
        language: ProgrammingLanguage(name: "C#")
    ),
    CodePattern(
        pattern: #"(namespace|sealed|override|async\s+Task)\s+\w+"#,
        language: ProgrammingLanguage(name: "C#")
    ),
    CodePattern(
        pattern: #"(public|private|protected|internal)\s+static\s+class\s+\w+"#,
        language: ProgrammingLanguage(name: "C#")
    ),
    // Java (check before Python to avoid import conflicts)
    CodePattern(
        pattern: #"import\s+[\w\.]+;"#,
        language: ProgrammingLanguage(name: "Java")
    ),
    CodePattern(
        pattern: #"(public|private|protected)\s+(static\s+)?(class|interface|enum)\s+\w+"#,
        language: ProgrammingLanguage(name: "Java")
    ),
    CodePattern(
        pattern: #"(public|private|protected)\s+(static\s+)?\w+\s+\w+\s*\([^)]*\)\s*\{"#,
        language: ProgrammingLanguage(name: "Java")
    ),
    CodePattern(
        pattern: #"System\.(out|err)\.(println|print)\s*\("#,
        language: ProgrammingLanguage(name: "Java")
    ),
    CodePattern(
        pattern: #"(package|import)\s+[\w\.]+;"#,
        language: ProgrammingLanguage(name: "Java")
    ),
    CodePattern(
        pattern: #"@Override|@Autowired|@Component|@Service|@SuppressWarnings"#,
        language: ProgrammingLanguage(name: "Java")
    ),
    // Python
    CodePattern(
        pattern: #"^[\s]*(def|class)\s+\w+"#,
        language: ProgrammingLanguage(name: "Python")
    ),
    CodePattern(
        pattern: #"(def|class)\s+\w+\s*\([^)]*\)\s*(->\s*\w+)?\s*:"#,
        language: ProgrammingLanguage(name: "Python")
    ),
    CodePattern(
        pattern: #"(from\s+\w+\s+)?import\s+\w+(\s+as\s+\w+)?(?![\w\s]*;)"#,
        language: ProgrammingLanguage(name: "Python")
    ),
    CodePattern(
        pattern: #"(if|elif|for|while)\s+[^:]+:\s*$"#,
        language: ProgrammingLanguage(name: "Python")
    ),
    CodePattern(
        pattern: #"(__init__|__main__|self\.|@staticmethod|@classmethod|@property)"#,
        language: ProgrammingLanguage(name: "Python")
    ),
    // Go (check before Java/C# to avoid false matches with "package")
    CodePattern(
        pattern: #"package\s+main\b"#,
        language: ProgrammingLanguage(name: "Go")
    ),
    CodePattern(
        pattern: #"func\s+main\s*\(\s*\)"#,
        language: ProgrammingLanguage(name: "Go")
    ),
    CodePattern(
        pattern: #"(defer|go\s+func|chan\s+\w+|<-\s*\w+)"#,
        language: ProgrammingLanguage(name: "Go")
    ),
    CodePattern(
        pattern: #":=\s*\w+|func\s+\(\w+\s+\*?\w+\)"#,
        language: ProgrammingLanguage(name: "Go")
    ),
    CodePattern(
        pattern: #"\brange\s+\w+|make\s*\(|import\s+"[^"]+""#,
        language: ProgrammingLanguage(name: "Go")
    ),
    // Rust
    CodePattern(
        pattern: #"(?i)(SELECT\s+.+\s+FROM|INSERT\s+INTO|UPDATE\s+.+\s+SET|DELETE\s+FROM|CREATE\s+TABLE|DROP\s+TABLE|ALTER\s+TABLE)"#,
        language: ProgrammingLanguage(name: "SQL")
    ),
    CodePattern(
        pattern: #"(?i)(PRIMARY\s+KEY|FOREIGN\s+KEY|VARCHAR\(|WHERE\s+.+\s*=)"#,
        language: ProgrammingLanguage(name: "SQL")
    ),
    // HTML/XML
    CodePattern(
        pattern: #"<!DOCTYPE\s+html>|<html[\s>]|<head[\s>]|<body[\s>]"#,
        language: ProgrammingLanguage(name: "HTML")
    ),
    CodePattern(
        pattern: #"<[\w-]+(\s+[\w-]+=["'][^"']*["'])*\s*/?>"#,
        language: ProgrammingLanguage(name: "HTML")
    ),
    // CSS/SCSS
    CodePattern(
        pattern: #"@(import|media|keyframes)|\w+\s*\{[^}]*([\w-]+\s*:\s*[^;]+;)+[^}]*\}"#,
        language: ProgrammingLanguage(name: "CSS")
    ),
    CodePattern(
        pattern: #"([\w-]+\s*:\s*[^;]+;\s*){2,}"#,
        language: ProgrammingLanguage(name: "CSS")
    ),
    CodePattern(
        pattern: #"\$[\w-]+\s*:|@(mixin|include|extend)"#,
        language: ProgrammingLanguage(name: "SCSS")
    ),
    // JSON
    CodePattern(
        pattern: #"^\s*\{[\s\n]*"[\w-]+"[\s\n]*:"#,
        language: ProgrammingLanguage(name: "JSON")
    ),
    // Markdown
    CodePattern(
        pattern: #"^#{1,6}\s+\w+|^\*{1,2}\w+\*{1,2}|\[.+\]\(.+\)|^```"#,
        language: ProgrammingLanguage(name: "Markdown")
    ),
    // YAML
    CodePattern(
        pattern: #"^[\w-]+:\s*([\w-]+|$)|^\s+-\s+[\w-]+"#,
        language: ProgrammingLanguage(name: "YAML")
    ),
    // Generic fallback patterns
    CodePattern(
        pattern: #"(function|def|class|struct|interface)\s+\w+\s*[\(\{]"#,
        language: ProgrammingLanguage(name: "Code")
    ),
    CodePattern(
        pattern: #"(public|private|protected|static)\s+(class|function|def|func)"#,
        language: ProgrammingLanguage(name: "Code")
    )
]

extension Color {
    func toHex() -> String? {
        guard let comps = components else {
            return nil
        }
        let r = Int(comps.red * 255)
        let g = Int(comps.green * 255)
        let b = Int(comps.blue * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
