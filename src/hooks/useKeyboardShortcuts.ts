"use client";

import { useEffect } from "react";

export interface KeyboardShortcutCallbacks {
  onSearch: () => void;
  onTOC: () => void;
  onToggleHistory: () => void;
  onPrevChapter: () => void;
  onNextChapter: () => void;
  onToggleBookmark: () => void;
  onPrevBookmark: () => void;
  onNextBookmark: () => void;
  onPrevHighlight: () => void;
  onNextHighlight: () => void;
  onShowShortcuts: () => void;
  onDismiss: () => void;
}

export function useKeyboardShortcuts(callbacks: KeyboardShortcutCallbacks) {
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      const mod = e.metaKey || e.ctrlKey;

      if (mod && e.key === "f") {
        e.preventDefault();
        callbacks.onSearch();
        return;
      }
      if (mod && e.key === "t") {
        e.preventDefault();
        callbacks.onTOC();
        return;
      }
      if (mod && e.key === "y") {
        e.preventDefault();
        callbacks.onToggleHistory();
        return;
      }
      if (mod && e.key === "[" && !e.shiftKey) {
        e.preventDefault();
        callbacks.onPrevChapter();
        return;
      }
      if (mod && e.key === "]" && !e.shiftKey) {
        e.preventDefault();
        callbacks.onNextChapter();
        return;
      }
      if (mod && e.key === "b") {
        e.preventDefault();
        callbacks.onToggleBookmark();
        return;
      }
      if (mod && e.shiftKey && e.key === "ArrowLeft") {
        e.preventDefault();
        callbacks.onPrevBookmark();
        return;
      }
      if (mod && e.shiftKey && e.key === "ArrowRight") {
        e.preventDefault();
        callbacks.onNextBookmark();
        return;
      }
      if (mod && (e.key === "{" || (e.shiftKey && e.key === "["))) {
        e.preventDefault();
        callbacks.onPrevHighlight();
        return;
      }
      if (mod && (e.key === "}" || (e.shiftKey && e.key === "]"))) {
        e.preventDefault();
        callbacks.onNextHighlight();
        return;
      }
      if (e.key === "?" && !mod && !e.altKey) {
        e.preventDefault();
        callbacks.onShowShortcuts();
        return;
      }
      if (e.key === "Escape") {
        callbacks.onDismiss();
        return;
      }
    };

    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [callbacks]);
}
