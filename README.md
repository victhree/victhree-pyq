# VicThree Defence — CDS PYQ Library

A free, mobile-first website that lets students **browse CDS Previous Year Questions**
(subject-wise, topic-wise, year-wise) and **take a random 50-question practice quiz**.
Plain HTML/CSS/JS, no build step, hosted on **GitHub Pages from the `/docs` folder**.

**Brand:** VicThree Defence by Anmol Sharma · Navy `#0B1F3A` / Gold `#C9A24B`

---

## What's live

- **Browse** (`docs/index.html`): filter by **Subject → Topic → Year/Paper** (each has an
  "All" option; filters combine), full-text **search**, **year-wise sorting**, a gold PYQ
  source tag (`★ CDS 2019-II, Q.34`), and a **Show answer** reveal with the correct option +
  explanation.
- **Random 50 Quiz** (`docs/quiz.html`): pulls 50 random questions from the entire answerable
  pool, **untimed**, grades in the browser, and shows score + correct answers + explanations.
- **Counts**: header shows `333 questions · 1 subject · 2016–2025`.

### Current data — Geography
- **333 questions**, CDS **2016-II → 2025-II** (19 papers).
- **329** have a correct answer + explanation. **4** are left unanswered because the *source
  paper itself* had a formatting issue (options/list unreadable) — these are flagged in-app
  with a "Source note". They are: `2025-I Q.1`, `2017-II Q.82`, `2024-II Q.72`, `2017-II Q.52`.
- **1 answer-key correction** applied: `2017-II Q.104` — the key labelled it `d`, but in this
  compilation the correct sequence (3, 2, 4, 1) is option **c**; corrected to `c`.
- Topic taxonomy: the compiler's 13 topics collapsed into **7 buckets** (subtopics preserved
  in each question for future use).

---

## Folder structure

```
victhree-pyq/
├─ README.md
├─ .claude/launch.json        # local preview config (not published)
├─ tools/                     # data-prep scripts (not published)
│  ├─ parse_geography.ps1     # PDF text + answer DOCX  ->  geography.json
│  ├─ build_index.ps1         # scans docs/data/*.json  ->  index.json
│  └─ serve.ps1               # tiny local static server for preview
└─ docs/                      # ← GitHub Pages serves THIS folder
   ├─ .nojekyll               # serve files as-is (no Jekyll processing)
   ├─ index.html              # Browse page
   ├─ quiz.html               # Random 50 quiz
   ├─ assets/banner.jpg       # ← put your banner image here (see below)
   ├─ css/styles.css
   ├─ js/{data.js, browse.js, quiz.js}
   └─ data/
      ├─ index.json           # manifest: subjects, topics, years, counts
      └─ geography.json       # one file per subject
```

## The banner

The header looks for `docs/assets/banner.jpg`. If it's missing, a clean navy/gold text header
shows instead. **To add it:** drop a `.jpg` (or `.png` renamed to `.jpg`) at
`docs/assets/banner.jpg` — the same banner you use on your mock-test site. Wide images
(e.g. 1200×300) look best; it's capped at 300px tall and cropped to fit.

---

## Data model

Each `docs/data/<subject>.json` is an array of question objects:

```json
{
  "id": "geo-2021-II-q9",
  "subject": "Geography",
  "topic": "Physical Geography",          // one of the 7 buckets (the filterable topic)
  "subtopic": "Interior of Earth",        // finer label, preserved from the source
  "topicOriginal": "Physical Geography",  // the compiler's original 13-topic label
  "year": 2021,
  "session": "II",
  "paper": "CDS 2021-II",
  "qno": 9,
  "ref": "CDS 2021-II, Q.9",              // the gold tag text
  "stem": "What is the approximate percentage of carbon in the Earth's crust?",
  "subs": ["1. ...", "2. ..."],           // sub-statements / match-lists / "Select the code…"
  "options": ["0.045", "0.025", "0.015", "0.005"],   // always 4 (a–d); "" if source omitted one
  "answer": "b",                          // "" if no answer available
  "explanation": "Carbon is a trace element …",
  "answerNote": "…"                       // only present when the source flagged a formatting issue
}
```

`docs/data/index.json` is the manifest the pages read first (subjects, each subject's topics +
papers with counts, and grand totals). **It is generated — don't edit it by hand.**

---

## Adding more PDFs / subjects later

The flow is the same one used for Geography:

1. **Parse the PDF.** Extract its text (the prep machine has Git's `pdftotext`):
   ```powershell
   & "C:\Program Files\Git\mingw64\bin\pdftotext.exe" -layout "path\to\Subject.pdf" "$env:TEMP\subject.txt"
   ```
   Then produce `docs/data/<subject>.json` in the data-model shape above. For Geography this is
   automated in `tools/parse_geography.ps1`; a new subject usually needs its own small parser
   or a hand-built JSON, plus its own topic taxonomy (propose → approve → tag).
2. **Drop the answer key** (if separate) and merge correct letters + explanations in.
3. **Rebuild the manifest:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\build_index.ps1
   ```
   This rescans `docs/data/*.json` and rewrites `index.json` with new counts/topics/years.
   No front-end changes needed — the new subject appears in the filters automatically.

> Tip: add subjects **one at a time** and sanity-check the topic tagging before moving on.

---

## Preview it locally

No Node/Python needed — a small PowerShell static server is included:

```powershell
powershell -ExecutionPolicy Bypass -File tools\serve.ps1 -Port 4178 -Root docs
# then open http://localhost:4178/
```

---

## Deploy to GitHub Pages (step by step)

You'll publish the `/docs` folder of a new repo.

1. **Create the repo on GitHub**
   - Go to <https://github.com/new>.
   - Name it e.g. `victhree-pyq` (or `cds-pyq`). Keep it **Public** (Pages is free for public
     repos). Don't add a README/.gitignore (we have files already). Click **Create repository**.

2. **Push this folder** (run in `C:\Users\ASUS\victhree-pyq`):
   ```powershell
   git init
   git add .
   git commit -m "CDS PYQ Library — Geography (333 Qs) + browse & quiz"
   git branch -M main
   git remote add origin https://github.com/<your-username>/victhree-pyq.git
   git push -u origin main
   ```

3. **Enable Pages**
   - In the repo: **Settings → Pages**.
   - **Source:** "Deploy from a branch".
   - **Branch:** `main`, **Folder:** `/docs`. Click **Save**.

4. **Wait ~1 minute**, then open the URL shown on that Pages screen:
   `https://<your-username>.github.io/victhree-pyq/`
   - Browse and Quiz both work as relative paths, so they're fine under this sub-path.

5. **Add the banner** (anytime): commit `docs/assets/banner.jpg`, push, done.

### Updating later
After adding a subject and running `build_index.ps1`:
```powershell
git add .
git commit -m "Add <Subject> (<N> questions)"
git push
```
Pages redeploys automatically in a minute or so.

---

*Answers are previous-year public knowledge and are graded entirely in the browser — there is
no server and no secret key (unlike the mock-test site).*
