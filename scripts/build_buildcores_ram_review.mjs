import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const sourceDir = "/tmp/buildcores-open-db/open-db/RAM";
const repoBaseUrl =
  "https://github.com/buildcores/buildcores-open-db/blob/main/open-db/RAM";
const productBaseUrl = "https://buildcores.com/products/RAM";
const outputDir = "/Users/may/Documents/AI装机/outputs/buildcores_ram_review";
const outputXlsx = path.join(outputDir, "buildcores_ram_ddr4_ddr5_by_brand.xlsx");
const outputCsv = path.join(outputDir, "buildcores_ram_ddr4_ddr5_by_brand.csv");
const outputMarkdown = path.join(
  outputDir,
  "buildcores_ram_ddr4_ddr5_by_brand.md",
);

const columns = [
  "审核状态",
  "品牌",
  "DDR类型",
  "产品型号/名称",
  "厂商料号",
  "系列",
  "变体",
  "总容量GB",
  "套条数量",
  "单条容量GB",
  "频率MHz",
  "CL",
  "时序",
  "电压",
  "形态",
  "ECC",
  "Registered",
  "RGB",
  "散热马甲",
  "颜色",
  "OpenDB ID",
  "BuildCores链接",
  "GitHub来源",
];

function cell(value) {
  if (Array.isArray(value)) return value.filter(Boolean).join("; ");
  if (value === null || value === undefined) return "";
  return value;
}

function csvEscape(value) {
  const text = String(cell(value));
  if (/[",\n\r]/.test(text)) return `"${text.replaceAll('"', '""')}"`;
  return text;
}

function rangeAddress(rowCount, colCount) {
  const colName = (n) => {
    let out = "";
    while (n > 0) {
      const rem = (n - 1) % 26;
      out = String.fromCharCode(65 + rem) + out;
      n = Math.floor((n - 1) / 26);
    }
    return out;
  };
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

const files = (await fs.readdir(sourceDir))
  .filter((file) => file.endsWith(".json"))
  .sort();

const rows = [];
const rejectedCounts = new Map();

for (const file of files) {
  const fullPath = path.join(sourceDir, file);
  const raw = await fs.readFile(fullPath, "utf8");
  const part = JSON.parse(raw);
  const ramType = part.ram_type || "";

  if (ramType !== "DDR4" && ramType !== "DDR5") {
    rejectedCounts.set(ramType || "UNKNOWN", (rejectedCounts.get(ramType || "UNKNOWN") || 0) + 1);
    continue;
  }

  const metadata = part.metadata || {};
  const modules = part.modules || {};
  const brand = metadata.manufacturer || "UNKNOWN";
  const openDbId = part.opendb_id || path.basename(file, ".json");

  rows.push({
    reviewStatus: "",
    brand,
    ramType,
    name: metadata.name || "",
    partNumbers: metadata.part_numbers || [],
    series: metadata.series || "",
    variant: metadata.variant || "",
    capacity: part.capacity,
    moduleQuantity: modules.quantity,
    moduleCapacityGb: modules.capacity_gb,
    speed: part.speed,
    casLatency: part.cas_latency,
    timings: part.timings,
    voltage: part.voltage,
    formFactor: part.form_factor,
    ecc: part.ecc,
    registered: part.registered,
    rgb: part.rgb,
    heatSpreader: part.heat_spreader,
    color: part.color || [],
    openDbId,
    productUrl: `${productBaseUrl}/${openDbId}`,
    githubUrl: `${repoBaseUrl}/${file}`,
  });
}

rows.sort((a, b) =>
  a.brand.localeCompare(b.brand, "zh-Hans-CN", { sensitivity: "base" }) ||
  a.ramType.localeCompare(b.ramType) ||
  a.name.localeCompare(b.name, "zh-Hans-CN", { numeric: true }),
);

const rowToArray = (row) => [
  row.reviewStatus,
  row.brand,
  row.ramType,
  row.name,
  row.partNumbers.join("; "),
  row.series,
  row.variant,
  row.capacity,
  row.moduleQuantity,
  row.moduleCapacityGb,
  row.speed,
  row.casLatency,
  row.timings,
  row.voltage,
  row.formFactor,
  row.ecc,
  row.registered,
  row.rgb,
  row.heatSpreader,
  row.color.join("; "),
  row.openDbId,
  row.productUrl,
  row.githubUrl,
];

const brandGroups = new Map();
for (const row of rows) {
  if (!brandGroups.has(row.brand)) brandGroups.set(row.brand, []);
  brandGroups.get(row.brand).push(row);
}

const summaryRows = [...brandGroups.entries()]
  .map(([brand, brandRows]) => [
    brand,
    brandRows.length,
    brandRows.filter((row) => row.ramType === "DDR4").length,
    brandRows.filter((row) => row.ramType === "DDR5").length,
  ])
  .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0], "zh-Hans-CN"));

