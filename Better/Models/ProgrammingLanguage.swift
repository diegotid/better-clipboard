//
//  ProgrammingLanguage.swift
//  Better
//
//  Created by Diego Rivera on 22/11/25.
//

import SwiftUI

struct ProgrammingLanguage {
    let name: String
    let color: Color?
}

struct CodePattern {
    let pattern: String
    let language: ProgrammingLanguage
}

let codePatterns: [CodePattern] = [
    // Comments (check first to avoid false matches)
    CodePattern(
        pattern: #"^[\s]*//[\s\S]*$"#,
        language: ProgrammingLanguage(name: "Code", color: Color(hex: "7F8C8D"))
    ),
    CodePattern(
        pattern: #"^[\s]*/\*[\s\S]*\*/$"#,
        language: ProgrammingLanguage(name: "Code", color: Color(hex: "7F8C8D"))
    ),
    // Swift
    CodePattern(
        pattern: #"import\s+(SwiftUI|UIKit|Foundation|Combine)"#,
        language: ProgrammingLanguage(name: "Swift", color: Color(hex: "FF8A5B"))
    ),
    CodePattern(
        pattern: #"@\w+\s+(class|struct|func|var|let|actor|State|Binding|Published|ObservedObject|StateObject)"#,
        language: ProgrammingLanguage(name: "Swift", color: Color(hex: "FF8A5B"))
    ),
    CodePattern(
        pattern: #"\.(padding|frame|background|foregroundColor|overlay)\("#,
        language: ProgrammingLanguage(name: "Swift", color: Color(hex: "FF8A5B"))
    ),
    CodePattern(
        pattern: #"(guard|extension|protocol|where)\s+\w+"#,
        language: ProgrammingLanguage(name: "Swift", color: Color(hex: "FF8A5B"))
    ),
    // TypeScript
    CodePattern(
        pattern: #"(interface|type)\s+\w+\s*[=\{<]"#,
        language: ProgrammingLanguage(name: "TypeScript", color: Color(hex: "4F9EE3"))
    ),
    CodePattern(
        pattern: #":\s*(string|number|boolean|any|void|unknown|never)\s*[;,\)\}=]"#,
        language: ProgrammingLanguage(name: "TypeScript", color: Color(hex: "4F9EE3"))
    ),
    CodePattern(
        pattern: #"(as|implements|namespace|declare|readonly)\s+\w+"#,
        language: ProgrammingLanguage(name: "TypeScript", color: Color(hex: "4F9EE3"))
    ),
    // JavaScript
    CodePattern(
        pattern: #"(console\.(log|error|warn)|document\.|window\.)"#,
        language: ProgrammingLanguage(name: "JavaScript", color: Color(hex: "F7C500"))
    ),
    CodePattern(
        pattern: #"(async|await)\s+(function|\w+\s*=>|\w+\s*\()"#,
        language: ProgrammingLanguage(name: "JavaScript", color: Color(hex: "F7C500"))
    ),
    CodePattern(
        pattern: #"(const|let|var)\s+\w+\s*=\s*(\(.*\)|.*)\s*=>"#,
        language: ProgrammingLanguage(name: "JavaScript", color: Color(hex: "F7C500"))
    ),
    CodePattern(
        pattern: #"(require|module\.exports|export\s+(default|const|function))"#,
        language: ProgrammingLanguage(name: "JavaScript", color: Color(hex: "F7C500"))
    ),
    // C/C++ (check before Python to avoid false matches with range-based for loops)
    CodePattern(
        pattern: #"#include\s*<[\w\.]+>|#define\s+\w+"#,
        language: ProgrammingLanguage(name: "C/C++", color: Color(hex: "5DADE2"))
    ),
    CodePattern(
        pattern: #"(std::|using\s+namespace|template\s*<|nullptr)"#,
        language: ProgrammingLanguage(name: "C++", color: Color(hex: "5DADE2"))
    ),
    CodePattern(
        pattern: #"(printf|scanf|malloc|free)\s*\("#,
        language: ProgrammingLanguage(name: "C", color: Color(hex: "85C1E9"))
    ),
    CodePattern(
        pattern: #"(std::cout|std::cin|std::endl|std::vector|std::string)"#,
        language: ProgrammingLanguage(name: "C++", color: Color(hex: "5DADE2"))
    ),
    // PHP (check before Shell because echo and $ are ambiguous)
    CodePattern(
        pattern: #"<\?php|\$\w+\s*=|function\s+\w+\([^)]*\)\s*\{|foreach\s*\([^)]+\)"#,
        language: ProgrammingLanguage(name: "PHP", color: Color(hex: "9B7FC5"))
    ),
    CodePattern(
        pattern: #"(public|private|protected)\s+function|\$this->|echo\s+[^;]+;"#,
        language: ProgrammingLanguage(name: "PHP", color: Color(hex: "9B7FC5"))
    ),
    // Shell/Bash (check early due to shebang being a strong indicator)
    CodePattern(
        pattern: #"^#!/bin/(bash|sh|zsh)"#,
        language: ProgrammingLanguage(name: "Shell", color: Color(hex: "7ED321"))
    ),
    CodePattern(
        pattern: #"^\s*export\s+\w+=|\$\{[A-Z_][A-Z0-9_]*\}"#,
        language: ProgrammingLanguage(name: "Shell", color: Color(hex: "7ED321"))
    ),
    CodePattern(
        pattern: #"(echo|grep|sed|awk|chmod|source|alias)\s+["'\-]"#,
        language: ProgrammingLanguage(name: "Shell", color: Color(hex: "7ED321"))
    ),
    CodePattern(
        pattern: #"(\$@|\$\*|\$#|\$\?|\$!|\$\$|\$0)"#,
        language: ProgrammingLanguage(name: "Shell", color: Color(hex: "7ED321"))
    ),
    // Python
    CodePattern(
        pattern: #"(def|class)\s+\w+\s*\([^)]*\)\s*:"#,
        language: ProgrammingLanguage(name: "Python", color: Color(hex: "5BA3D0"))
    ),
    CodePattern(
        pattern: #"import\s+\w+(\s+(as|from))?"#,
        language: ProgrammingLanguage(name: "Python", color: Color(hex: "5BA3D0"))
    ),
    CodePattern(
        pattern: #"(if|elif|for|while)\s+[^:]+:\s*$"#,
        language: ProgrammingLanguage(name: "Python", color: Color(hex: "5BA3D0"))
    ),
    CodePattern(
        pattern: #"(__init__|__main__|self\.|@staticmethod|@classmethod|@property)"#,
        language: ProgrammingLanguage(name: "Python", color: Color(hex: "5BA3D0"))
    ),
    // Java
    CodePattern(
        pattern: #"(public|private|protected)\s+(static\s+)?(class|interface|enum)\s+\w+"#,
        language: ProgrammingLanguage(name: "Java", color: Color(hex: "2E94C5"))
    ),
    CodePattern(
        pattern: #"(public|private|protected)\s+(static\s+)?\w+\s+\w+\s*\([^)]*\)\s*\{"#,
        language: ProgrammingLanguage(name: "Java", color: Color(hex: "2E94C5"))
    ),
    CodePattern(
        pattern: #"System\.(out|err)\.(println|print)\s*\("#,
        language: ProgrammingLanguage(name: "Java", color: Color(hex: "2E94C5"))
    ),
    CodePattern(
        pattern: #"(package|import)\s+[\w\.]+;"#,
        language: ProgrammingLanguage(name: "Java", color: Color(hex: "2E94C5"))
    ),
    CodePattern(
        pattern: #"@Override|@Autowired|@Component|@Service"#,
        language: ProgrammingLanguage(name: "Java", color: Color(hex: "2E94C5"))
    ),
    // C#
    CodePattern(
        pattern: #"using\s+(System|Microsoft|Unity)[\w\.]*;"#,
        language: ProgrammingLanguage(name: "C#", color: Color(hex: "68C67A"))
    ),
    CodePattern(
        pattern: #"(namespace|sealed|override|async\s+Task)\s+\w+"#,
        language: ProgrammingLanguage(name: "C#", color: Color(hex: "68C67A"))
    ),
    // Go
    CodePattern(
        pattern: #"(package\s+main|func\s+main\(\))"#,
        language: ProgrammingLanguage(name: "Go", color: Color(hex: "5DD4F4"))
    ),
    CodePattern(
        pattern: #"(defer|go\s+func|chan\s+\w+|<-\s*\w+)"#,
        language: ProgrammingLanguage(name: "Go", color: Color(hex: "5DD4F4"))
    ),
    CodePattern(
        pattern: #":=\s*\w+|func\s+\(\w+\s+\*?\w+\)"#,
        language: ProgrammingLanguage(name: "Go", color: Color(hex: "5DD4F4"))
    ),
    // Rust
    CodePattern(
        pattern: #"(fn\s+\w+|let\s+mut\s+\w+|impl\s+\w+|pub\s+(fn|struct))"#,
        language: ProgrammingLanguage(name: "Rust", color: Color(hex: "F74C00"))
    ),
    CodePattern(
        pattern: #"(use\s+std::|&str|&mut|Box<|Vec<|Option<|Result<)"#,
        language: ProgrammingLanguage(name: "Rust", color: Color(hex: "F74C00"))
    ),
    // Kotlin (check before SQL to avoid Int/VARCHAR confusion)
    CodePattern(
        pattern: #"(fun\s+\w+|val\s+\w+|var\s+\w+:\s*\w+|data\s+class)"#,
        language: ProgrammingLanguage(name: "Kotlin", color: Color(hex: "A97BFF"))
    ),
    CodePattern(
        pattern: #"(companion\s+object|sealed\s+class|when\s*\{)"#,
        language: ProgrammingLanguage(name: "Kotlin", color: Color(hex: "A97BFF"))
    ),
    // SQL (check before Ruby to avoid false matches)
    CodePattern(
        pattern: #"(?i)(SELECT\s+.+\s+FROM|INSERT\s+INTO|UPDATE\s+.+\s+SET|DELETE\s+FROM|CREATE\s+TABLE|DROP\s+TABLE|ALTER\s+TABLE)"#,
        language: ProgrammingLanguage(name: "SQL", color: Color(hex: "FF6B9D"))
    ),
    CodePattern(
        pattern: #"(?i)(PRIMARY\s+KEY|FOREIGN\s+KEY|VARCHAR\(|WHERE\s+.+\s*=)"#,
        language: ProgrammingLanguage(name: "SQL", color: Color(hex: "FF6B9D"))
    ),
    // Ruby
    CodePattern(
        pattern: #"(def\s+\w+|end$|require\s+['"]|class\s+\w+\s*<\s*\w+)"#,
        language: ProgrammingLanguage(name: "Ruby", color: Color(hex: "E74C3C"))
    ),
    CodePattern(
        pattern: #"(@\w+|attr_(reader|writer|accessor)|do\s*\||puts\s+)"#,
        language: ProgrammingLanguage(name: "Ruby", color: Color(hex: "E74C3C"))
    ),
    // HTML/XML
    CodePattern(
        pattern: #"<!DOCTYPE\s+html>|<html[\s>]|<head[\s>]|<body[\s>]"#,
        language: ProgrammingLanguage(name: "HTML", color: Color(hex: "FF6347"))
    ),
    CodePattern(
        pattern: #"<[\w-]+(\s+[\w-]+=["'][^"']*["'])*\s*/?>"#,
        language: ProgrammingLanguage(name: "HTML", color: Color(hex: "FF6347"))
    ),
    // CSS/SCSS
    CodePattern(
        pattern: #"@(import|media|keyframes)|\w+\s*\{[^}]*([\w-]+\s*:\s*[^;]+;)+[^}]*\}"#,
        language: ProgrammingLanguage(name: "CSS", color: Color(hex: "9B59B6"))
    ),
    CodePattern(
        pattern: #"([\w-]+\s*:\s*[^;]+;\s*){2,}"#,
        language: ProgrammingLanguage(name: "CSS", color: Color(hex: "9B59B6"))
    ),
    CodePattern(
        pattern: #"\$[\w-]+\s*:|@(mixin|include|extend)"#,
        language: ProgrammingLanguage(name: "SCSS", color: Color(hex: "E91E63"))
    ),
    // JSON
    CodePattern(
        pattern: #"^\s*\{[\s\n]*"[\w-]+"[\s\n]*:"#,
        language: ProgrammingLanguage(name: "JSON", color: Color(hex: "95A5A6"))
    ),
    // Markdown
    CodePattern(
        pattern: #"^#{1,6}\s+\w+|^\*{1,2}\w+\*{1,2}|\[.+\]\(.+\)|^```"#,
        language: ProgrammingLanguage(name: "Markdown", color: Color(hex: "3498DB"))
    ),
    // YAML
    CodePattern(
        pattern: #"^[\w-]+:\s*([\w-]+|$)|^\s+-\s+[\w-]+"#,
        language: ProgrammingLanguage(name: "YAML", color: Color(hex: "E74C3C"))
    ),
    // Generic fallback patterns
    CodePattern(
        pattern: #"(function|def|class|struct|interface)\s+\w+\s*[\(\{]"#,
        language: ProgrammingLanguage(name: "Code", color: Color(hex: "7F8C8D"))
    ),
    CodePattern(
        pattern: #"(public|private|protected|static)\s+(class|function|def|func)"#,
        language: ProgrammingLanguage(name: "Code", color: Color(hex: "7F8C8D"))
    )
]

