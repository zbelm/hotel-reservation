import { Suspense } from "react";
import { Spinner } from "@/components/ui";
import { RoomDetails } from "./RoomDetails";

export const metadata = { title: "Room rates" };

export default function RoomPage() {
  return (
    <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
      <Suspense fallback={<Spinner label="Loading room" />}>
        <RoomDetails />
      </Suspense>
    </div>
  );
}