await fs.mkdir(outputDir, { recursive: true });

const csvLines = [columns.map(csvEscape).join(",")];
for (const row of rows) csvLines.push(rowToArray(row).map(csvEscape).join(","));
await fs.writeFile(outputCsv, `${csvLines.join("\n")}\n`, "utf8");

const md = [];
md.push("# BuildCores DDR4/DDR5 内存型号审核清单");
md.push("");
md.push(`来源：BuildCores OpenDB RAM JSON`);
md.push(`筛选：仅保留 ram_type 为 DDR4 或 DDR5 的记录`);
md.push(`总数：${rows.length} 条，品牌：${brandGroups.size} 个`);
md.push(
  `排除：${[...rejectedCounts.entries()].map(([type, count]) => `${type} ${count}`).join("，")}`,
);
md.push("");
md.push("## 品牌汇总");
md.push("");
for (const [brand, total, ddr4, ddr5] of summaryRows) {
  md.push(`- ${brand}: ${total} 条（DDR4 ${ddr4} / DDR5 ${ddr5}）`);
}
md.push("");
md.push("## 按品牌型号");
for (const [brand, brandRows] of [...brandGroups.entries()].sort((a, b) =>
  a[0].localeCompare(b[0], "zh-Hans-CN", { sensitivity: "base" }),
)) {
  md.push("");
  md.push(`### ${brand}（${brandRows.length} 条）`);
  for (const row of brandRows) {
    const pn = row.partNumbers.length ? ` | ${row.partNumbers.join("; ")}` : "";
    md.push(`- ${row.ramType} | ${row.name}${pn}`);
  }
}
await fs.writeFile(outputMarkdown, `${md.join("\n")}\n`, "utf8");

const workbook = Workbook.create();
const usedSheetNames = new Set();

function writeSheet(sheetName, matrix) {
  const sheet = workbook.worksheets.add(safeSheetName(sheetName, usedSheetNames));
  const range = sheet.getRange(rangeAddress(matrix.length, matrix[0].length));
  range.values = matrix;
  return sheet;
}

writeSheet("品牌汇总", [
  ["品牌", "总数", "DDR4", "DDR5"],
  ...summaryRows,
]);

writeSheet("全部型号", [columns, ...rows.map(rowToArray)]);

for (const [brand, brandRows] of [...brandGroups.entries()].sort((a, b) =>
  a[0].localeCompare(b[0], "zh-Hans-CN", { sensitivity: "base" }),
)) {
  writeSheet(brand, [columns, ...brandRows.map(rowToArray)]);
}

const exported = await SpreadsheetFile.exportXlsx(workbook);
await exported.save(outputXlsx);

console.log(
  JSON.stringify(
    {
      sourceDir,
      outputXlsx,
      outputCsv,
      outputMarkdown,
      totalFiles: files.length,
      exportedRows: rows.length,
      brandCount: brandGroups.size,
      ramTypeCounts: {
        DDR4: rows.filter((row) => row.ramType === "DDR4").length,
        DDR5: rows.filter((row) => row.ramType === "DDR5").length,
      },
      rejectedCounts: Object.fromEntries(rejectedCounts),
      topBrands: summaryRows.slice(0, 12),
    },
    null,
    2,
  ),
);
