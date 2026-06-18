import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const outputXlsx =
  "/Users/may/Documents/AI装机/outputs/buildcores_ram_review/buildcores_ram_ddr4_ddr5_by_brand.xlsx";

const input = await FileBlob.load(outputXlsx);
const workbook = await SpreadsheetFile.importXlsx(input);

const summary = await workbook.inspect({
  kind: "table",
  range: "品牌汇总!A1:D16",
  include: "values",
  tableMaxRows: 16,
  tableMaxCols: 4,
  summary: "brand summary preview",
});

const allRows = await workbook.inspect({
  kind: "table",
  range: "全部型号!A1:W20",
  include: "values",
  tableMaxRows: 20,
  tableMaxCols: 23,
  summary: "all models preview",
});

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});

console.log("SUMMARY_PREVIEW");
console.log(summary.ndjson);
console.log("ALL_MODELS_PREVIEW");
console.log(allRows.ndjson);
console.log("ERROR_SCAN");
console.log(errors.ndjson);
