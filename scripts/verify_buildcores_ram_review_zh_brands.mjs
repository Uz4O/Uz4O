import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const outputXlsx =
  "/Users/may/Documents/AI装机/outputs/buildcores_ram_review/buildcores_ram_ddr4_ddr5_by_brand_zh.xlsx";

const input = await FileBlob.load(outputXlsx);
const workbook = await SpreadsheetFile.importXlsx(input);

const mapping = await workbook.inspect({
  kind: "table",
  range: "品牌映射!A1:E48",
  include: "values",
  tableMaxRows: 48,
  tableMaxCols: 5,
  summary: "brand translation mapping",
});

const summary = await workbook.inspect({
  kind: "table",
  range: "品牌汇总!A1:H16",
  include: "values",
  tableMaxRows: 16,
  tableMaxCols: 8,
  summary: "translated brand summary",
});

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});

console.log("MAPPING_PREVIEW");
console.log(mapping.ndjson);
console.log("SUMMARY_PREVIEW");
console.log(summary.ndjson);
console.log("ERROR_SCAN");
console.log(errors.ndjson);
