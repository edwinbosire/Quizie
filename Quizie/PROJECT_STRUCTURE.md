# Project Structure

Quizie is organized by user-facing feature. Every feature has the same four
layers so new code has a predictable home:

- `Views`: SwiftUI presentation and feature navigation.
- `ViewModels`: observable presentation state and UI orchestration.
- `Models`: feature-owned domain and display values.
- `Repository`: protocols and concrete data or system boundaries.

`Resources` contains bundled data, fonts, shared visual styling, animation,
and implementation notes. `SharedDependencies` contains the app composition
root, cross-feature errors, and persistence assembly. Feature dependencies are
created there and passed explicitly from each feature root to the view or
object that consumes them. App-owned services and presentation context are not
stored in SwiftUI's environment.

Layers without an implementation contain a small, feature-named Swift marker
file. This keeps the common layout visible without introducing placeholder
types or duplicate bundled resources.
