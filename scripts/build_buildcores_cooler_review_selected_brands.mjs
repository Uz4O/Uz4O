import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const sourceDir = "/tmp/buildcores-open-db/open-db/CPUCooler";
const outputDir = "/Users/may/Documents/AI装机/outputs/buildcores_cooler_review";
const outputBase = "buildcores_cpu_coolers_selected_brands";
const outputXlsx = path.join(outputDir, `${outputBase}.xlsx`);
const outputCsv = path.join(outputDir, `${outputBase}.csv`);
const outputMarkdown = path.join(outputDir, `${outputBase}.md`);
const repoBaseUrl =
  "https://github.com/buildcores/buildcores-open-db/blob/main/open-db/CPUCooler";
const productBaseUrl = "https://buildcores.com/products/CPUCooler";

const selectedBrands = [
  { en: "Asus", zh: "华硕", screenshotCount: 71 },
  { en: "be quiet!", zh: "德商德静界", screenshotCount: 67 },
  { en: "Cooler Master", zh: "酷冷至尊", screenshotCount: 168 },
  { en: "Corsair", zh: "美商海盗船", screenshotCount: 103 },
  { en: "Deepcool", zh: "九州风神", screenshotCount: 182 },
  { en: "ID-COOLING", zh: "ID-COOLING", screenshotCount: 191 },
  { en: "Lian Li", zh: "联力", screenshotCount: 47 },
  { en: "MSI", zh: "微星", screenshotCount: 57 },
  { en: "Noctua", zh: "猫头鹰", screenshotCount: 54 },
  { en: "NZXT", zh: "恩杰", screenshotCount: 80 },
  { en: "Thermalright", zh: "利民", screenshotCount: 233 },
  { en: "TRYX", zh: "TRYX", screenshotCount: 16 },
];

const selectedByEnglish = new Map(selectedBrands.map((brand) => [brand.en, brand]));

