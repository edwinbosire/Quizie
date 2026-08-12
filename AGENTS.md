# Coding Guidelines

## Formatting

- Prefer compact, conventional formatting. Do not wrap code merely because a declaration or call has several arguments.
- Keep function and method declarations on one line when they remain reasonably readable.
- Keep function calls, initializers, collection literals, conditions, and generic constraints on one line when they fit comfortably.
- Wrap code only when a single line would be genuinely difficult to read or when the surrounding file consistently uses a multiline form.
- When multiline formatting is necessary, use one argument or parameter per line and avoid excessive continuation indentation.
- Preserve the established formatting style of nearby code unless these rules make it unnecessarily verbose.

Prefer:

```swift
func textView(_ textView: UITextView, editMenuForTextInRanges ranges: [NSValue], suggestedActions: [UIMenuElement]) -> UIMenu? {
    // ...
}
```

Avoid unnecessary wrapping:

```swift
func textView(
            _ textView: UITextView,
            editMenuForTextInRanges ranges: [NSValue],
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
    // ...
}
```
