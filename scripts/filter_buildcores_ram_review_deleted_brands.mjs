import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const inputCsv =
  "/Users/may/Documents/AI装机/outputs/buildcores_ram_review/buildcores_ram_ddr4_ddr5_by_brand_zh.csv";
const outputDir = "/Users/may/Documents/AI装机/outputs/buildcores_ram_review";
const outputBase = "buildcores_ram_ddr4_ddr5_by_brand_zh_filtered";
const outputCsv = path.join(outputDir, `${outputBase}.csv`);
const outputMarkdown = path.join(outputDir, `${outputBase}.md`);
const outputXlsx = path.join(outputDir, `${outputBase}.xlsx`);

const deletionRules = [
  { requested: "杰兴科技", zh: ["杰新科技"], en: ["Addlink"], note: "按疑似错字处理：杰兴科技 -> 杰新科技/Addlink" },
  { requested: "超威半导体", zh: ["超威半导体"], en: ["AMD"], note: "" },
  { requested: "avexir", zh: ["宇帷"], en: ["Avexir"], note: "按英文品牌 Avexir 处理" },
  { requested: "铂胜", zh: ["铂胜"], en: ["Ballistix"], note: "" },
  { requested: "艾维克", zh: ["艾维克"], en: ["EVGA"], note: "" },
  { requested: "金邦", zh: ["金邦"], en: ["GeIL"], note: "" },
  { requested: "立达国际", zh: ["立达国际"], en: ["Gigastone"], note: "" },
  { requested: "固德兰", zh: ["固德兰"], en: ["GOODRAM"], note: "" },
  { requested: "极度未知", zh: ["极度未知"], en: ["HyperX"], note: "" },
  { requested: "穆什金", zh: ["穆什金"], en: ["Mushkin", "MUSHKIN"], note: "覆盖 Mushkin 与 MUSHKIN 两种写法" },
  { requested: "凌航", zh: ["凌航"], en: ["Neo Forza"], note: "" },
  { requested: "奥洛依", zh: ["奥洛依"], en: ["OLOy"], note: "" },
  { requested: "美商博帝", zh: ["美商博帝"], en: ["Patriot"], note: "" },
  { requested: "广颖电通", zh: ["广颖电通"], en: ["Silicon Power"], note: "" },
  { requested: "美超微", zh: ["美超微"], en: ["Supermicro"], note: "" },
  { requested: "十铨", zh: ["十铨"], en: ["TEAMGROUP"], note: "" },
  { requested: "耀越", zh: ["曜越"], en: ["Thermaltake"], note: "按常见品牌中文写法“曜越”处理" },
  { requested: "全何科技", zh: ["全何科技"], en: ["v-color"], note: "" },
  { requested: "泰美特", zh: ["泰美特"], en: ["Timetec"], note: "" },
  { requested: "未知", zh: ["未知"], en: ["UNKNOWN"], note: "" },
  { requested: "维信泰克", zh: ["维信泰克"], en: ["VisionTek"], note: "" },
];

function parseCsv(text) {
  const rows = [];
  let row = [];
  let value = "";
  let quoted = false;

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    const next = text[i + 1];
    if (quoted) {
      if (ch === '"' && next === '"') {
        value += '"';
        i += 1;
      } else if (ch === '"') {
        quoted = false;
      } else {
        value += ch;
      }
      continue;
    }

    if (ch === '"') quoted = true;
    else if (ch === ",") {
      row.push(value);
      value = "";
    } else if (ch === "\n") {
      row.push(value);
      rows.push(row);
      row = [];
      value = "";
    } else if (ch !== "\r") {
      value += ch;
    }
  }
  if (value || row.length) {
    row.push(value);
    rows.push(row);
  }
  return rows;
}

