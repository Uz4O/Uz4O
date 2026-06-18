import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const outputXlsx =
  "/Users/may/Documents/AI装机/outputs/buildcores_psu_review/buildcores_psu_selected_brands.xlsx";

const input = await FileBlob.load(outputXlsx);
const workbook = await SpreadsheetFile.importXlsx(input);

const hits = await workbook.inspect({
  kind: "table",
  range: "品牌命中情况!A1:I13",
  include: "values",
  tableMaxRows: 13,
  tableMaxCols: 9,
  summary: "brand hit summary",
});

const summary = await workbook.inspect({
  kind: "table",
  range: "品牌汇总!A1:J11",
  include: "values",
  tableMaxRows: 11,
  tableMaxCols: 10,
  summary: "brand summary",
});

const preview = await workbook.inspect({
  kind: "table",
  range: "全部型号!A1:AB20",
  include: "values",
  tableMaxRows: 20,
  tableMaxCols: 28,
  summary: "all psu models preview",
});

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 300 },
  summary: "final formula error scan",
});

console.log("BRAND_HITS");
console.log(hits.ndjson);
console.log("SUMMARY");
console.log(summary.ndjson);
console.log("PREVIEW");
console.log(preview.ndjson);
console.log("ERROR_SCAN");
console.log(errors.ndjson);
