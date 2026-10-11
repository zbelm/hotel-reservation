// Photos of the hotel and its spaces. These are free stock photos from Unsplash
// (unsplash.com/license: free to use, no permission needed). Swap them for the
// hotel's own photos when you have them; room photos live in the database
// (room_types.photos) so the app shows them too.

type Photo = { id: string; alt: string; altFil: string; credit: string; src: (width: number) => string };

const unsplash = (id: string, alt: string, altFil: string, credit: string): Photo => ({
  id,
  alt,
  altFil,
  credit,
  src: (width) => `https://images.unsplash.com/photo-${id}?w=${width}&q=70&auto=format&fit=crop`,
});

export const PHOTOS = {
  exterior: unsplash("1717916435055-311684eb773b", "The hotel's white façade with palm trees in front", "Ang puting harapan ng hotel na may mga puno ng niyog", "Alferio Njau"),
  pool: unsplash("1765741836851-8071475d4911", "The rooftop pool and sun loungers from above", "Ang rooftop pool at mga upuan, kuha mula sa itaas", "Matthew Zheng"),
  cafe: unsplash("1699559510594-12624b72312c", "Coffee and fresh pastries at the café", "Kape at bagong lutong tinapay sa café", "Simon Follin"),
} as const;

export const PHOTO_CREDITS = "Photos: Unsplash (Alferio Njau, Matthew Zheng, Simon Follin, Point3D Commercial Imaging, Wes Hicks, Juliana Morales Ramírez)";
