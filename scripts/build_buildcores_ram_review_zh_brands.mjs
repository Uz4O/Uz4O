import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const inputCsv =
  "/Users/may/Documents/AI装机/outputs/buildcores_ram_review/buildcores_ram_ddr4_ddr5_by_brand.csv";
const outputDir = "/Users/may/Documents/AI装机/outputs/buildcores_ram_review";
const outputXlsx = path.join(
  outputDir,
  "buildcores_ram_ddr4_ddr5_by_brand_zh.xlsx",
);
const outputCsv = path.join(
  outputDir,
  "buildcores_ram_ddr4_ddr5_by_brand_zh.csv",
);
const outputMarkdown = path.join(
  outputDir,
  "buildcores_ram_ddr4_ddr5_by_brand_zh.md",
);

const brandMap = {
  Acer: ["宏碁", "官方中文名", "https://www.acer.com/corporate/zh", ""],
  ADATA: ["威刚", "官方中文名", "https://www.adata.com.cn/", ""],
  Addlink: [
    "杰新科技",
    "公司主体中文名",
    "https://tw.linkedin.com/company/addlink-technology-corp.",
    "addlink 为品牌名；中文资料多对应公司主体“杰新科技”。",
  ],
  AMD: ["超威半导体", "常用/百科中文名", "https://zh.wikipedia.org/wiki/AMD", ""],
  Apacer: ["宇瞻", "官方中文名", "https://www.apacer.com/zh-CN", ""],
  Avexir: [
    "宇帷",
    "常用中文名",
    "https://tw.news.yahoo.com/avexir%E5%AE%87%E5%B8%B7-s100%E7%B3%BB%E5%88%97%E8%A8%98%E6%86%B6%E9%AB%94%E5%90%B8%E7%9D%9B-215007232--finance.html",
    "",
  ],
  Ballistix: [
    "铂胜",
    "官方新闻/常用中文名",
    "https://cn.chinadaily.com.cn/a/202009/11/WS5f5aed0da31009ff9fddfa43.html",
    "Crucial 旗下旧游戏内存品牌线。",
  ],
  Biwin: ["佰维", "官方中文名", "https://cn.biwintech.com/", ""],
  Corsair: ["美商海盗船", "官方中文名", "https://www.corsair.com/ww/zh/s/about", ""],
  Crucial: [
    "英睿达",
    "常用中文名",
    "https://www.pceva.com.cn/topic/crucialssd/index-2_1.html",
    "",
  ],
  EVGA: ["艾维克", "常用中文名", "https://zh.wikipedia.org/wiki/%E8%89%BE%E7%B6%AD%E5%85%8B", ""],
  "G.SKILL": ["芝奇", "官方中文名", "https://www.gskill.com/tw/?h=1", ""],
  GeIL: ["金邦", "官方中文名", "https://www.geilmemory.com/zh-cn/brand_story", ""],
  GIGABYTE: ["技嘉", "官方中文名", "https://www.gigabyte.com/tw", ""],
  Gigastone: ["立达国际", "公司主体中文名", "https://tw.gigastone.com/about", ""],
  Gloway: ["光威", "官方中文名", "https://www.gloway.com/", ""],
  GOODRAM: [
    "固德兰",
    "音译兜底",
    "https://www.goodram.com/en/brand/",
    "未找到可靠官方中文品牌名；按发音音译。",
  ],
  HP: ["惠普", "官方中文名", "https://support.hp.com/cn-zh", ""],
  HyperX: [
    "极度未知",
    "官方/常用中文名",
    "https://www.zfrontier.com/app/flow/2RXnpMGng7bV",
    "旧内存产品线也常见“骇客神条”叫法。",
  ],
  KingBank: ["金百达", "官方中文名", "https://www.kingbank.com/cn/", ""],
  KINGBANK: ["金百达", "官方中文名", "https://www.kingbank.com/cn/", ""],
  Kingston: ["金士顿", "官方中文名", "https://www.kingston.com/cn", ""],
  Klevv: ["科赋", "官方中文名", "https://www.klevv.com/kcn/main", ""],
  Lenovo: ["联想", "官方中文名", "https://www.lenovo.com.cn/", ""],
  Lexar: ["雷克沙", "官方中文名", "https://www.lexar.com/zh-hans/", ""],
  Micron: ["美光", "官方中文名", "https://www.micron.cn/", ""],
  Mushkin: [
    "穆什金",
    "音译兜底",
    "https://mushkin.com/",
    "未找到可靠官方中文品牌名；按发音音译。",
  ],
  MUSHKIN: [
    "穆什金",
    "音译兜底",
    "https://mushkin.com/",
    "未找到可靠官方中文品牌名；按发音音译。",
  ],
  "Neo Forza": ["凌航", "公司主体/常用中文名", "https://www.neoforza.com/about_en_1.php", ""],
  Netac: ["朗科", "官方中文名", "https://www.netac.com.cn/", ""],
  OLOy: [
    "奥洛依",
    "常用中文名",
    "https://zhongce.sina.cn/article/view/184795?vt=4",
    "未找到官方中文页，采用中文评测/渠道常用名。",
  ],
  Patriot: ["美商博帝", "官方中文名", "https://www.patriotmemory.com/zh-tw", ""],
  PNY: ["必恩威", "常用中文名", "https://zh.wikipedia.org/wiki/%E5%BF%85%E6%81%A9%E5%A8%81%E7%A7%91%E6%8A%80", ""],
  PROXMEM: [
    "博德斯曼",
    "常用中文名",
    "https://www.51cto.com/article/743095.html",
    "未找到官方中文页，采用中文科技媒体常用名。",
  ],
  Samsung: ["三星", "官方中文名", "https://www.samsung.com.cn/about-us/company-info/", ""],
  "Silicon Power": ["广颖电通", "官方中文名", "https://www.silicon-power.com/tw/", ""],
  "SK Hynix": ["SK海力士", "官方/常用中文名", "https://news.skhynix.com.cn/", ""],
  Supermicro: [
    "美超微",
    "常用中文名",
    "https://zh.wikipedia.org/zh-hans/%E7%BE%8E%E8%B6%85%E5%BE%AE%E9%9B%BB%E8%85%A6",
    "官方中文站保留 Supermicro；为避免与 AMD 混淆，采用“美超微”。",
  ],
  TEAMGROUP: ["十铨", "官方中文名", "https://www.teamgroupinc.com/cn/", ""],
  Thermaltake: ["曜越", "官方中文名", "https://tw.thermaltake.com/", ""],
  Timetec: [
    "泰美特",
    "音译兜底",
    "https://www.linkedin.com/company/timetec",
    "未找到可靠官方中文品牌名；按发音音译。",
  ],
  UNKNOWN: ["未知", "字段占位", "", "源数据品牌缺失。"],
  "v-color": ["全何科技", "常用/主体中文名", "https://www.zenitron.com.tw/tw/product/brand/v-color", ""],
  VisionTek: [
    "维信泰克",
    "音译兜底",
    "https://visiontek.com/pages/about-visiontek",
    "未找到可靠官方中文品牌名；按发音音译。",
  ],
};

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

    if (ch === '"') {
      quoted = true;
    } else if (ch === ",") {
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

const rawRows = parseCsv(await fs.readFile(inputCsv, "utf8"));
const headers = rawRows[0];
const brandIndex = headers.indexOf("品牌");
if (brandIndex < 0) throw new Error("CSV is missing 品牌 column.");

const zhHeaders = [
  headers[0],
  "品牌中文名",
  ...headers.slice(1),
  "中文名依据",
  "中文名来源链接",
  "中文名备注",
];

const rows = rawRows.slice(1).filter((row) => row.length > 1).map((row) => {
  const brand = row[brandIndex];
  const mapping = brandMap[brand] || [
    brand,
    "未映射",
    "",
    "未在翻译映射表中找到该品牌。",
  ];
  return [
    row[0],
    mapping[0],
    ...row.slice(1),
    mapping[1],
    mapping[2],
    mapping[3],
  ];
});

const brandGroups = new Map();
for (const row of rows) {
  const brand = row[2];
  if (!brandGroups.has(brand)) brandGroups.set(brand, []);
  brandGroups.get(brand).push(row);
}

const summaryRows = [...brandGroups.entries()]
  .map(([brand, brandRows]) => {
    const mapping = brandMap[brand] || ["", "未映射", "", ""];
    return [
      brand,
      mapping[0],
      brandRows.length,
      brandRows.filter((row) => row[3] === "DDR4").length,
      brandRows.filter((row) => row[3] === "DDR5").length,
      mapping[1],
      mapping[2],
      mapping[3],
    ];
  })
  .sort((a, b) => b[2] - a[2] || a[1].localeCompare(b[1], "zh-Hans-CN"));

const mappingRows = Object.entries(brandMap)
  .sort((a, b) => a[0].localeCompare(b[0], "zh-Hans-CN", { sensitivity: "base" }))
  .map(([brand, mapping]) => [brand, ...mapping]);

await fs.writeFile(
  outputCsv,
  [zhHeaders.map(csvEscape).join(","), ...rows.map((row) => row.map(csvEscape).join(","))].join("\n") + "\n",
  "utf8",
);

const md = [];
md.push("# BuildCores DDR4/DDR5 内存型号中文品牌审核清单");
md.push("");
md.push(`总数：${rows.length} 条，品牌：${brandGroups.size} 个`);
md.push("");
md.push("## 品牌映射");
md.push("");
md.push("| 英文品牌 | 中文品牌 | 依据 | 备注 |");
md.push("|---|---|---|---|");
for (const [brand, zh, basis, , note] of mappingRows) {
  md.push(`| ${brand} | ${zh} | ${basis} | ${note || ""} |`);
}
md.push("");
md.push("## 品牌汇总");
md.push("");
for (const [brand, zh, total, ddr4, ddr5, basis] of summaryRows) {
  md.push(`- ${zh}（${brand}）: ${total} 条（DDR4 ${ddr4} / DDR5 ${ddr5}，${basis}）`);
}
await fs.writeFile(outputMarkdown, md.join("\n") + "\n", "utf8");

const workbook = Workbook.create();
const usedSheetNames = new Set();

function writeSheet(sheetName, matrix) {
  const sheet = workbook.worksheets.add(safeSheetName(sheetName, usedSheetNames));
  sheet.getRange(rangeAddress(matrix.length, matrix[0].length)).values = matrix;
}

writeSheet("品牌映射", [
  ["英文品牌", "中文品牌", "依据", "来源链接", "备注"],
  ...mappingRows,
]);
writeSheet("品牌汇总", [
  ["英文品牌", "中文品牌", "总数", "DDR4", "DDR5", "依据", "来源链接", "备注"],
  ...summaryRows,
]);
writeSheet("全部型号", [zhHeaders, ...rows]);

for (const [brand, brandRows] of [...brandGroups.entries()].sort((a, b) =>
  (brandMap[a[0]]?.[0] || a[0]).localeCompare(brandMap[b[0]]?.[0] || b[0], "zh-Hans-CN", {
    sensitivity: "base",
  }),
)) {
  const zh = brandMap[brand]?.[0] || brand;
  writeSheet(`${zh}-${brand}`, [zhHeaders, ...brandRows]);
}

const exported = await SpreadsheetFile.exportXlsx(workbook);
await exported.save(outputXlsx);

console.log(
  JSON.stringify(
    {
      outputXlsx,
      outputCsv,
      outputMarkdown,
      rows: rows.length,
      brands: brandGroups.size,
      basisCounts: rows.reduce((acc, row) => {
        acc[row.at(-3)] = (acc[row.at(-3)] || 0) + 1;
        return acc;
      }, {}),
    },
    null,
    2,
  ),
);
