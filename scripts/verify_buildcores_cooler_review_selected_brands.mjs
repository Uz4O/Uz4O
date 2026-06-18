import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const outputXlsx =
  "/Users/may/Documents/AI装机/outputs/buildcores_cooler_review/buildcores_cpu_coolers_selected_brands.xlsx";

const input = await FileBlob.load(outputXlsx);
const workbook = await SpreadsheetFile.importXlsx(input);

const counts = await workbook.inspect({
  kind: "table",
  range: "数量对照!A1:F14",
  include: "values",
  tableMaxRows: 14,
  tableMaxCols: 6,
  summary: "screenshot count comparison",
});

const summary = await workbook.inspect({
  kind: "table",
  range: "品牌汇总!A1:G14",
  include: "values",
  tableMaxRows: 14,
  tableMaxCols: 7,
  summary: "selected brand summary",
});

const preview = await workbook.inspect({
  kind: "table",
  range: "全部型号!A1:W20",
  include: "values",
  tableMaxRows: 20,
  tableMaxCols: 23,
  summary: "all cooler models preview",
});

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});

console.log("COUNT_COMPARISON");
console.log(counts.ndjson);
console.log("SUMMARY");
console.log(summary.ndjson);
console.log("PREVIEW");
console.log(preview.ndjson);
console.log("ERROR_SCAN");
console.log(errors.ndjson);
