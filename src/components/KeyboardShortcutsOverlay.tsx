"use client";

interface KeyboardShortcutsOverlayProps {
  open: boolean;
  onClose: () => void;
}

function isMac(): boolean {
  if (typeof navigator === "undefined") return false;
  return /Mac|iPhone|iPad|iPod/.test(
    navigator.userAgent ?? navigator.platform ?? "",
  );
}

const shortcuts: { action: string; mac: string; other: string }[] = [
  { action: "Search", mac: "\u2318F", other: "Ctrl+F" },
  { action: "Table of Contents", mac: "\u2318T", other: "Ctrl+T" },
  { action: "Toggle History", mac: "\u2318Y", other: "Ctrl+Y" },
  { action: "Previous Chapter", mac: "\u2318[", other: "Ctrl+[" },
  { action: "Next Chapter", mac: "\u2318]", other: "Ctrl+]" },
  { action: "Toggle Bookmark", mac: "\u2318B", other: "Ctrl+B" },
  { action: "Previous Bookmark", mac: "\u2318\u21E7\u2190", other: "Ctrl+Shift+\u2190" },
  { action: "Next Bookmark", mac: "\u2318\u21E7\u2192", other: "Ctrl+Shift+\u2192" },
  { action: "Previous Highlight", mac: "\u2318{", other: "Ctrl+{" },
  { action: "Next Highlight", mac: "\u2318}", other: "Ctrl+}" },
  { action: "Keyboard Shortcuts", mac: "?", other: "?" },
  { action: "Dismiss", mac: "Esc", other: "Esc" },
];

export default function KeyboardShortcutsOverlay({
  open,
  onClose,
}: KeyboardShortcutsOverlayProps) {
  if (!open) return null;

  const mac = isMac();

  return (
    <div
      className="fixed inset-0 bg-black/30 backdrop-blur-sm z-50 flex items-center justify-center"
      onClick={onClose}
    >
      <div
        className="max-w-md w-full bg-white rounded-xl shadow-2xl p-6"
        onClick={(e) => e.stopPropagation()}
      >
        <h2 className="text-lg font-semibold text-stone-900 mb-4">
          Keyboard Shortcuts
        </h2>

        <div className="space-y-2">
          {shortcuts.map((s) => (
            <div
              key={s.action}
              className="flex items-center justify-between text-sm"
            >
              <span className="text-stone-700">{s.action}</span>
              <kbd className="font-mono text-xs bg-stone-100 px-2 py-0.5 rounded text-stone-600">
                {mac ? s.mac : s.other}
              </kbd>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
