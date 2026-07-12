// -----------------------------------------------------------------------------
// Shared constants for the admin dashboard.
// The subject list + English path slugs MUST stay in sync with the Flutter app
// and the storage layout defined in supabase/migration.sql.
// -----------------------------------------------------------------------------

export const STREAM = "علوم تجريبية"; // always this value in V1

// Arabic display label -> English storage-path slug
export const SUBJECTS = [
  { label: "رياضيات",        slug: "maths" },
  { label: "فيزياء",         slug: "physique" },
  { label: "علوم طبيعية",    slug: "svt" },
  { label: "عربية",          slug: "arabe" },
  { label: "فرنسية",         slug: "francais" },
  { label: "إنجليزية",       slug: "anglais" },
  { label: "فلسفة",          slug: "philo" },
  { label: "تاريخ وجغرافيا", slug: "histoire-geo" },
  { label: "تربية إسلامية",  slug: "islamique" },
  { label: "أخرى",           slug: "autre" },
];

export const SUBJECT_SLUG = Object.fromEntries(
  SUBJECTS.map((s) => [s.label, s.slug])
);

export const STORAGE_BUCKET = "bac-files";

// Logical file kind -> object filename in storage
export const FILE_KINDS = [
  { key: "sujet",      label: "الموضوع",        filename: "sujet.pdf",      urlColumn: "sujet_url" },
  { key: "solution",   label: "الحل",           filename: "solution.pdf",   urlColumn: "solution_url" },
  { key: "correction", label: "الحل النموذجي",  filename: "correction.pdf", urlColumn: "correction_url" },
];

// {year}/sciences/{slug}
export function folderPath(year, slug) {
  return `${year}/sciences/${slug}`;
}

export function formatBytes(bytes) {
  if (!bytes || bytes <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return `${(bytes / Math.pow(1024, i)).toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}
