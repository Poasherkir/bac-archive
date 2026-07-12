import { supabase } from "./supabaseClient.js";
import {
  STREAM,
  SUBJECTS,
  SUBJECT_SLUG,
  STORAGE_BUCKET,
  FILE_KINDS,
  folderPath,
} from "./constants.js";
import { mountManageView } from "./manage.js";

// ----------------------------------------------------------------------------
// Element refs
// ----------------------------------------------------------------------------
const $ = (sel) => document.querySelector(sel);

const bootLoader = $("#boot-loader");
const loginView = $("#login-view");
const appView = $("#app-view");

const loginForm = $("#login-form");
const loginEmail = $("#login-email");
const loginPassword = $("#login-password");
const loginBtn = $("#login-btn");
const loginError = $("#login-error");

const userEmailEl = $("#user-email");
const logoutBtn = $("#logout-btn");

const addForm = $("#add-form");
const yearInput = $("#f-year");
const subjectSelect = $("#f-subject");
const fileGrid = $("#file-grid");
const submitBtn = $("#submit-btn");
const formStatus = $("#form-status");
const progressWrap = $("#progress-wrap");
const progressBar = $("#progress-bar");

// ----------------------------------------------------------------------------
// Build static form pieces
// ----------------------------------------------------------------------------
function buildSubjectOptions() {
  subjectSelect.innerHTML =
    `<option value="" disabled selected>اختر المادة…</option>` +
    SUBJECTS.map((s) => `<option value="${s.label}">${s.label}</option>`).join("");
}

function buildFilePickers() {
  fileGrid.innerHTML = FILE_KINDS.map(
    (k) => `
    <div class="file-picker" data-kind="${k.key}">
      <div class="fp-label">${k.label}</div>
      <label class="fp-btn">
        اختر ملف PDF
        <input type="file" accept="application/pdf" data-kind="${k.key}" />
      </label>
      <span class="fp-name"></span>
    </div>`
  ).join("");

  fileGrid.querySelectorAll('input[type="file"]').forEach((input) => {
    input.addEventListener("change", () => {
      const picker = input.closest(".file-picker");
      const nameEl = picker.querySelector(".fp-name");
      const file = input.files[0];
      if (file && file.type !== "application/pdf") {
        input.value = "";
        nameEl.textContent = "الملف يجب أن يكون PDF";
        picker.classList.remove("filled");
        return;
      }
      nameEl.textContent = file ? file.name : "";
      picker.classList.toggle("filled", !!file);
    });
  });
}

// ----------------------------------------------------------------------------
// Auth
// ----------------------------------------------------------------------------
function showView(authenticated, user) {
  bootLoader.classList.add("hidden");
  loginView.classList.toggle("hidden", authenticated);
  appView.classList.toggle("hidden", !authenticated);
  if (authenticated && user) {
    userEmailEl.textContent = user.email ?? "";
    mountManageView(); // idempotent: builds once, refreshes data thereafter
  }
}

loginForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  loginError.classList.add("hidden");
  loginBtn.disabled = true;
  loginBtn.textContent = "جارٍ الدخول…";

  const { error } = await supabase.auth.signInWithPassword({
    email: loginEmail.value.trim(),
    password: loginPassword.value,
  });

  loginBtn.disabled = false;
  loginBtn.textContent = "تسجيل الدخول";

  if (error) {
    loginError.textContent = "بيانات الدخول غير صحيحة. حاول مرة أخرى.";
    loginError.classList.remove("hidden");
  }
  // onAuthStateChange handles the view switch on success.
});

logoutBtn.addEventListener("click", async () => {
  await supabase.auth.signOut();
});

supabase.auth.onAuthStateChange((_event, session) => {
  showView(!!session, session?.user);
});

// ----------------------------------------------------------------------------
// Add-content form submit
// ----------------------------------------------------------------------------
function setStatus(msg, kind) {
  formStatus.textContent = msg;
  formStatus.className = "status" + (kind ? " " + kind : "");
}