function csvEscape(value) {
  const text = String(value ?? "");
  if (/[",\n\r]/.test(text)) return `"${text.replaceAll('"', '""')}"`;
  return text;
}

function colName(n) {
  let out = "";
  while (n > 0) {
    const rem = (n - 1) % 26;
    out = String.fromCharCode(65 + rem) + out;
    n = Math.floor((n - 1) / 26);
  }
  return out;
}

function rangeAddress(rowCount, colCount) {
  return `A1:${colName(colCount)}${rowCount}`;
}

function safeSheetName(name, used) {
  let base = String(name || "UNKNOWN")
    .replace(/[\\/*?:[\]]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 31);
  if (!base) base = "UNKNOWN";
  let candidate = base;
  let suffix = 2;
  while (used.has(candidate)) {
    const tail = ` ${suffix}`;
    candidate = `${base.slice(0, 31 - tail.length)}${tail}`;
    suffix += 1;
  }
  used.add(candidate);
  return candidate;
}

const raw = parseCsv(await fs.readFile(inputCsv, "utf8"));
const headers = raw[0];
const rows = raw.slice(1).filter((row) => row.length > 1);
const zhIndex = headers.indexOf("品牌中文名");
const brandIndex = headers.indexOf("品牌");
const ddrIndex = headers.indexOf("DDR类型");
if (zhIndex < 0 || brandIndex < 0 || ddrIndex < 0) {
  throw new Error("Input CSV is missing 品牌中文名, 品牌, or DDR类型.");
}

const zhDelete = new Set(deletionRules.flatMap((rule) => rule.zh));
const enDelete = new Set(deletionRules.flatMap((rule) => rule.en));
const removed = [];
const kept = [];

for (const row of rows) {
  if (zhDelete.has(row[zhIndex]) || enDelete.has(row[brandIndex])) removed.push(row);
  else kept.push(row);
}

function countByBrand(sourceRows) {
  const out = new Map();
  for (const row of sourceRows) {
    const key = `${row[zhIndex]}\u0000${row[brandIndex]}`;
    if (!out.has(key)) {
      out.set(key, {
        zh: row[zhIndex],
        en: row[brandIndex],
        total: 0,
        DDR4: 0,
        DDR5: 0,
        basis: row[headers.indexOf("中文名依据")] || "",
        source: row[headers.indexOf("中文名来源链接")] || "",
        note: row[headers.indexOf("中文名备注")] || "",
      });
    }
    const entry = out.get(key);
    entry.total += 1;
    if (row[ddrIndex] === "DDR4") entry.DDR4 += 1;
    if (row[ddrIndex] === "DDR5") entry.DDR5 += 1;
  }
  return [...out.values()].sort(
    (a, b) => b.total - a.total || a.zh.localeCompare(b.zh, "zh-Hans-CN"),
  );
}

const keptSummary = countByBrand(kept);
const removedSummary = countByBrand(removed);

const deletionSummary = deletionRules.map((rule) => {
  const matched = removedSummary.filter(
    (entry) => rule.zh.includes(entry.zh) || rule.en.includes(entry.en),
  );
  return [
    rule.requested,
    [...new Set(matched.map((entry) => entry.zh))].join("; "),
    [...new Set(matched.map((entry) => entry.en))].join("; "),
    matched.reduce((sum, entry) => sum + entry.total, 0),
    matched.reduce((sum, entry) => sum + entry.DDR4, 0),
    matched.reduce((sum, entry) => sum + entry.DDR5, 0),
    rule.note,
  ];
});

await fs.mkdir(outputDir, { recursive: true });
await fs.writeFile(
  outputCsv,
  [headers.map(csvEscape).join(","), ...kept.map((row) => row.map(csvEscape).join(","))].join("\n") + "\n",
  "utf8",
);

const md = [];
md.push("# BuildCores DDR4/DDR5 内存型号审核清单（已删除指定品牌）");
md.push("");
md.push(`删除前：${rows.length} 条`);
md.push(`删除：${removed.length} 条`);
md.push(`保留：${kept.length} 条`);
md.push("");
md.push("## 删除品牌清单");
md.push("");
md.push("| 请求删除名 | 实际中文品牌 | 英文品牌 | 删除数 | DDR4 | DDR5 | 备注 |");
md.push("|---|---|---:|---:|---:|---:|---|");
for (const row of deletionSummary) {
  md.push(`| ${row.map((cell) => String(cell ?? "").replaceAll("|", "\\|")).join(" | ")} |`);
}
md.push("");
md.push("## 保留品牌汇总");
md.push("");
for (const entry of keptSummary) {
  md.push(`- ${entry.zh}（${entry.en}）: ${entry.total} 条（DDR4 ${entry.DDR4} / DDR5 ${entry.DDR5}）`);
}
await fs.writeFile(outputMarkdown, md.join("\n") + "\n", "utf8");

const workbook = Workbook.create();
const usedSheetNames = new Set();

function writeSheet(sheetName, matrix) {
  const sheet = workbook.worksheets.add(safeSheetName(sheetName, usedSheetNames));
  sheet.getRange(rangeAddress(matrix.length, matrix[0].length)).values = matrix;
}

writeSheet("删除品牌清单", [
  ["请求删除名", "实际中文品牌", "英文品牌", "删除数", "DDR4", "DDR5", "备注"],
  ...deletionSummary,
]);
writeSheet("保留品牌汇总", [
  ["中文品牌", "英文品牌", "总数", "DDR4", "DDR5", "中文名依据", "中文名来源链接", "中文名备注"],
  ...keptSummary.map((entry) => [
    entry.zh,
    entry.en,
    entry.total,
    entry.DDR4,
    entry.DDR5,
    entry.basis,
    entry.source,
    entry.note,
  ]),
]);
writeSheet("已删除型号", [headers, ...removed]);
writeSheet("全部型号", [headers, ...kept]);

const brandGroups = new Map();
for (const row of kept) {
  const key = `${row[zhIndex]}-${row[brandIndex]}`;
  if (!brandGroups.has(key)) brandGroups.set(key, []);
  brandGroups.get(key).push(row);
}

for (const [brand, brandRows] of [...brandGroups.entries()].sort((a, b) =>
  a[0].localeCompare(b[0], "zh-Hans-CN", { sensitivity: "base" }),
)) {
  writeSheet(brand, [headers, ...brandRows]);
}

const exported = await SpreadsheetFile.exportXlsx(workbook);
await exported.save(outputXlsx);

console.log(
  JSON.stringify(
    {
      outputXlsx,
      outputCsv,
      outputMarkdown,
      beforeRows: rows.length,
      removedRows: removed.length,
      keptRows: kept.length,
      keptTypes: {
        DDR4: kept.filter((row) => row[ddrIndex] === "DDR4").length,
        DDR5: kept.filter((row) => row[ddrIndex] === "DDR5").length,
      },
      removedTypes: {
        DDR4: removed.filter((row) => row[ddrIndex] === "DDR4").length,
        DDR5: removed.filter((row) => row[ddrIndex] === "DDR5").length,
      },
      deletionSummary,
    },
    null,
    2,
  ),
);
