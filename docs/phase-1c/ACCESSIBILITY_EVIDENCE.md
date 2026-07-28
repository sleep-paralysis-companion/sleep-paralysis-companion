# Accessibility Evidence

## Implemented behavior

- Semantic text styles support all accessibility Dynamic Type categories.
- Critical actions have a minimum 48-point height and multi-line labels.
- Every screen scrolls where content can outgrow the viewport.
- Headings carry header traits and onboarding/state headings receive accessibility focus.
- Decorative symbols are hidden; meaningful symbols are paired with text.
- Feedback is a combined accessible element, carries the updating-content trait, and receives
  explicit accessibility focus when a new error appears.
- Button labels and hints describe actions without relying on position, shape, or color.
- System colors support light/dark; borders become stronger for increased contrast.
- Reduce Motion removes decorative duration; Reduce Transparency uses an opaque semantic surface.
- `ViewThatFits` changes notice utility actions from a row to a column when horizontal space is
  insufficient.
- Leading alignment and system navigation mirror under right-to-left layout.

## Automated coverage

The unit suite covers touch target size, adaptive spacing, Reduce Motion, access-policy state,
and the finite permission states.

The UI suite covers:

- critical onboarding and Home controls at all five accessibility Dynamic Type categories;
- light appearance;
- dark appearance with increased contrast, Reduce Motion, and Reduce Transparency;
- right-to-left locale at accessibility text size in portrait width;
- accessible labels for the approved claims and critical actions;
- top-to-bottom heading/action order;
- clean-install, notice, Home, and restored-route screenshots retained as xcresult attachments.

## Evidence boundary

Hosted simulator accessibility queries validate labels, element order, and operability. They do
not constitute a human VoiceOver usability review. Physical-device VoiceOver focus/announcement
behavior, Switch Control, hardware keyboard, display zoom, and real device contrast remain
unverified external/physical-device evidence. Gate 0 is unaffected.
