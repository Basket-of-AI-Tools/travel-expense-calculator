param(
    [string]$DataPath = (Join-Path $PSScriptRoot 'travel-data.json'),
    [string]$OutputPath = (Join-Path $PSScriptRoot '旅行花费汇总.html'),
    [switch]$NoOpen
)

Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'Common.ps1')

$data = Read-TravelData -Path $DataPath
Test-TravelData -Data $data

$reportData = [pscustomobject]@{
    settings = [pscustomobject]@{
        tripName = [string]$data.Settings.TripName
        baseCurrency = [string]$data.Settings.BaseCurrency
    }
    categories = @($data.Categories | ForEach-Object {
        [pscustomobject]@{
            id = [string]$_.Id
            name = [string]$_.Name
            color = [string]$_.Color
        }
    })
    expenses = @($data.Expenses | Sort-Object Date, CreatedAt | ForEach-Object {
        [pscustomobject]@{
            id = [string]$_.Id
            date = [string]$_.Date
            item = [string]$_.Item
            categoryId = [string]$_.CategoryId
            originalAmount = [decimal]$_.OriginalAmount
            currency = [string]$_.Currency
            exchangeRate = [decimal]$_.ExchangeRate
            convertedAmount = [decimal]$_.ConvertedAmount
            merchant = [string]$_.Merchant
            notes = [string]$_.Notes
        }
    })
}

