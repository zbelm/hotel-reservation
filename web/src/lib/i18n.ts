"use client";

import { useSyncExternalStore } from "react";
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
  return useSyncExternalStore(subscribe, read, () => "en");
}

export function useT(): { lang: Lang; t: Messages; hotel: HotelContent } {
  const lang = useLang();
  return { lang, t: messages[lang], hotel: content[lang] };
}

export type { Lang };
