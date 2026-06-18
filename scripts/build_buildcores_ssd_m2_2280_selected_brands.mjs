import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const sourceDir = "/tmp/buildcores-open-db/open-db/Storage";
const outputDir = "/Users/may/Documents/AI装机/outputs/buildcores_ssd_review";
const outputBase = "buildcores_ssd_m2_2280_selected_brands";
const outputXlsx = path.join(outputDir, `${outputBase}.xlsx`);
const outputCsv = path.join(outputDir, `${outputBase}.csv`);
const outputMarkdown = path.join(outputDir, `${outputBase}.md`);
const repoBaseUrl =
  "https://github.com/buildcores/buildcores-open-db/blob/main/open-db/Storage";
const productBaseUrl = "https://buildcores.com/products/Storage";

const selectedBrands = [
  { requestZh: "三星", zh: "三星", en: "Samsung", aliases: ["Samsung", "SAMSUNG"] },
  { requestZh: "西部数据", zh: "西部数据", en: "Western Digital", aliases: ["Western Digital"] },
  { requestZh: "铠侠", zh: "铠侠", en: "KIOXIA", aliases: ["KIOXIA"] },
  { requestZh: "致态", zh: "致态", en: "ZHITAI", aliases: ["ZHITAI", "Zhitai"] },
  { requestZh: "英睿达", zh: "英睿达", en: "Crucial", aliases: ["Crucial"] },
  { requestZh: "海力士", zh: "SK海力士", en: "SK Hynix", aliases: ["SK Hynix", "SK hynix"] },
  { requestZh: "金士顿", zh: "金士顿", en: "Kingston", aliases: ["Kingston", "Kingston Technology", "Kingston Technology Corp."] },
  { requestZh: "宏碁", zh: "宏碁", en: "Acer", aliases: ["Acer"] },
  { requestZh: "佰维", zh: "佰维", en: "Biwin", aliases: ["Biwin"] },
  { requestZh: "威刚", zh: "威刚", en: "ADATA", aliases: ["ADATA"] },
  { requestZh: "闪迪", zh: "闪迪", en: "SanDisk", aliases: ["SanDisk"] },
  { requestZh: "希捷", zh: "希捷", en: "Seagate", aliases: ["Seagate"] },
  { requestZh: "雷克沙", zh: "雷克沙", en: "Lexar", aliases: ["Lexar"] },
  { requestZh: "阿斯加特", zh: "阿斯加特", en: "Asgard", aliases: ["Asgard"] },
  { requestZh: "美商海盗船", zh: "美商海盗船", en: "Corsair", aliases: ["Corsair"] },
  { requestZh: "海康威视", zh: "海康威视", en: "HIKVISION", aliases: ["HIKVISION", "Hikvision"] },
  { requestZh: "光威", zh: "光威", en: "Gloway", aliases: ["Gloway"] },
  { requestZh: "金百达", zh: "金百达", en: "KingBank", aliases: ["KingBank", "KINGBANK"] },
  { requestZh: "长城", zh: "长城", en: "Great Wall", aliases: ["Great Wall"] },
  { requestZh: "技嘉", zh: "技嘉", en: "Gigabyte", aliases: ["Gigabyte", "GIGABYTE"] },
  { requestZh: "微星", zh: "微星", en: "MSI", aliases: ["MSI"] },
  { requestZh: "华硕", zh: "华硕", en: "Asus", aliases: ["Asus", "ASUS"] },
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
  "容量GB",
  "形态",
  "接口",
  "NVMe",
  "缓存MB",
  "灯效",
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
const selectedAllStorageCounts = new Map(selectedBrands.map((brand) => [brand.en, 0]));
const selectedM2Counts = new Map(selectedBrands.map((brand) => [brand.en, 0]));

for (const file of files) {
  const fullPath = path.join(sourceDir, file);
  const part = JSON.parse(await fs.readFile(fullPath, "utf8"));
  const metadata = part.metadata || {};
  const sourceBrand = metadata.manufacturer || "UNKNOWN";
  const brand = brandByAlias.get(sourceBrand);
  if (!brand) continue;

  selectedAllStorageCounts.set(brand.en, selectedAllStorageCounts.get(brand.en) + 1);

  if (part.storage_type !== "SSD" || part.form_factor !== "M.2-2280") continue;

  selectedM2Counts.set(brand.en, selectedM2Counts.get(brand.en) + 1);

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
    capacity: part.capacity,
    formFactor: part.form_factor,
    interface: part.interface,
    nvme: part.nvme,
    cache: part.cache,
    lighting: part.lighting || [],
    openDbId,
    productUrl: `${productBaseUrl}/${openDbId}`,
    githubUrl: `${repoBaseUrl}/${file}`,
  });
}

