import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { SearchResults } from "./SearchResults";

export const metadata = { title: "Available rooms" };

export default function SearchPage() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
      <Suspense fallback={<Spinner label="Finding rooms" />}>
        <SearchResults />
      </Suspense>
    </div>
  );
}
