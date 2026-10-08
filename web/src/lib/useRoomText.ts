"use client";

import { useEffect, useState } from "react";
import { supabase } from "./supabase";
import { useLang } from "./i18n";

// Filipino room descriptions, fetched once per visit and only when Filipino is on
let cached: Record<string, string> | null = null;
let pending: Promise<Record<string, string>> | null = null;

function load() {
  pending ??= Promise.resolve(
    supabase().from("room_types").select("id, description_fil"),
  ).then(({ data }) => {
    const map: Record<string, string> = Object.fromEntries(
      (data ?? []).filter((r) => r.description_fil).map((r) => [r.id as string, r.description_fil as string]),
    );
    cached = map;
    return map;
  });
  return pending;
}

/** Returns a function that picks the room description in the guest's language. */
export function useRoomDescription() {
  const lang = useLang();
  const [fil, setFil] = useState<Record<string, string> | null>(cached);

  useEffect(() => {
    if (lang !== "fil" || fil) return;
    let active = true;
    load().then((m) => active && setFil(m));
    return () => { active = false; };
  }, [lang, fil]);

  return (id: string, english: string | null) => (lang === "fil" && fil?.[id]) || english;
}