$json = $reportData | ConvertTo-Json -Depth 8 -Compress
$json = $json.Replace('&', '\u0026').Replace('<', '\u003c').Replace('>', '\u003e')
$generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$template = @'
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>旅行花费汇总</title>
<style>
:root {
  color-scheme: light;
  --bg: #f3f6fb;
  --card: #fff;
  --ink: #172033;
  --muted: #64748b;
  --line: #e2e8f0;
  --brand: #0f766e;
  --brand-soft: #ccfbf1;
  --danger: #b91c1c;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--ink);
  font-family: "Segoe UI", "Microsoft YaHei UI", "Microsoft YaHei", sans-serif;
}
button, input, select { font: inherit; }
.page { max-width: 1220px; margin: 0 auto; padding: 24px; }
.hero {
  color: white;
  background: linear-gradient(120deg, #115e59, #0f766e 55%, #0891b2);
  border-radius: 18px;
  padding: 26px 28px;
  box-shadow: 0 14px 36px rgba(15, 118, 110, .18);
}
.hero h1 { margin: 0 0 6px; font-size: clamp(25px, 4vw, 36px); }
.hero p { margin: 0; opacity: .84; font-size: 13px; }
.filters, .summary, .charts { display: grid; gap: 14px; }
.filters {
  grid-template-columns: repeat(6, minmax(130px, 1fr));
  margin: 18px 0 14px;
  padding: 16px;
  border-radius: 14px;
  background: var(--card);
  border: 1px solid var(--line);
}
.field label { display: block; font-size: 12px; color: var(--muted); margin-bottom: 6px; }
.field input, .field select {
  width: 100%;
  height: 38px;
  border: 1px solid #cbd5e1;
  border-radius: 8px;
  padding: 0 10px;
  background: white;
  color: var(--ink);
}
.clear-button {
  align-self: end;
  height: 38px;
  border: 0;
  border-radius: 8px;
  padding: 0 14px;
  color: #0f766e;
  background: var(--brand-soft);
  cursor: pointer;
}
.summary { grid-template-columns: repeat(4, 1fr); margin-bottom: 14px; }
.metric, .panel {
  background: var(--card);
  border: 1px solid var(--line);
  border-radius: 14px;
  box-shadow: 0 5px 18px rgba(15, 23, 42, .035);
}
.metric { padding: 17px 18px; min-height: 90px; }
.metric span { display: block; color: var(--muted); font-size: 12px; margin-bottom: 7px; }
.metric strong { display: block; font-size: 22px; word-break: break-word; }
.charts { grid-template-columns: minmax(0, 1.65fr) minmax(320px, .75fr); }
.panel { padding: 18px; overflow: hidden; }
.panel-head { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; margin-bottom: 12px; }
.panel h2 { margin: 0; font-size: 17px; }
.panel-note { color: var(--muted); font-size: 12px; }
.chart-wrap { width: 100%; min-height: 330px; position: relative; }
svg { width: 100%; height: auto; display: block; overflow: visible; }
.axis-label { fill: #64748b; font-size: 11px; }
.grid-line { stroke: #e2e8f0; stroke-width: 1; }
.bar-segment, .pie-segment, .legend-button { cursor: pointer; transition: opacity .15s ease; }
.bar-segment:hover, .pie-segment:hover { opacity: .78; }
.legend { display: flex; flex-wrap: wrap; gap: 8px 12px; margin-top: 10px; }
.legend-button {
  border: 0;
  background: transparent;
  color: #475569;
  padding: 3px 0;
  font-size: 12px;
}
.legend-button::before {
  content: "";
  display: inline-block;
  width: 9px;
  height: 9px;
  margin-right: 6px;
  border-radius: 3px;
  background: var(--legend-color);
}
.legend-button.active { color: var(--brand); font-weight: 700; }
.empty {
  min-height: 260px;
  display: grid;
  place-items: center;
  color: var(--muted);
  text-align: center;
}
.table-panel { margin-top: 14px; padding: 0; }
.table-head { padding: 18px 18px 12px; }
.table-scroll { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; min-width: 960px; }
th, td { padding: 11px 12px; border-top: 1px solid var(--line); text-align: left; vertical-align: top; }
th { color: #475569; background: #f8fafc; font-size: 12px; white-space: nowrap; }
td { font-size: 13px; }
.money { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
.date { white-space: nowrap; }
.category-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  white-space: nowrap;
}
.category-pill::before {
  content: "";
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--category-color);
}
.muted { color: var(--muted); }
.footer { text-align: center; color: var(--muted); font-size: 11px; padding: 18px; }
@media (max-width: 900px) {
  .filters { grid-template-columns: repeat(2, 1fr); }
  .summary { grid-template-columns: repeat(2, 1fr); }
  .charts { grid-template-columns: 1fr; }
}
@media (max-width: 540px) {
  .page { padding: 12px; }
  .filters { grid-template-columns: 1fr; }
  .summary { grid-template-columns: 1fr; }
}
</style>
</head>
<body>
<main class="page">
  <header class="hero">
    <h1 id="tripTitle">旅行花费汇总</h1>
    <p>生成时间：__GENERATED_AT__ · 所有金额按记录时保存的汇率换算</p>
  </header>

  <section class="filters" aria-label="筛选条件">
    <div class="field"><label for="startDate">开始日期</label><input id="startDate" type="date"></div>
    <div class="field"><label for="endDate">结束日期</label><input id="endDate" type="date"></div>
    <div class="field"><label for="categoryFilter">类别</label><select id="categoryFilter"></select></div>
    <div class="field"><label for="currencyFilter">原币币种</label><select id="currencyFilter"></select></div>
    <div class="field"><label for="queryFilter">项目、商家或备注</label><input id="queryFilter" type="search" placeholder="输入关键词"></div>
    <button id="clearFilters" class="clear-button" type="button">清除筛选</button>
  </section>

  <section class="summary">
    <div class="metric"><span>筛选后总花费</span><strong id="totalMetric">—</strong></div>
    <div class="metric"><span>记录数</span><strong id="countMetric">—</strong></div>
    <div class="metric"><span>消费天数</span><strong id="daysMetric">—</strong></div>
    <div class="metric"><span>最高类别</span><strong id="topCategoryMetric">—</strong></div>
  </section>

  <section class="charts">
    <article class="panel">
      <div class="panel-head"><h2>按日期与类别</h2><span class="panel-note">点击色块筛选日期和类别</span></div>
      <div id="barChart" class="chart-wrap"></div>
      <div id="barLegend" class="legend"></div>
    </article>
    <article class="panel">
      <div class="panel-head"><h2>类别占比</h2><span class="panel-note">点击扇区筛选类别</span></div>
      <div id="pieChart" class="chart-wrap"></div>
      <div id="pieLegend" class="legend"></div>
    </article>
  </section>

  <section class="panel table-panel">
    <div class="panel-head table-head"><h2>花费明细</h2><span id="tableCount" class="panel-note"></span></div>
    <div class="table-scroll">
      <table>
        <thead>
          <tr>
            <th>日期</th><th>项目</th><th>类别</th><th>商家/地点</th>
            <th class="money">原币金额</th><th class="money">汇率</th>
            <th class="money">换算金额</th><th>备注</th>
          </tr>
        </thead>
        <tbody id="expenseRows"></tbody>
      </table>
    </div>
  </section>
  <footer class="footer">此页面完全离线运行。筛选只改变当前页面显示，不会修改原始数据。</footer>
</main>

<script>
"use strict";
const DATA = __DATA_JSON__;
const categoryMap = new Map(DATA.categories.map(c => [c.id, c]));
const state = { start: "", end: "", category: "", currency: "", query: "" };
const NS = "http://www.w3.org/2000/svg";

const el = id => document.getElementById(id);
const money = (value, currency = DATA.settings.baseCurrency) =>
  new Intl.NumberFormat("zh-CN", { style: "currency", currency, minimumFractionDigits: 2 }).format(Number(value || 0));
const number = value => new Intl.NumberFormat("zh-CN", { maximumFractionDigits: 6 }).format(Number(value || 0));
const svgNode = (name, attrs = {}) => {
  const node = document.createElementNS(NS, name);
  Object.entries(attrs).forEach(([key, value]) => node.setAttribute(key, value));
  return node;
};
const addOption = (select, value, text) => {
  const option = document.createElement("option");
  option.value = value;
  option.textContent = text;
  select.appendChild(option);
};

document.title = `${DATA.settings.tripName} · 旅行花费汇总`;
el("tripTitle").textContent = `${DATA.settings.tripName} · 旅行花费汇总`;
addOption(el("categoryFilter"), "", "全部类别");
DATA.categories.forEach(c => addOption(el("categoryFilter"), c.id, c.name));
addOption(el("currencyFilter"), "", "全部币种");
[...new Set(DATA.expenses.map(e => e.currency))].sort().forEach(c => addOption(el("currencyFilter"), c, c));

function readFilters() {
  state.start = el("startDate").value;
  state.end = el("endDate").value;
  state.category = el("categoryFilter").value;
  state.currency = el("currencyFilter").value;
  state.query = el("queryFilter").value.trim().toLocaleLowerCase("zh-CN");
}

function filteredExpenses() {
  readFilters();
  return DATA.expenses.filter(e => {
    if (state.start && e.date < state.start) return false;
    if (state.end && e.date > state.end) return false;
    if (state.category && e.categoryId !== state.category) return false;
    if (state.currency && e.currency !== state.currency) return false;
    if (state.query) {
      const category = categoryMap.get(e.categoryId)?.name || "";
      const haystack = `${e.item} ${e.merchant} ${e.notes} ${category}`.toLocaleLowerCase("zh-CN");
      if (!haystack.includes(state.query)) return false;
    }
    return true;
  });
}

function aggregateByCategory(expenses) {
  const values = new Map();
  expenses.forEach(e => values.set(e.categoryId, (values.get(e.categoryId) || 0) + Number(e.convertedAmount)));
  return [...values.entries()]
    .map(([id, value]) => ({ category: categoryMap.get(id) || { id, name: "未知", color: "#64748b" }, value }))
    .sort((a, b) => b.value - a.value);
}

function activateCategory(categoryId) {
  el("categoryFilter").value = state.category === categoryId ? "" : categoryId;
  render();
}

function makeLegend(container, items) {
  container.replaceChildren();
  items.forEach(({ category, value }) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = `legend-button${state.category === category.id ? " active" : ""}`;
    button.style.setProperty("--legend-color", category.color);
    button.textContent = `${category.name} ${money(value)}`;
    button.addEventListener("click", () => activateCategory(category.id));
    container.appendChild(button);
  });
}

function renderSummary(expenses) {
  const total = expenses.reduce((sum, e) => sum + Number(e.convertedAmount), 0);
  const days = new Set(expenses.map(e => e.date)).size;
  const categories = aggregateByCategory(expenses);
  el("totalMetric").textContent = money(total);
  el("countMetric").textContent = String(expenses.length);
  el("daysMetric").textContent = String(days);
  el("topCategoryMetric").textContent = categories.length
    ? `${categories[0].category.name} · ${money(categories[0].value)}`
    : "—";
}

function renderBarChart(expenses) {
  const container = el("barChart");
  container.replaceChildren();
  const legendItems = aggregateByCategory(expenses);
  makeLegend(el("barLegend"), legendItems);
  if (!expenses.length) {
    const empty = document.createElement("div");
    empty.className = "empty";
    empty.textContent = "当前筛选条件下没有花费记录";
    container.appendChild(empty);
    return;
  }

  const dateMap = new Map();
  expenses.forEach(e => {
    if (!dateMap.has(e.date)) dateMap.set(e.date, new Map());
    const categoryValues = dateMap.get(e.date);
    categoryValues.set(e.categoryId, (categoryValues.get(e.categoryId) || 0) + Number(e.convertedAmount));
  });
  const dates = [...dateMap.keys()].sort();
  const totals = dates.map(date => [...dateMap.get(date).values()].reduce((a, b) => a + b, 0));
  const maxTotal = Math.max(...totals, 1);
  const width = Math.max(760, dates.length * 58 + 110);
  const height = 360;
  const margin = { top: 18, right: 20, bottom: 70, left: 72 };
  const plotWidth = width - margin.left - margin.right;
  const plotHeight = height - margin.top - margin.bottom;
  const svg = svgNode("svg", { viewBox: `0 0 ${width} ${height}`, role: "img", "aria-label": "按日期和类别堆叠柱状图" });

  for (let i = 0; i <= 4; i++) {
    const y = margin.top + plotHeight - plotHeight * i / 4;
    const grid = svgNode("line", { x1: margin.left, x2: width - margin.right, y1: y, y2: y, class: "grid-line" });
    svg.appendChild(grid);
    const label = svgNode("text", { x: margin.left - 8, y: y + 4, "text-anchor": "end", class: "axis-label" });
    label.textContent = number(maxTotal * i / 4);
    svg.appendChild(label);
  }

  const band = plotWidth / dates.length;
  const barWidth = Math.min(34, band * .68);
  dates.forEach((date, index) => {
    let currentY = margin.top + plotHeight;
    const entries = [...dateMap.get(date).entries()]
      .map(([categoryId, value]) => ({ category: categoryMap.get(categoryId), value }))
      .sort((a, b) => b.value - a.value);
    entries.forEach(({ category, value }) => {
      const segmentHeight = value / maxTotal * plotHeight;
      currentY -= segmentHeight;
      const rect = svgNode("rect", {
        x: margin.left + band * index + (band - barWidth) / 2,
        y: currentY,
        width: barWidth,
        height: Math.max(segmentHeight, .8),
        rx: 2,
        fill: category?.color || "#64748b",
        class: "bar-segment"
      });
      const title = svgNode("title");
      title.textContent = `${date} · ${category?.name || "未知"}：${money(value)}`;
      rect.appendChild(title);
      rect.addEventListener("click", () => {
        el("startDate").value = date;
        el("endDate").value = date;
        el("categoryFilter").value = category?.id || "";
        render();
      });
      svg.appendChild(rect);
    });
    const label = svgNode("text", {
      x: margin.left + band * index + band / 2,
      y: height - margin.bottom + 18,
      "text-anchor": "end",
      transform: `rotate(-42 ${margin.left + band * index + band / 2} ${height - margin.bottom + 18})`,
      class: "axis-label"
    });
    label.textContent = date;
    svg.appendChild(label);
  });
  container.appendChild(svg);
}

function polar(cx, cy, radius, angle) {
  const radians = (angle - 90) * Math.PI / 180;
  return { x: cx + radius * Math.cos(radians), y: cy + radius * Math.sin(radians) };
}

function arcPath(cx, cy, outerRadius, innerRadius, startAngle, endAngle) {
  const outerStart = polar(cx, cy, outerRadius, endAngle);
  const outerEnd = polar(cx, cy, outerRadius, startAngle);
  const innerStart = polar(cx, cy, innerRadius, startAngle);
  const innerEnd = polar(cx, cy, innerRadius, endAngle);
  const large = endAngle - startAngle <= 180 ? "0" : "1";
  return [
    `M ${outerStart.x} ${outerStart.y}`,
    `A ${outerRadius} ${outerRadius} 0 ${large} 0 ${outerEnd.x} ${outerEnd.y}`,
    `L ${innerStart.x} ${innerStart.y}`,
    `A ${innerRadius} ${innerRadius} 0 ${large} 1 ${innerEnd.x} ${innerEnd.y}`,
    "Z"
  ].join(" ");
}

function renderPieChart(expenses) {
  const container = el("pieChart");
  container.replaceChildren();
  const items = aggregateByCategory(expenses);
  makeLegend(el("pieLegend"), items);
  if (!items.length) {
    const empty = document.createElement("div");
    empty.className = "empty";
    empty.textContent = "暂无类别占比";
    container.appendChild(empty);
    return;
  }
  const total = items.reduce((sum, item) => sum + item.value, 0);
  const svg = svgNode("svg", { viewBox: "0 0 360 330", role: "img", "aria-label": "花费类别扇形图" });
  let angle = 0;
  items.forEach(item => {
    const sweep = item.value / total * 360;
    const safeSweep = items.length === 1 ? 359.999 : sweep;
    const path = svgNode("path", {
      d: arcPath(180, 155, 125, 70, angle, angle + safeSweep),
      fill: item.category.color,
      class: "pie-segment"
    });
    const title = svgNode("title");
    title.textContent = `${item.category.name}：${money(item.value)}（${(item.value / total * 100).toFixed(1)}%）`;
    path.appendChild(title);
    path.addEventListener("click", () => activateCategory(item.category.id));
    svg.appendChild(path);
    angle += sweep;
  });
  const totalLabel = svgNode("text", { x: 180, y: 150, "text-anchor": "middle", class: "axis-label" });
  totalLabel.textContent = "合计";
  totalLabel.setAttribute("style", "font-size:13px");
  svg.appendChild(totalLabel);
  const totalValue = svgNode("text", { x: 180, y: 177, "text-anchor": "middle" });
  totalValue.textContent = money(total);
  totalValue.setAttribute("style", "font-size:17px;font-weight:700;fill:#172033");
  svg.appendChild(totalValue);
  container.appendChild(svg);
}

function renderTable(expenses) {
  const tbody = el("expenseRows");
  tbody.replaceChildren();
  const ordered = [...expenses].sort((a, b) => b.date.localeCompare(a.date) || b.id.localeCompare(a.id));
  if (!ordered.length) {
    const row = document.createElement("tr");
    const cell = document.createElement("td");
    cell.colSpan = 8;
    cell.className = "empty";
    cell.textContent = "当前筛选条件下没有花费记录";
    row.appendChild(cell);
    tbody.appendChild(row);
  } else {
    ordered.forEach(e => {
      const category = categoryMap.get(e.categoryId) || { name: "未知", color: "#64748b" };
      const row = document.createElement("tr");
      const values = [
        { text: e.date, className: "date" },
        { text: e.item },
        { text: category.name, className: "category-pill", style: category.color },
        { text: e.merchant || "—", className: e.merchant ? "" : "muted" },
        { text: money(e.originalAmount, e.currency), className: "money" },
        { text: number(e.exchangeRate), className: "money" },
        { text: money(e.convertedAmount), className: "money" },
        { text: e.notes || "—", className: e.notes ? "" : "muted" }
      ];
      values.forEach(value => {
        const cell = document.createElement("td");
        cell.textContent = value.text;
        if (value.className) cell.className = value.className;
        if (value.style) cell.style.setProperty("--category-color", value.style);
        row.appendChild(cell);
      });
      tbody.appendChild(row);
    });
  }
  el("tableCount").textContent = `显示 ${ordered.length} 条`;
}

function render() {
  const expenses = filteredExpenses();
  renderSummary(expenses);
  renderBarChart(expenses);
  renderPieChart(expenses);
  renderTable(expenses);
}

["startDate", "endDate", "categoryFilter", "currencyFilter"].forEach(id =>
  el(id).addEventListener("change", render)
);
el("queryFilter").addEventListener("input", render);
el("clearFilters").addEventListener("click", () => {
  ["startDate", "endDate", "categoryFilter", "currencyFilter", "queryFilter"].forEach(id => el(id).value = "");
  render();
});
render();
</script>
</body>
</html>
'@

$html = $template.Replace('__DATA_JSON__', $json).Replace('__GENERATED_AT__', $generatedAt)
$parent = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$tempPath = "$OutputPath.$([guid]::NewGuid().ToString('N')).tmp"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
try {
    [System.IO.File]::WriteAllText($tempPath, $html, $utf8NoBom)
    Move-Item -LiteralPath $tempPath -Destination $OutputPath -Force
}
finally {
    Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
}

if (-not $NoOpen) {
    Start-Process -FilePath $OutputPath
}

Write-Output $OutputPath
