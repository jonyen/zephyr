"use client";

import { useEffect, useRef, useCallback } from "react";

interface UseInfiniteScrollOptions {
  /** Called when the sentinel at the top of the list becomes visible */
  onLoadPrevious: () => void;
  /** Called when the sentinel at the bottom of the list becomes visible */
  onLoadNext: () => void;
  /** The scrollable container element */
  scrollContainer: HTMLElement | null;
  /** Whether loading previous chapters is possible */
  canLoadPrevious: boolean;
  /** Whether loading next chapters is possible */
  canLoadNext: boolean;
}

/**
 * Hook that sets up IntersectionObservers on sentinel elements to trigger
 * infinite scroll loading in both directions.
 *
 * Returns refs to attach to the top and bottom sentinel elements.
 */
export function useInfiniteScroll({
  onLoadPrevious,
  onLoadNext,
  scrollContainer,
  canLoadPrevious,
  canLoadNext,
}: UseInfiniteScrollOptions) {
  const topSentinelRef = useRef<HTMLDivElement>(null);
  const bottomSentinelRef = useRef<HTMLDivElement>(null);

  const onLoadPreviousRef = useRef(onLoadPrevious);
  onLoadPreviousRef.current = onLoadPrevious;
  const onLoadNextRef = useRef(onLoadNext);
  onLoadNextRef.current = onLoadNext;

  useEffect(() => {
    if (!scrollContainer) return;

    const topEl = topSentinelRef.current;
    const bottomEl = bottomSentinelRef.current;
    if (!topEl || !bottomEl) return;

    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          if (entry.target === topEl && canLoadPrevious) {
            onLoadPreviousRef.current();
          } else if (entry.target === bottomEl && canLoadNext) {
            onLoadNextRef.current();
          }
        }
      },
      {
        root: scrollContainer,
        rootMargin: "200px 0px",
        threshold: 0,
      },
    );

    observer.observe(topEl);
    observer.observe(bottomEl);

    return () => observer.disconnect();
  }, [scrollContainer, canLoadPrevious, canLoadNext]);

  return { topSentinelRef, bottomSentinelRef };
}