function selectedFiles() {
  // returns [{ kind, filename, urlColumn, file }] for pickers that have a file
  return FILE_KINDS
    .map((k) => {
      const input = fileGrid.querySelector(`input[data-kind="${k.key}"]`);
      const file = input?.files?.[0] || null;
      return file ? { ...k, file } : null;
    })
    .filter(Boolean);
}

addForm.addEventListener("submit", async (e) => {
  e.preventDefault();
  setStatus("");

  const year = yearInput.value.trim();
  const subject = subjectSelect.value;
  const slug = SUBJECT_SLUG[subject];
  const files = selectedFiles();

  // ---- validation ----
  if (!/^\d{4}$/.test(year)) {
    setStatus("أدخل سنة صحيحة مكوّنة من 4 أرقام.", "err");
    return;
  }
  if (!subject || !slug) {
    setStatus("اختر المادة.", "err");
    return;
  }
  if (files.length === 0) {
    setStatus("اختر ملف PDF واحدًا على الأقل.", "err");
    return;
  }

  submitBtn.disabled = true;
  progressWrap.classList.remove("hidden");
  progressBar.style.width = "0%";

  try {
    const folder = folderPath(year, slug);

    // ---- 1) upload each selected file (overwrite same path on re-upload) ----
    let done = 0;
    for (const f of files) {
      setStatus(`جارٍ رفع: ${f.label}…`);
      const { error: upErr } = await supabase.storage
        .from(STORAGE_BUCKET)
        .upload(`${folder}/${f.filename}`, f.file, {
          upsert: true,
          contentType: "application/pdf",
        });
      if (upErr) throw upErr;
      done += 1;
      progressBar.style.width = `${Math.round((done / files.length) * 90)}%`;
    }

    // ---- 2) read storage truth for this folder (URLs + total size) ----
    setStatus("جارٍ تحديث السجل…");
    const { data: objects, error: listErr } = await supabase.storage
      .from(STORAGE_BUCKET)
      .list(folder);
    if (listErr) throw listErr;

    const byName = Object.fromEntries((objects || []).map((o) => [o.name, o]));

    const row = { year, stream: STREAM, subject, file_size_bytes: 0 };
    for (const k of FILE_KINDS) {
      const obj = byName[k.filename];
      if (obj) {
        row[k.urlColumn] = supabase.storage
          .from(STORAGE_BUCKET)
          .getPublicUrl(`${folder}/${k.filename}`).data.publicUrl;
        row.file_size_bytes += obj.metadata?.size ?? 0;
      } else {
        row[k.urlColumn] = null;
      }
    }

    // ---- 3) upsert the exam row (one per year+stream+subject) ----
    const { error: dbErr } = await supabase
      .from("exams")
      .upsert(row, { onConflict: "year,stream,subject" });
    if (dbErr) throw dbErr;

    progressBar.style.width = "100%";
    setStatus(`تم الحفظ بنجاح — ${subject} ${year}`, "ok");

    // reset the form (keep the success message)
    addForm.reset();
    fileGrid.querySelectorAll(".file-picker").forEach((p) => {
      p.classList.remove("filled");
      p.querySelector(".fp-name").textContent = "";
    });
    subjectSelect.selectedIndex = 0;

    // let Step 3's management view refresh if present
    document.dispatchEvent(new CustomEvent("exams:changed"));
  } catch (err) {
    console.error(err);
    setStatus(`حدث خطأ: ${err.message || "تعذّر الحفظ"}`, "err");
  } finally {
    submitBtn.disabled = false;
    setTimeout(() => progressWrap.classList.add("hidden"), 800);
  }
});

// ----------------------------------------------------------------------------
// Boot
// ----------------------------------------------------------------------------
async function boot() {
  buildSubjectOptions();
  buildFilePickers();
  try {
    const { data } = await supabase.auth.getSession();
    showView(!!data.session, data.session?.user);
  } catch (err) {
    // e.g. config.js still has placeholder values — fall back to the login view.
    console.error("Auth session check failed:", err);
    showView(false, null);
  }
}

boot();