rows.sort((a, b) =>
  a.brand.localeCompare(b.brand, "zh-Hans-CN", { sensitivity: "base" }) ||
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
  row.capacity,
  row.formFactor,
  row.interface,
  row.nvme,
  row.cache,
  row.lighting.join("; "),
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
  const allStorage = selectedAllStorageCounts.get(brand.en) || 0;
  return [
    brand.requestZh,
    brand.zh,
    brand.en,
    brand.aliases.join("; "),
    allStorage,
    extracted,
    extracted ? "已提取" : "未命中 M.2-2280 SSD，已跳过",
  ];
});

const summaryRows = selectedBrands
  .map((brand) => {
    const brandRows = brandGroups.get(brand.en) || [];
    const nvmeCount = brandRows.filter((row) => row.nvme === true).length;
    const sataCount = brandRows.filter((row) => row.interface === "M.2 SATA").length;
    const capacities = [...new Set(brandRows.map((row) => row.capacity).filter((value) => value !== null && value !== undefined))]
      .sort((a, b) => a - b)
      .join("; ");
    return [brand.zh, brand.en, brandRows.length, nvmeCount, sataCount, capacities];
  })
  .filter((row) => row[2] > 0);

await fs.mkdir(outputDir, { recursive: true });

const csvLines = [columns.map(csvEscape).join(",")];
for (const row of rows) csvLines.push(rowToArray(row).map(csvEscape).join(","));
await fs.writeFile(outputCsv, `${csvLines.join("\n")}\n`, "utf8");

const md = [];
md.push("# BuildCores M.2-2280 SSD 型号审核清单（截图品牌）");
md.push("");
md.push("来源：BuildCores OpenDB Storage JSON");
md.push("筛选：storage_type = SSD 且 form_factor = M.2-2280");
md.push(`总数：${rows.length} 条，命中品牌：${brandGroups.size} 个，截图品牌：${selectedBrands.length} 个`);
md.push("");
md.push("## 品牌命中情况");
md.push("");
md.push("| 请求中文名 | 中文品牌 | 英文品牌 | 匹配源品牌字段 | Storage总数 | M.2-2280 SSD提取数 | 状态 |");
md.push("|---|---|---|---|---:|---:|---|");
for (const row of countRows) {
  md.push(`| ${row.map((item) => String(item ?? "").replaceAll("|", "\\|")).join(" | ")} |`);
}
md.push("");
md.push("## 品牌汇总");
md.push("");
for (const [zh, en, total, nvmeCount, sataCount, capacities] of summaryRows) {
  md.push(`- ${zh}（${en}）: ${total} 条（NVMe ${nvmeCount} / M.2 SATA ${sataCount}，容量GB：${capacities}）`);
}
await fs.writeFile(outputMarkdown, `${md.join("\n")}\n`, "utf8");

const workbook = Workbook.create();
const usedSheetNames = new Set();

function writeSheet(sheetName, matrix) {
  const sheet = workbook.worksheets.add(safeSheetName(sheetName, usedSheetNames));
  sheet.getRange(rangeAddress(matrix.length, matrix[0].length)).values = matrix;
}

writeSheet("品牌命中情况", [
  ["请求中文名", "中文品牌", "英文品牌", "匹配源品牌字段", "Storage总数", "M.2-2280 SSD提取数", "状态"],
  ...countRows,
]);
writeSheet("品牌汇总", [
  ["中文品牌", "英文品牌", "总数", "NVMe", "M.2 SATA", "容量GB"],
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
      skippedBrands: countRows.filter((row) => row[5] === 0).map((row) => [row[1], row[2]]),
      countRows,
      summaryRows,
    },
    null,
    2,
  ),
);
