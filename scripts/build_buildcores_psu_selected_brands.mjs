import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const sourceDir = "/tmp/buildcores-open-db/open-db/PSU";
const outputDir = "/Users/may/Documents/AI装机/outputs/buildcores_psu_review";
const outputBase = "buildcores_psu_selected_brands";
const outputXlsx = path.join(outputDir, `${outputBase}.xlsx`);
const outputCsv = path.join(outputDir, `${outputBase}.csv`);
const outputMarkdown = path.join(outputDir, `${outputBase}.md`);
const repoBaseUrl =
  "https://github.com/buildcores/buildcores-open-db/blob/main/open-db/PSU";
const productBaseUrl = "https://buildcores.com/products/PSU";

const selectedBrands = [
  { request: "ADATA", zh: "威刚", en: "ADATA", aliases: ["ADATA"], screenshotCount: 24, source: "截图" },
  { request: "Asus / ASUS", zh: "华硕", en: "Asus", aliases: ["Asus", "ASUS"], screenshotCount: 46, source: "截图" },
  { request: "Cooler Master", zh: "酷冷至尊", en: "Cooler Master", aliases: ["Cooler Master"], screenshotCount: 209, source: "截图" },
  { request: "Deepcool", zh: "九州风神", en: "Deepcool", aliases: ["Deepcool", "DeepCool"], screenshotCount: 70, source: "截图" },
  { request: "MSI / MSI ", zh: "微星", en: "MSI", aliases: ["MSI", "MSI "], screenshotCount: 46, source: "截图" },
  { request: "SAMA", zh: "先马", en: "SAMA", aliases: ["SAMA"], screenshotCount: 6, source: "截图" },
  { request: "SeaSonic / Seasonic", zh: "海韵", en: "Seasonic", aliases: ["SeaSonic", "Seasonic"], screenshotCount: 224, source: "截图" },
  { request: "Segotep", zh: "鑫谷", en: "Segotep", aliases: ["Segotep"], screenshotCount: 13, source: "截图" },
  { request: "Super Flower", zh: "振华", en: "Super Flower", aliases: ["Super Flower"], screenshotCount: 78, source: "截图" },
  { request: "长城", zh: "长城", en: "Great Wall", aliases: ["Great Wall", "长城"], screenshotCount: null, source: "额外检查" },
  { request: "玄武", zh: "玄武", en: "Xuanwu", aliases: ["Xuanwu", "玄武"], screenshotCount: null, source: "额外检查" },
];

const brandByAlias = new Map();
for (const brand of selectedBrands) {
  for (const alias of brand.aliases) brandByAlias.set(alias, brand);
}

const columns = [
  "审核状态",
  "品牌中文名",
  "品牌",
  "源品牌字段",
  "产品型号/名称",
  "厂商料号",
  "系列",
  "变体",
  "功率W",
  "规格",
  "80PLUS认证",
  "Cybenetics效率",
  "Cybenetics噪音",
  "模组",
  "长度mm",
  "无风扇",
  "颜色",
  "灯效",
  "ATX 24pin",
  "CPU EPS 8pin",
  "12VHPWR",
  "PCIe 6+2pin",
  "SATA供电",
  "Molex 4pin",
  "Floppy 4pin",
  "OpenDB ID",
  "BuildCores链接",
  "GitHub来源",
];

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

const files = (await fs.readdir(sourceDir))
  .filter((file) => file.endsWith(".json"))
  .sort();

const rows = [];
const selectedAllCounts = new Map(selectedBrands.map((brand) => [brand.en, 0]));

for (const file of files) {
  const fullPath = path.join(sourceDir, file);
  const part = JSON.parse(await fs.readFile(fullPath, "utf8"));
  const metadata = part.metadata || {};
  const sourceBrand = metadata.manufacturer || "UNKNOWN";
  const brand = brandByAlias.get(sourceBrand);
  if (!brand) continue;

  selectedAllCounts.set(brand.en, selectedAllCounts.get(brand.en) + 1);
  const connectors = part.connectors || {};
  const openDbId = part.opendb_id || path.basename(file, ".json");

  rows.push({
    reviewStatus: "",
    brandZh: brand.zh,
    brand: brand.en,
    sourceBrand,
    name: metadata.name || "",
    partNumbers: metadata.part_numbers || [],
    series: metadata.series || "",
    variant: metadata.variant || "",
    wattage: part.wattage,
    formFactor: part.form_factor,
    efficiencyRating: part.efficiency_rating,
    cyberneticsEfficiencyRating: part.cybernetics_efficiency_rating,
    cyberneticsNoiseRating: part.cybernetics_noise_rating,
    modular: part.modular,
    length: part.length,
    fanless: part.fanless,
    color: part.color || [],
    lighting: part.lighting || [],
    atx24Pin: connectors.atx_24_pin,
    eps8Pin: connectors.eps_8_pin,
    pcie12vhpwr: connectors.pcie_12vhpwr,
    pcie6Plus2Pin: connectors.pcie_6_plus_2_pin,
    sata: connectors.sata,
    molex4Pin: connectors.molex_4_pin,
    floppy4Pin: connectors.floppy_4_pin,
    openDbId,
    productUrl: `${productBaseUrl}/${openDbId}`,
    githubUrl: `${repoBaseUrl}/${file}`,
  });
}

