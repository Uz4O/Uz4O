import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';

const exec = promisify(execFile);
const root = process.cwd();
const tmpAssets = path.join(root, 'tmp', 'figma-assets');
const out = path.join(root, 'output', 'UzBox-首页-Figma.svg');

await mkdir(tmpAssets, { recursive: true });

const sources = {
  hero: 'May/May/Assets.xcassets/HomeGPUHeroCard.imageset/home-gpu-hero-card.png',
  style1: 'May/May/Assets.xcassets/StyleLianLiVisionCompactBlack.imageset/vision-compact-black.heic',
  style2: 'May/May/Assets.xcassets/StyleROGGR701Black.imageset/rog-gr701-black.heic',
  style3: 'May/May/Assets.xcassets/StyleUnknownPlayerPhantomWingBlack.imageset/phantom-wing-black.heic',
};

const pngs = {};
for (const [name, source] of Object.entries(sources)) {
  const destination = path.join(tmpAssets, `${name}.png`);
  if (source.endsWith('.heic')) await exec('sips', ['-s', 'format', 'png', path.join(root, source), '--out', destination]);
  else await writeFile(destination, await readFile(path.join(root, source)));
  pngs[name] = `data:image/png;base64,${(await readFile(destination)).toString('base64')}`;
}

const esc = (value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const text = (id, x, y, value, size, weight = 400, fill = '#101010', extra = '') =>
  `<text id="${id}" x="${x}" y="${y}" font-family="PingFang SC, SF Pro Display, Helvetica Neue, sans-serif" font-size="${size}px" font-weight="${weight}" fill="${fill}" ${extra}>${esc(value)}</text>`;

const check = (cx, cy) => `<g id="check-${cy}"><circle cx="${cx}" cy="${cy}" r="5.5" fill="none" stroke="#8D9293" stroke-width="1.4"/><path d="M${cx - 2.6} ${cy}l1.8 1.9 3.4-4" fill="none" stroke="#8D9293" stroke-width="1.35" stroke-linecap="round" stroke-linejoin="round"/></g>`;
const iconToolbar = `<g id="icon-toolbar" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M31 471l9 9m-4-13l5 5m-9-2l-4 4 10 10 4-4m-3-13l6-6a6 6 0 018 8l-6 6m-1-2l5 5"/><path d="M22 482l-4 4 6 6 4-4"/></g>`;
const iconGamepad = `<g id="icon-gamepad" fill="none" stroke="#111" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M143 474c-2-5 2-9 7-9h15c5 0 9 4 11 9l2 7c1 5-2 8-6 8-3 0-5-3-7-6h-15c-2 3-4 6-7 6-4 0-7-3-6-8z"/><path d="M151 470v8m-4-4h8m14-2h.1m0 6h.1"/></g>`;
const iconShield = `<g id="icon-shield" fill="none" stroke="#111" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M263 466l9 3v7c0 6-4 10-9 12-5-2-9-6-9-12v-7z"/><path d="M258 476l3 3 6-7"/></g>`;
const iconArrow = `<g id="icon-arrow" fill="none" stroke="#111" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M365 482l14-14m-11 0h11v11"/></g>`;

const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="440" height="956" viewBox="0 0 440 956">
  <title>UzBox 首页 · iPhone 17 Pro Max</title>
  <desc>从 SwiftUI HomeView 还原的单屏首页，导入 Figma 后可按分组编辑文本、形状和图片。</desc>
  <defs>
    <filter id="button-shadow" x="-30%" y="-40%" width="160%" height="200%"><feGaussianBlur in="SourceAlpha" stdDeviation="5"/><feOffset dy="4"/><feComponentTransfer><feFuncA type="linear" slope=".28"/></feComponentTransfer><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
    <filter id="nav-shadow" x="-20%" y="-30%" width="140%" height="180%"><feGaussianBlur in="SourceAlpha" stdDeviation="8"/><feOffset dy="3"/><feComponentTransfer><feFuncA type="linear" slope=".14"/></feComponentTransfer><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
    <linearGradient id="nav-glass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".93"/><stop offset="1" stop-color="#FFFFFF" stop-opacity=".80"/></linearGradient>
  </defs>
  <g id="Screen" data-name="UzBox 首页" shape-rendering="geometricPrecision">
    <rect id="Background" width="440" height="956" fill="#F7F9F9"/>

    <g id="Status Bar" data-name="状态栏">
      ${text('Status Time', 42, 40, '06:42', 20, 650, '#050505', 'letter-spacing=".2px"')}
      <rect id="Dynamic Island" x="156" y="10" width="126" height="40" rx="22" fill="#000000"/>
      <g id="Signal" fill="#C9CDCD"><circle cx="315" cy="34" r="2.3"/><circle cx="324" cy="34" r="2.3"/><circle cx="333" cy="34" r="2.3"/><circle cx="342" cy="34" r="2.3"/></g>
      <path id="WiFi" d="M356 29c8-8 20-8 28 0M360 34c6-6 14-6 20 0M366 39c2-2 6-2 8 0" fill="none" stroke="#050505" stroke-width="2.4" stroke-linecap="round"/>
      <rect id="Battery" x="396" y="27" width="27" height="14" rx="4" fill="none" stroke="#858989" stroke-width="1.5"/><rect x="399" y="30" width="21" height="8" rx="2.5" fill="#050505"/><rect x="424" y="31" width="2" height="6" rx="1" fill="#858989"/>
    </g>

    <g id="Header" data-name="顶部品牌">
      ${text('Wordmark', 21, 91, 'UzBox', 28, 800, '#050505', 'letter-spacing="-.8px"')}
    </g>

    <g id="Hero" data-name="当前功能 · AI 一键装机">
      ${text('Hero Eyebrow', 38, 157, '当前功能', 13, 500, '#858989')}
      ${text('Hero Title', 38, 207, 'AI 一键装机', 34, 800, '#050505', 'letter-spacing="-.9px"')}
      ${text('Hero Subtitle', 38, 242, '智能推荐装机方案', 16, 550, '#5E6263', 'letter-spacing="2px"')}
      ${check(45, 284)}${text('Bullet 1', 61, 289, '智能推荐配置', 14, 450, '#858989')}
      ${check(45, 310)}${text('Bullet 2', 61, 315, '自动检测兼容性', 14, 450, '#858989')}
      ${check(45, 336)}${text('Bullet 3', 61, 341, '优化预算方案', 14, 450, '#858989')}
      <g id="Hero Image" data-name="主视觉图片"><image x="253" y="197" width="165" height="165" preserveAspectRatio="xMidYMid meet" href="${pngs.hero}"/></g>
      <g id="Primary CTA" data-name="开始装机按钮" filter="url(#button-shadow)"><rect x="38" y="368" width="136" height="44" rx="23" fill="#000000"/><rect x="38" y="371" width="136" height="41" rx="22" fill="#000000"/><path d="M145 390h14m-6-6l6 6-6 6" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>${text('CTA Label', 56, 396, '开始装机', 15, 700, '#FFFFFF')}</g>
    </g>

    <g id="Feature Selector" data-name="功能切换">
      <g id="Selector AI"><rect x="25" y="456" width="50" height="50" rx="16" fill="#000000" filter="url(#button-shadow)"/>${iconToolbar}</g>
      <g id="Selector Performance"><rect x="135" y="456" width="50" height="50" rx="16" fill="#FFFFFF" fill-opacity=".60"/>${iconGamepad}</g>
      <g id="Selector Review"><rect x="245" y="456" width="50" height="50" rx="16" fill="#FFFFFF" fill-opacity=".60"/>${iconShield}</g>
      <g id="Selector Upgrade"><rect x="355" y="456" width="50" height="50" rx="16" fill="#FFFFFF" fill-opacity=".60"/>${iconArrow}</g>
    </g>

    <g id="Style Section" data-name="精选装机风格">
      ${text('Style Heading', 17, 557, '精选装机风格', 19, 800, '#050505', 'letter-spacing="-.4px"')}
      ${text('Style Subheading', 17, 580, '找到你喜欢的主机外观与氛围', 13, 400, '#858989')}
      <g id="Style Row 1" data-name="联立 VISION COMPACT">
        ${text('Style 1 Title', 17, 642, '联立 VISION COMPACT', 18, 750, '#050505', 'letter-spacing="-.2px"')}
        ${text('Style 1 Price', 17, 668, '为颜值花费约 ¥2,734 起', 13, 600, '#4F5455')}
        ${text('Style 1 Action', 17, 690, '按这个风格装机  →', 12, 500, '#8C989E')}
        <image id="Style 1 Image" x="304" y="605" width="118" height="103" preserveAspectRatio="xMidYMid meet" href="${pngs.style1}"/>
        <line x1="17" y1="722" x2="423" y2="722" stroke="#DDE1E1" stroke-width="1"/>
      </g>
      <g id="Style Row 2" data-name="ROG 创世神 701">
        ${text('Style 2 Title', 17, 758, 'ROG 创世神 701', 18, 750, '#050505', 'letter-spacing="-.1px"')}
        ${text('Style 2 Price', 17, 784, '为颜值花费约 ¥3,476 起', 13, 600, '#4F5455')}
        ${text('Style 2 Action', 17, 806, '按这个风格装机  →', 12, 500, '#8C989E')}
        <image id="Style 2 Image" x="300" y="731" width="124" height="112" preserveAspectRatio="xMidYMid meet" href="${pngs.style2}"/>
        <line x1="17" y1="845" x2="423" y2="845" stroke="#DDE1E1" stroke-width="1"/>
      </g>
      <g id="Style Row 3" data-name="未知玩家 幻翼">
        ${text('Style 3 Title', 17, 881, '未知玩家 幻翼', 18, 750, '#050505')}
        ${text('Style 3 Price', 17, 907, '为颜值花费约 ¥2,980 起', 13, 600, '#4F5455')}
        <image id="Style 3 Image" x="303" y="850" width="118" height="110" preserveAspectRatio="xMidYMid meet" href="${pngs.style3}"/>
      </g>
    </g>

    <g id="Bottom Navigation" data-name="底部导航" filter="url(#nav-shadow)">
      <rect x="20" y="881" width="400" height="62" rx="31" fill="url(#nav-glass)" stroke="#FFFFFF" stroke-width="1.2"/>
      <rect id="Selected Tab" x="27" y="887" width="100" height="50" rx="25" fill="#F1F3F3" fill-opacity=".90"/>
      <g id="Home Icon" fill="#121616"><path d="M57 914l13-11 13 11v14H73v-8h-6v8H57z"/><path d="M54 914l16-14 16 14-2 2-14-12-14 12z"/></g>
      <g id="Palette Icon" fill="#121616"><path d="M177 906c-9 0-16 7-16 15s7 14 15 14h4c3 0 4-3 2-5l-2-2c-2-2-.5-5 2-5h4c4 0 7-3 7-7 0-6-7-10-16-10zm-8 11a2.4 2.4 0 110-4.8 2.4 2.4 0 010 4.8zm8-5a2.4 2.4 0 110-4.8 2.4 2.4 0 010 4.8zm8 6a2.4 2.4 0 110-4.8 2.4 2.4 0 010 4.8z"/></g>
      <g id="Briefcase Icon" fill="#121616"><rect x="239" y="910" width="32" height="20" rx="4"/><path d="M247 909v-4h16v4h-3v-2h-10v2zM239 918h32v5h-32z"/></g>
      <g id="Profile Icon" fill="#121616"><circle cx="358" cy="908" r="7"/><path d="M344 931c1-9 6-13 14-13s13 4 14 13z"/></g>
    </g>
  </g>
</svg>`;

await writeFile(out, svg, 'utf8');
console.log(out);
