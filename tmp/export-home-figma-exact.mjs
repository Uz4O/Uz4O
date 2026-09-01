import { readFile, writeFile } from 'node:fs/promises';

const root = process.cwd();
const screenshot = await readFile(`${root}/output/UzBox-首页-当前实现.png`);
const vector = await readFile(`${root}/output/UzBox-首页-Figma.svg`, 'utf8');
const screenshotData = `data:image/png;base64,${screenshot.toString('base64')}`;
const defs = vector.match(/<defs>[\s\S]*?<\/defs>/)?.[0] ?? '';
const screen = vector.match(/<g id="Screen"[\s\S]*?<\/g>\s*<\/svg>/)?.[0]?.replace(/<\/svg>\s*$/, '') ?? '';
const hidden = screen.replace('<g id="Screen"', '<g id="Editable reconstruction (hidden)" opacity="0"');

const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="440" height="956" viewBox="0 0 440 956">
  <title>UzBox 首页 · Figma 精确参考</title>
  <desc>基于 iPhone 17 Pro Max 模拟器当前 HomeView 截图的 1:1 画板。截图作为视觉基准；隐藏的重建层包含可编辑文本、形状和图片。</desc>
  ${defs}
  <g id="Figma page · UzBox Home" data-name="UzBox 首页">
    <image id="Reference screenshot — exact" data-name="截图基准（锁定视觉）" x="0" y="0" width="440" height="956" preserveAspectRatio="none" href="${screenshotData}"/>
    <rect id="Status time mask" x="38" y="15" width="78" height="32" fill="#F7F9F9"/>
    <text id="Status time (editable)" x="42" y="40" font-family="SF Pro Display, Helvetica Neue, sans-serif" font-size="20px" font-weight="650" fill="#050505">06:42</text>
    ${hidden}
  </g>
</svg>`;

await writeFile(`${root}/output/UzBox-首页-Figma-精确版.svg`, svg);
console.log(`${root}/output/UzBox-首页-Figma-精确版.svg`);