rows.sort((a, b) =>
  a.brand.localeCompare(b.brand, "zh-Hans-CN", { sensitivity: "base" }) ||
  (a.wattage ?? 0) - (b.wattage ?? 0) ||
  a.name.localeCompare(b.name, "zh-Hans-CN", { numeric: true }),
);

const rowToArray = (row) => [
  row.reviewStatus,
  row.brandZh,
  row.brand,
  row.sourceBrand,
  row.name,
  row.partNumbers.join("; "),
  row.series,
  row.variant,
  row.wattage,
  row.formFactor,
  row.efficiencyRating,
  row.cyberneticsEfficiencyRating,
  row.cyberneticsNoiseRating,
  row.modular,
  row.length,
  row.fanless,
  row.color.join("; "),
  row.lighting.join("; "),
  row.atx24Pin,
  row.eps8Pin,
  row.pcie12vhpwr,
  row.pcie6Plus2Pin,
  row.sata,
  row.molex4Pin,
  row.floppy4Pin,
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
  const screenshotCount = brand.screenshotCount ?? "";
  const diff = brand.screenshotCount === null ? "" : extracted - brand.screenshotCount;
  let status = extracted ? "已提取" : "未命中，已跳过";
  if (brand.screenshotCount !== null && diff !== 0) status = "与截图数量不一致";
  return [
    brand.source,
    brand.request,
    brand.zh,
    brand.en,
    brand.aliases.join("; "),
    screenshotCount,
    extracted,
    diff,
    status,
  ];
});

const summaryRows = selectedBrands
  .map((brand) => {
    const brandRows = brandGroups.get(brand.en) || [];
    const wattages = [...new Set(brandRows.map((row) => row.wattage).filter((value) => value !== null && value !== undefined))]
      .sort((a, b) => a - b)
      .join("; ");
    return [
      brand.zh,
      brand.en,
      brandRows.length,
      brandRows.filter((row) => row.formFactor === "ATX").length,
      brandRows.filter((row) => row.formFactor === "SFX").length,
      brandRows.filter((row) => row.formFactor === "SFX-L").length,
      brandRows.filter((row) => row.modular === "Full").length,
      brandRows.filter((row) => row.modular === "Semi-Modular").length,
      brandRows.filter((row) => row.modular === "Non-Modular").length,
      wattages,
    ];
  })
  .filter((row) => row[2] > 0);

await fs.mkdir(outputDir, { recursive: true });

const csvLines = [columns.map(csvEscape).join(",")];
for (const row of rows) csvLines.push(rowToArray(row).map(csvEscape).join(","));
await fs.writeFile(outputCsv, `${csvLines.join("\n")}\n`, "utf8");

const md = [];
md.push("# BuildCores 电源型号审核清单（截图品牌 + 长城/玄武检查）");
md.push("");
md.push(`来源：BuildCores OpenDB PSU JSON`);
md.push(`总数：${rows.length} 条，命中品牌：${brandGroups.size} 个，请求品牌：${selectedBrands.length} 个`);
md.push("");
md.push("## 品牌命中情况");
md.push("");
md.push("| 来源 | 请求品牌 | 中文品牌 | 英文品牌 | 匹配源品牌字段 | 截图数量 | 提取数量 | 差异 | 状态 |");
md.push("|---|---|---|---|---|---:|---:|---:|---|");
for (const row of countRows) {
  md.push(`| ${row.map((item) => String(item ?? "").replaceAll("|", "\\|")).join(" | ")} |`);
}
md.push("");
md.push("## 品牌汇总");
md.push("");
for (const [zh, en, total, atx, sfx, sfxl, full, semi, non, wattages] of summaryRows) {
  md.push(`- ${zh}（${en}）: ${total} 条（ATX ${atx} / SFX ${sfx} / SFX-L ${sfxl}，全模组 ${full} / 半模组 ${semi} / 非模组 ${non}，功率W：${wattages}）`);
}
await fs.writeFile(outputMarkdown, `${md.join("\n")}\n`, "utf8");

const workbook = Workbook.create();
const usedSheetNames = new Set();

function writeSheet(sheetName, matrix) {
  const sheet = workbook.worksheets.add(safeSheetName(sheetName, usedSheetNames));
  sheet.getRange(rangeAddress(matrix.length, matrix[0].length)).values = matrix;
}

writeSheet("品牌命中情况", [
  ["来源", "请求品牌", "中文品牌", "英文品牌", "匹配源品牌字段", "截图数量", "提取数量", "差异", "状态"],
  ...countRows,
]);
writeSheet("品牌汇总", [
  ["中文品牌", "英文品牌", "总数", "ATX", "SFX", "SFX-L", "全模组", "半模组", "非模组", "功率W"],
  ...summaryRows,
]);
writeSheet("全部型号", [columns, ...rows.map(rowToArray)]);

for (const brand of selectedBrands) {
  const brandRows = brandGroups.get(brand.en) || [];
  if (!brandRows.length) continue;
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
      matchedBrands: brandGroups.size,
      skippedBrands: countRows.filter((row) => row[6] === 0).map((row) => [row[2], row[3]]),
      countRows,
      summaryRows,
    },
    null,
    2,
  ),
);
