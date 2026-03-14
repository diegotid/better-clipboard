package main

import (
	"bytes"
	"encoding/json"
	"io"
	"os"
	"unicode"

	enry "github.com/go-enry/go-enry/v2"
	"github.com/go-enry/go-enry/v2/data"
)

type result struct {
	Language   string   `json:"language"`
	Top5       []string `json:"top5"`
}

func main() {
	content, err := io.ReadAll(os.Stdin)
	if err != nil {
		os.Exit(0)
	}
	content = bytes.TrimSpace(content)
	if len(content) == 0 {
		os.Exit(0)
	}

	// Heuristic: if it doesn't look like code at all, return nothing.
	// This is language-agnostic and prevents tagging regular sentences.
	if !looksLikeCode(content) {
		os.Exit(0)
	}

	// Text-only strategies first.
	if lang, ok := enry.GetLanguageByShebang(content); ok && lang != "" && lang != "Other" {
		write(lang)
		return
	}
	if lang, ok := enry.GetLanguageByModeline(content); ok && lang != "" && lang != "Other" {
		write(lang)
		return
	}

	// Classifier-ranked languages (clipboard has no filename, so we rely on content only).
	// We return the top 5 guesses so the caller can decide how strict to be.
	candidates := make([]string, 0, len(data.LanguagesLogProbabilities))
	for lang := range data.LanguagesLogProbabilities {
		candidates = append(candidates, lang)
	}

	ranked := enry.GetLanguagesByClassifier("", content, candidates)
	if len(ranked) == 0 {
		os.Exit(0)
	}

	// Filter out empty/Other and take top 5.
	top := make([]string, 0, 5)
	for _, l := range ranked {
		if l == "" || l == "Other" {
			continue
		}
		top = append(top, l)
		if len(top) == 5 {
			break
		}
	}
	if len(top) == 0 {
		os.Exit(0)
	}

	// Primary language is the top guess; also include the top 5 list.
	_ = json.NewEncoder(os.Stdout).Encode(result{Language: top[0], Top5: top})
	return
}

func write(lang string) {
	_ = json.NewEncoder(os.Stdout).Encode(result{Language: lang, Top5: []string{lang}})
}

func looksLikeCode(b []byte) bool {
	// Require either multiple lines or a decent amount of punctuation typical for code.
	lines := 1
	for _, c := range b {
		if c == '\n' {
			lines++
		}
	}
	if lines < 2 && len(b) < 80 {
		return false
	}

	var letters, punct int
	var hasCodePunct bool
	for _, r := range string(b) {
		if unicode.IsLetter(r) {
			letters++
			continue
		}
		if unicode.IsDigit(r) || unicode.IsSpace(r) {
			continue
		}
		punct++
		switch r {
		case '{', '}', '(', ')', '[', ']', ';', '=', '<', '>', '#', '\\':
			hasCodePunct = true
		}
	}

	// If it contains no typical code punctuation, it's probably prose.
	if !hasCodePunct {
		return false
	}

	// Punctuation ratio guard: prose tends to have very low punctuation density.
	// Allow short snippets if they still have clear code punctuation.
	if letters == 0 {
		return true
	}
	return float64(punct)/float64(letters) >= 0.05
}