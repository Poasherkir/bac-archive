import { supabase } from "./supabaseClient.js";
import {
  STREAM,
  SUBJECT_SLUG,
  STORAGE_BUCKET,
  FILE_KINDS,
  folderPath,
  formatBytes,
} from "./constants.js";

// ----------------------------------------------------------------------------
// Content management view — searchable table, delete (row + storage files),
// missing-file flags, and running total archive size.
// Mounts into #manage-mount. Idempotent.
// ----------------------------------------------------------------------------

let mounted = false;
let allRows = [];
let searchTerm = "";

const el = {}; // filled on mount

function template() {
  return `
    <div class="card manage-card">
      <div class="manage-head">
        <h2 class="section-title">إدارة المحتوى</h2>
        <div class="archive-total">
          الحجم الإجمالي للأرشيف: <strong id="archive-total">—</strong>
        </div>
      </div>

      <input id="manage-search" class="search" type="search"
             placeholder="ابحث بالسنة أو المادة…" />

      <div class="table-wrap">
        <table class="exams-table">
          <thead>
            <tr>
              <th>السنة</th>
              <th>المادة</th>
              <th>الموضوع</th>
              <th>الحل</th>
              <th>الحل النموذجي</th>
              <th>الحجم</th>
              <th></th>
            </tr>
          </thead>
          <tbody id="exams-tbody"></tbody>
        </table>
      </div>

      <p id="manage-empty" class="muted manage-empty hidden">لا توجد إدخالات بعد.</p>
    </div>
  `;
}

function fileBadge(present) {
  return present
    ? `<span class="badge badge-ok">✓</span>`
    : `<span class="badge badge-missing">—</span>`;
}

function rowHtml(row) {
  const hasSujet = !!row.sujet_url;
  const hasSolution = !!row.solution_url;
  const hasCorr = !!row.correction_url;
  const incomplete = !(hasSujet && hasSolution && hasCorr);

  return `
    <tr class="${incomplete ? "row-incomplete" : ""}">
      <td>${row.year}</td>
      <td>
        ${escapeHtml(row.subject)}
        ${incomplete ? `<span class="flag">ملفات ناقصة</span>` : ""}
      </td>
      <td class="cell-center">${fileBadge(hasSujet)}</td>
      <td class="cell-center">${fileBadge(hasSolution)}</td>
      <td class="cell-center">${fileBadge(hasCorr)}</td>
      <td>${formatBytes(row.file_size_bytes)}</td>
      <td class="cell-center">
        <button class="btn btn-danger btn-sm" data-id="${row.id}"
                data-year="${escapeAttr(row.year)}"
                data-subject="${escapeAttr(row.subject)}">حذف</button>
      </td>
    </tr>
  `;
}

function render() {
  const term = searchTerm.trim();
  const rows = term
    ? allRows.filter(
        (r) =>
          String(r.year).includes(term) ||
          (r.subject || "").includes(term)
      )
    : allRows;

  el.tbody.innerHTML = rows.map(rowHtml).join("");
  el.empty.classList.toggle("hidden", rows.length > 0);

  const total = allRows.reduce((sum, r) => sum + (r.file_size_bytes || 0), 0);
  el.total.textContent = formatBytes(total);

  // wire delete buttons
  el.tbody.querySelectorAll("button[data-id]").forEach((btn) => {
    btn.addEventListener("click", () => onDelete(btn));
  });
}

async function load() {
  const { data, error } = await supabase
    .from("exams")
    .select("*")
    .eq("stream", STREAM)
    .order("year", { ascending: false })
    .order("subject", { ascending: true });

  if (error) {
    console.error("Failed to load exams:", error);
    el.tbody.innerHTML = `<tr><td colspan="7" class="cell-center muted">تعذّر تحميل البيانات: ${escapeHtml(
      error.message
    )}</td></tr>`;
    return;
  }
  allRows = data || [];
  render();
}

async function onDelete(btn) {
  const id = btn.dataset.id;
  const year = btn.dataset.year;
  const subject = btn.dataset.subject;

  if (!confirm(`حذف إدخال ${subject} ${year} وكل ملفاته نهائيًا؟`)) return;

  btn.disabled = true;
  btn.textContent = "جارٍ الحذف…";

  try {
    const slug = SUBJECT_SLUG[subject] || "autre";
    const folder = folderPath(year, slug);

    // 1) remove storage files for this entry (whichever exist)
    const paths = FILE_KINDS.map((k) => `${folder}/${k.filename}`);
    const { error: rmErr } = await supabase.storage
      .from(STORAGE_BUCKET)
      .remove(paths);
    // Non-fatal: a missing object just isn't removed; only throw on real errors.
    if (rmErr) console.warn("Storage remove warning:", rmErr);

    // 2) delete the DB row
    const { error: dbErr } = await supabase.from("exams").delete().eq("id", id);
    if (dbErr) throw dbErr;

    allRows = allRows.filter((r) => r.id !== id);
    render();
  } catch (err) {
    console.error(err);
    alert(`تعذّر الحذف: ${err.message || err}`);
    btn.disabled = false;
    btn.textContent = "حذف";
  }
}

function escapeHtml(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
  );
}
function escapeAttr(s) {
  return escapeHtml(s);
}

export function mountManageView() {
  const host = document.getElementById("manage-mount");
  if (!host) return;

  if (!mounted) {
    host.innerHTML = template();
    el.tbody = document.getElementById("exams-tbody");
    el.empty = document.getElementById("manage-empty");
    el.total = document.getElementById("archive-total");
    el.search = document.getElementById("manage-search");

    el.search.addEventListener("input", () => {
      searchTerm = el.search.value;
      render();
    });

    // refresh after the add-content form saves something
    document.addEventListener("exams:changed", () => load());
    mounted = true;
  }
  load();
}
