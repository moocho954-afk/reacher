// Standalone replacement for the Space SDK's SafeAreaTopScrim: a spacer that
// reserves the device's top safe-area inset so the sticky header never sits
// under a notch. No SDK dependency.
export function SafeAreaTopScrim({ backgroundColor }: { backgroundColor?: string }) {
  return (
    <div
      aria-hidden="true"
      style={{
        background: backgroundColor ?? "var(--bg)",
        height: "env(safe-area-inset-top, 0px)",
      }}
    />
  );
}
