"use client";

import { useEffect, useSyncExternalStore } from "react";
import { messages, type Lang, type Messages } from "./messages";
import { content, type HotelContent } from "./hotel";

// The guest's language lives in this browser only (no account needed).
const KEY = "lang";
const EVENT = "langchange";

function read(): Lang {
  try {
    return localStorage.getItem(KEY) === "fil" ? "fil" : "en";
  } catch {
    return "en";
  }
}

function subscribe(onChange: () => void) {
  window.addEventListener("storage", onChange);
  window.addEventListener(EVENT, onChange);
  return () => {
    window.removeEventListener("storage", onChange);
    window.removeEventListener(EVENT, onChange);
  };
}

export function setLang(lang: Lang) {
  try {
    localStorage.setItem(KEY, lang);
  } catch {
    // Private mode: the choice lasts until the page is closed
  }
  document.documentElement.lang = lang === "fil" ? "fil" : "en";
  window.dispatchEvent(new Event(EVENT));
}

export function useLang(): Lang {
  const lang = useSyncExternalStore<Lang>(subscribe, read, () => "en");
  // Keep <html lang> right after a reload too, so screen readers use the right voice
  useEffect(() => {
    document.documentElement.lang = lang;
  }, [lang]);
  return lang;
}

export function useT(): { lang: Lang; t: Messages; hotel: HotelContent } {
  const lang = useLang();
  return { lang, t: messages[lang], hotel: content[lang] };
}

export type { Lang };
