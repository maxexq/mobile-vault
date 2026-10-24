#!/usr/bin/env python3
"""Translations for Apocarlypse: Mobile Vault (MV-151). Thai in the code is the key; English is in i18n/en.json.

  python tools/i18n.py wrap FILE...      put Loc.t() around Thai string literals that are built into text at run
                                         time; lines where that would break the game are listed, not changed
  python tools/i18n.py extract           add every Thai literal of the translated files to i18n/en.json ("" = to do)
  python tools/i18n.py check [--phase N] untranslated keys used by the files of phase N (default: all); exit 1 if any
  python tools/i18n.py csv OUT.csv       thai,english sheet for review (open in Excel / Google Sheets)
  python tools/i18n.py import-csv IN.csv read the english column back into i18n/en.json

Not translated on purpose: the GOD MODE panel and Dev (tester tools stay Thai), see SKIP.
Stdlib only, works on Windows.
"""
import csv
import glob
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
EN = os.path.join(ROOT, "i18n", "en.json")
TH = re.compile(r"[฀-๿]")
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
SKIP = {"scripts/ui/god_panel.gd", "scripts/autoload/dev.gd"}
# the three PRs of MV-151: UI chrome, game data, lore / chatter / stories
PHASES = {
    1: ["scripts/ui/*.gd", "scripts/main.gd", "scripts/autoload/tutorial.gd", "scripts/autoload/settings.gd",
        "scripts/autoload/cloud.gd", "scripts/build_info.gd", "scripts/autoload/modes.gd"],
}
# a Thai literal on such a line is compared or matched against data: translating it would break the logic
RISKY = re.compile(r'==|!=|\.contains\(|\.begins_with\(|\.ends_with\(|\.find\(|\.has\(|\bin \[|\.erase\(|\.split\(|\.replace\(')


def rel(p):
    return os.path.relpath(p, ROOT).replace("\\", "/")


def files_of(phase=None):
    pats = PHASES[phase] if phase else ["scripts/**/*.gd"]
    out = []
    for pat in pats:
        for f in glob.glob(os.path.join(ROOT, pat), recursive=True):
            if rel(f) not in SKIP and f not in out:
                out.append(f)
    return sorted(out)


def unescape(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\"}.get(n, "\\" + n))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def code_part(line):
    """the line without a trailing # comment (a # inside a string is kept)"""
    q = False
    for i, c in enumerate(line):
        if c == '"' and (i == 0 or line[i - 1] != "\\"):
            q = not q
        elif c == "#" and not q:
            return line[:i]
    return line


CTX = re.compile(r'\s*,\s*"([a-z_]+)"\s*\)')


def literals(path):
    """(line_no, raw_literal, start, end) of every Thai literal outside comments. A literal in
    Loc.t("...", "ctx") comes back as "@ctx:..." (same Thai word, another meaning)"""
    out = []
    with open(path, encoding="utf-8") as fh:
        for no, line in enumerate(fh, 1):
            code = code_part(line)
            if code.lstrip().startswith("#"):
                continue
            for m in LIT.finditer(code):
                if TH.search(m.group(1)):
                    c = CTX.match(code, m.end())
                    raw = ("@%s:" % c.group(1) + m.group(1)) if c and code[:m.start()].rstrip().endswith("Loc.t(") else m.group(1)
                    out.append((no, raw, m.start(), m.end()))
    return out


def load_en():
    if os.path.exists(EN):
        with open(EN, encoding="utf-8") as fh:
            return json.load(fh)
    return {}


def save_en(d):
    os.makedirs(os.path.dirname(EN), exist_ok=True)
    with open(EN, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(dict(sorted(d.items())), fh, ensure_ascii=False, indent=1)
        fh.write("\n")


def cmd_wrap(paths):
    skipped = []
    for p in paths:
        p = os.path.join(ROOT, p) if not os.path.isabs(p) else p
        with open(p, encoding="utf-8", newline="") as fh:
            lines = fh.read().split("\n")
        depth, in_const, changed = 0, False, 0
        for i, line in enumerate(lines):
            code = code_part(line)
            s = code.strip()
            starts_const = re.match(r"(static\s+)?(const|enum)\b", s) is not None
            class_var = re.match(r"(static\s+)?var\b", code) is not None      # column 0 = class level
            if starts_const:
                in_const = True
            opens = code.count("[") + code.count("{") + code.count("(")
            closes = code.count("]") + code.count("}") + code.count(")")
            blocked = in_const or class_var or s.startswith(("func ", "static func ", "@", "match ")) or RISKY.search(code)
            if TH.search(code) and LIT.search(code):
                new, last, n = [], 0, 0
                for m in LIT.finditer(code):
                    if not TH.search(m.group(1)):
                        continue
                    before = code[:m.start()].rstrip()
                    after = code[m.end():].lstrip()
                    if before.endswith(("Loc.t(", "tr(")):
                        continue
                    if blocked or (after.startswith(":") and not after.startswith("::")):
                        skipped.append("%s:%d  %s" % (rel(p), i + 1, s[:110]))
                        break
                    new.append(code[last:m.start()] + "Loc.t(" + m.group(0) + ")")
                    last = m.end()
                    n += 1
                if n:
                    lines[i] = "".join(new) + code[last:] + line[len(code):]
                    changed += n
            if in_const:
                depth += opens - closes
                if depth <= 0:
                    in_const, depth = False, 0
        with open(p, "w", encoding="utf-8", newline="") as fh:
            fh.write("\n".join(lines))
        print("%s: %d wrapped" % (rel(p), changed))
    if skipped:
        print("\nleft for manual review (%d): const / class var / comparison / key / signature lines" % len(skipped))
        for s in skipped:
            print("  " + s)


def cmd_extract():
    d, added = load_en(), 0
    for f in files_of():
        for _, raw, _, _ in literals(f):
            k = unescape(raw)
            if k not in d:
                d[k] = ""
                added += 1
    save_en(d)
    print("en.json: %d keys, %d new, %d without English" % (len(d), added, sum(1 for v in d.values() if v == "")))


def cmd_check(phase):
    d = load_en()
    todo = {}
    for f in files_of(phase):
        for no, raw, _, _ in literals(f):
            k = unescape(raw)
            if d.get(k, "") == "":
                todo.setdefault(k, "%s:%d" % (rel(f), no))
    for k, where in todo.items():
        print("%s  %s" % (where, k.replace("\n", "\\n")[:100]))
    print("%s: %d untranslated" % ("phase %d" % phase if phase else "all files", len(todo)))
    return 1 if todo else 0


def cmd_csv(out):
    d = load_en()
    with open(out, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["thai", "english"])
        for k, v in sorted(d.items()):
            w.writerow([k, v])
    print("wrote %s (%d rows)" % (out, len(d)))


def cmd_import_csv(src):
    d, n = load_en(), 0
    with open(src, encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            if row.get("thai") in d and row.get("english", "") != d[row["thai"]]:
                d[row["thai"]] = row["english"]
                n += 1
    save_en(d)
    print("updated %d translations" % n)


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    c = argv[1]
    if c == "wrap":
        cmd_wrap(argv[2:])
    elif c == "extract":
        cmd_extract()
    elif c == "check":
        phase = int(argv[argv.index("--phase") + 1]) if "--phase" in argv else None
        return cmd_check(phase)
    elif c == "csv":
        cmd_csv(argv[2])
    elif c == "import-csv":
        cmd_import_csv(argv[2])
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