const columns = [
  "审核状态",
  "品牌中文名",
  "品牌",
  "散热类型",
  "产品型号/名称",
  "厂商料号",
  "系列",
  "变体",
  "冷排尺寸mm",
  "散热器高度mm",
  "风扇尺寸mm",
  "风扇数量",
  "最低转速RPM",
  "最高转速RPM",
  "最低噪音dB",
  "最高噪音dB",
  "支持平台",
  "灯效",
  "颜色",
  "无风扇",
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

function coolerType(part) {
  if (part.water_cooled === true) return "水冷";
  if (part.fanless === true) return "被动/无风扇";
  if (part.water_cooled === false) return "风冷";
  return "";
}

const files = (await fs.readdir(sourceDir))
  .filter((file) => file.endsWith(".json"))
  .sort();

const rows = [];
const allBrandCounts = new Map();

for (const file of files) {
  const fullPath = path.join(sourceDir, file);
  const part = JSON.parse(await fs.readFile(fullPath, "utf8"));
  const metadata = part.metadata || {};
  const brand = metadata.manufacturer || "UNKNOWN";
  allBrandCounts.set(brand, (allBrandCounts.get(brand) || 0) + 1);

  const selected = selectedByEnglish.get(brand);
  if (!selected) continue;

  const openDbId = part.opendb_id || path.basename(file, ".json");
  rows.push({
    reviewStatus: "",
    brandZh: selected.zh,
    brand,
    type: coolerType(part),
    name: metadata.name || "",
    partNumbers: metadata.part_numbers || [],
    series: metadata.series || "",
    variant: metadata.variant || "",
    radiatorSize: part.radiator_size,
    height: part.height,
    fanSize: part.fan_size,
    fanQuantity: part.fan_quantity,
    minFanRpm: part.min_fan_rpm,
    maxFanRpm: part.max_fan_rpm,
    minNoiseLevel: part.min_noise_level,
    maxNoiseLevel: part.max_noise_level,
    cpuSockets: part.cpu_sockets || [],
    lighting: part.lighting || [],
    color: part.color || [],
    fanless: part.fanless,
    openDbId,
    productUrl: `${productBaseUrl}/${openDbId}`,
    githubUrl: `${repoBaseUrl}/${file}`,
  });
}

rows.sort((a, b) =>
  a.brand.localeCompare(b.brand, "zh-Hans-CN", { sensitivity: "base" }) ||
  a.type.localeCompare(b.type, "zh-Hans-CN") ||
  a.name.localeCompare(b.name, "zh-Hans-CN", { numeric: true }),
);

const rowToArray = (row) => [
  row.reviewStatus,
  row.brandZh,
  row.brand,
  row.type,
  row.name,
  row.partNumbers.join("; "),
  row.series,
  row.variant,
  row.radiatorSize,
  row.height,
  row.fanSize,
  row.fanQuantity,
  row.minFanRpm,
  row.maxFanRpm,
  row.minNoiseLevel,
  row.maxNoiseLevel,
  row.cpuSockets.join("; "),
  row.lighting.join("; "),
  row.color.join("; "),
  row.fanless,
  row.openDbId,
  row.productUrl,
  row.githubUrl,
];

const brandGroups = new Map();
for (const row of rows) {
  if (!brandGroups.has(row.brand)) brandGroups.set(row.brand, []);
  brandGroups.get(row.brand).push(row);
}

const countRows = selectedBrands.map((brand) => {
  const extracted = brandGroups.get(brand.en)?.length || 0;
  return [
    brand.zh,
    brand.en,
    brand.screenshotCount,
    extracted,
    extracted - brand.screenshotCount,
    extracted === brand.screenshotCount ? "" : "与截图数量不一致，可能是 OpenDB 与站点索引同步时间差。",
  ];
});

const summaryRows = selectedBrands.map((brand) => {
  const brandRows = brandGroups.get(brand.en) || [];
  return [
    brand.zh,
    brand.en,
    brandRows.length,
    brandRows.filter((row) => row.type === "风冷").length,
    brandRows.filter((row) => row.type === "水冷").length,
    brandRows.filter((row) => row.type === "被动/无风扇").length,
    brandRows.filter((row) => !row.type).length,
  ];
});

await fs.mkdir(outputDir, { recursive: true });

const csvLines = [columns.map(csvEscape).join(",")];
for (const row of rows) csvLines.push(rowToArray(row).map(csvEscape).join(","));
await fs.writeFile(outputCsv, `${csvLines.join("\n")}\n`, "utf8");

const md = [];
md.push("# BuildCores 散热器型号审核清单（截图勾选品牌）");
md.push("");
md.push(`来源：BuildCores OpenDB CPUCooler JSON`);
md.push(`筛选品牌：${selectedBrands.map((brand) => brand.en).join(", ")}`);
md.push(`总数：${rows.length} 条，品牌：${brandGroups.size} 个`);
md.push("");
md.push("## 数量对照");
md.push("");
md.push("| 中文品牌 | 英文品牌 | 截图数量 | 提取数量 | 差异 | 备注 |");
md.push("|---|---|---:|---:|---:|---|");
for (const row of countRows) {
  md.push(`| ${row.map((item) => String(item ?? "").replaceAll("|", "\\|")).join(" | ")} |`);
}
md.push("");
md.push("## 品牌汇总");
md.push("");
for (const [zh, en, total, air, liquid, fanless, unknown] of summaryRows) {
  md.push(`- ${zh}（${en}）: ${total} 条（风冷 ${air} / 水冷 ${liquid} / 被动 ${fanless} / 未知 ${unknown}）`);
}
await fs.writeFile(outputMarkdown, `${md.join("\n")}\n`, "utf8");

const workbook = Workbook.create();
const usedSheetNames = new Set();

function writeSheet(sheetName, matrix) {
  const sheet = workbook.worksheets.add(safeSheetName(sheetName, usedSheetNames));
  sheet.getRange(rangeAddress(matrix.length, matrix[0].length)).values = matrix;
}

writeSheet("数量对照", [
  ["中文品牌", "英文品牌", "截图数量", "提取数量", "差异", "备注"],
  ...countRows,
]);
writeSheet("品牌汇总", [
  ["中文品牌", "英文品牌", "总数", "风冷", "水冷", "被动/无风扇", "未知类型"],
  ...summaryRows,
]);
writeSheet("全部型号", [columns, ...rows.map(rowToArray)]);

for (const brand of selectedBrands) {
  const brandRows = brandGroups.get(brand.en) || [];
  writeSheet(`${brand.zh}-${brand.en}`, [columns, ...brandRows.map(rowToArray)]);
}

const exported = await SpreadsheetFile.exportXlsx(workbook);
await exported.save(outputXlsx);

console.log(
  JSON.stringify(
    {
      outputXlsx,
      outputCsv,
      outputMarkdown,
      totalFiles: files.length,
      exportedRows: rows.length,
      selectedBrands: selectedBrands.length,
      countRows,
      summaryRows,
      relatedUnselectedSpellings: [...allBrandCounts.entries()]
        .filter(([brand]) => ["DEEPCOOL", "DeepCool", "LIAN LI", "THERMALRIGHT"].includes(brand))
        .sort(),
    },
    null,
    2,
  ),
);
