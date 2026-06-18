import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const outputXlsx =
  "/Users/may/Documents/AI装机/outputs/buildcores_ram_review/buildcores_ram_ddr4_ddr5_by_brand_zh_filtered.xlsx";

const input = await FileBlob.load(outputXlsx);
const workbook = await SpreadsheetFile.importXlsx(input);

const deletion = await workbook.inspect({
  kind: "table",
  range: "删除品牌清单!A1:G24",
  include: "values",
  tableMaxRows: 24,
  tableMaxCols: 7,
  summary: "deleted brand summary",
});

const summary = await workbook.inspect({
  kind: "table",
  range: "保留品牌汇总!A1:H20",
  include: "values",
  tableMaxRows: 20,
  tableMaxCols: 8,
  summary: "kept brand summary",
});

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});

console.log("DELETION_SUMMARY");
console.log(deletion.ndjson);
console.log("KEPT_SUMMARY");
console.log(summary.ndjson);
console.log("ERROR_SCAN");
console.log(errors.ndjson);
