# Design-System Inventory

## Semantic foundations

| Layer | Implementation | Adaptive behavior |
|---|---|---|
| Color | background, surface, elevated surface, primary/secondary text, accent, success, caution, error, separator | system semantic colors support light/dark; separator weight increases with contrast |
| Typography | hero, screen title, section title, card title, body, supporting, control, label | SwiftUI semantic fonts scale through every Dynamic Type category |
| Spacing | tight, compact, standard, spacious, section, screen, minimum control | accessibility sizes increase vertical spacing and reduce screen padding |
| Shape | control and card radii | no meaning depends on shape |
| Motion | standard duration | decorative duration becomes zero for Reduce Motion |

No visual meaning depends only on color. System symbols are paired with text or hidden from the
accessibility tree when decorative.

## Reusable components

| Component | Purpose |
|---|---|
| `AppPrimaryButtonStyle` | full-width critical action with scalable label and 48-point minimum height |
| `AppSecondaryButtonStyle` | bordered secondary/local navigation action |
| `AppCard` | semantic adaptive surface with increased-contrast outline and reduced-transparency fallback |
| `AppFeatureCard` | title, honest status, and one explicit action |
| `AppFeedbackBanner` | combined important message with update trait and explicit focus transfer |
| `AppStateView` | loading/error/unavailable/empty state with focused heading and optional recovery |

`ScrollView`, multi-line labels, `ViewThatFits`, adaptive padding, and no fixed text frames keep
critical controls operable at accessibility sizes and narrow widths. Leading/trailing layout
semantics provide right-to-left mirroring.
