Set-StrictMode -Version Latest

function ConvertTo-INRHtmlText {
    <#
    .SYNOPSIS
    HTML-encodes a value for safe interpolation into report markup.
    .DESCRIPTION
    Report inputs originate from CSV fields, some of which come from network
    responses (for example certificate Issuer strings). Encoding them prevents
    a crafted value from injecting markup or script into the generated report.
    .PARAMETER Value
    The value to encode. Null is treated as an empty string.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function ConvertTo-INRStatusEmoji {
    <#
    .SYNOPSIS
    Maps a result value to a traffic-light emoji for the HTML reports.
    .PARAMETER Value
    The raw value to classify.
    .PARAMETER IsHttpStatus
    Treat the value as an HTTP status code (2xx-4xx green, 5xx red).
    .PARAMETER IsSSLInspection
    Treat the value as an SSL-interception flag (inverted: False is good).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $Value,
        [switch]$IsHttpStatus,
        [switch]$IsSSLInspection
    )

    if ($IsHttpStatus) {
        $num = $null
        [void][int]::TryParse([string]$Value, [ref]$num)
        if ($num -ge 200 -and $num -lt 500) { return '🟢' }
        if ($num -ge 500 -and $num -lt 600) { return '🔴' }
        return '🟡'
    }

    $text = [string]$Value
    if ($IsSSLInspection) {
        # Inverted: "False" means no SSL interception was detected, which
        # is the desired outcome.
        if ($text -eq 'False') { return '🟢' }
        if ($text -eq 'True') { return '🔴' }
        return '🟡'
    }
    if ($text -eq 'True') { return '🟢' }
    if ($text -eq 'False') { return '🔴' }
    return '🟡'
}

function New-INRMindMapReport {
    <#
    .SYNOPSIS
    Generates an HTML scan report (endpoint status table) from a ResultList CSV.
    .PARAMETER CsvPath
    Path to the ResultList CSV produced by a scan.
    .PARAMETER OutputHtmlPath
    Destination path for the generated HTML report.
    .PARAMETER SelectedASAs
    The service areas the scan covered, used for the report header.
    .OUTPUTS
    The output HTML path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath,
        [Parameter(Mandatory)]
        [string]$OutputHtmlPath,
        [Parameter(Mandatory)]
        [string[]]$SelectedASAs
    )

    $rows = Import-Csv -LiteralPath $CsvPath
    if (-not $rows -or $rows.Count -eq 0) {
        throw 'Input CSV has no rows.'
    }

    $machineLabel = [System.IO.Path]::GetFileNameWithoutExtension($CsvPath)
    if ($machineLabel -match 'ResultList_\d{8}_\d{6}_(?<name>.+)$') {
        $machineLabel = $matches['name']
    }

    $asaLabel = if ($SelectedASAs -and $SelectedASAs.Count -gt 0) { $SelectedASAs -join ', ' } else { 'Unspecified' }

    $tableRows = $rows | ForEach-Object {
        $dns = ConvertTo-INRStatusEmoji -Value $_.DNSResult
        $tcp = ConvertTo-INRStatusEmoji -Value $_.TCPResult
        $http = ConvertTo-INRStatusEmoji -Value $_.HTTPStatusCode -IsHttpStatus
        $ssl = ConvertTo-INRStatusEmoji -Value $_.SSLTest
        $insp = ConvertTo-INRStatusEmoji -Value $_.SSLInterception -IsSSLInspection
        $idCell = ConvertTo-INRHtmlText $_.id
        $urlCell = ConvertTo-INRHtmlText $_.url
        $portCell = ConvertTo-INRHtmlText $_.Port
        $protocolCell = ConvertTo-INRHtmlText $_.Protocol
        "<tr><td>$idCell</td><td>$urlCell</td><td>$portCell</td><td>$protocolCell</td><td>$dns</td><td>$tcp</td><td>$http</td><td>$ssl</td><td>$insp</td></tr>"
    }

    $machineLabelHtml = ConvertTo-INRHtmlText $machineLabel
    $asaLabelHtml = ConvertTo-INRHtmlText $asaLabel

    $html = @"
<!doctype html>
<html>
<head>
<meta charset='utf-8'>
<title>INR Visual Scan Report</title>
<style>
:root {
  --brand1: #00AEEF;
  --brand2: #0F6CBD;
  --brand3: #38B6A4;
  --bg: #f4fbff;
  --text: #17324d;
}
body { font-family: 'Segoe UI', Tahoma, sans-serif; margin: 0; background: linear-gradient(145deg, var(--bg), #ffffff); color: var(--text); }
header { padding: 20px; background: linear-gradient(120deg, var(--brand2), var(--brand1)); color: white; }
main { display: grid; grid-template-columns: 1fr; gap: 16px; padding: 16px; }
.card { background: white; border-radius: 12px; box-shadow: 0 6px 20px rgba(15,108,189,.14); padding: 16px; }
table { width: 100%; border-collapse: collapse; }
th, td { border-bottom: 1px solid #e6eef6; padding: 8px; text-align: left; }
th { background: #ecf5ff; }
</style>
</head>
<body>
<header>
  <h1>INR Visual Scan Report</h1>
<div>Hostname: ${machineLabelHtml} | ASA: ${asaLabelHtml}</div>
</header>
<main>
  <section class='card'>
    <h2>Endpoint Status Table</h2>
    <table>
      <thead><tr><th>ID</th><th>URL</th><th>Port</th><th>Protocol</th><th>DNS</th><th>TCP</th><th>HTTP</th><th>SSL</th><th>SSL Inspection</th></tr></thead>
      <tbody>
        $($tableRows -join "`n")
      </tbody>
    </table>
  </section>
</main>
</body>
</html>
"@

    $dir = Split-Path -Path $OutputHtmlPath -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $html | Set-Content -LiteralPath $OutputHtmlPath -Encoding UTF8
    return $OutputHtmlPath
}

function ConvertTo-INRJsonForHtml {
    <#
    .SYNOPSIS
    Serializes an object to JSON that is safe to embed inside an HTML <script> block.
    .DESCRIPTION
    Report inputs include CSV-sourced values (such as certificate Issuer strings)
    that may contain markup. After JSON serialization, the characters that could
    terminate or break out of a <script> context (< > &) are escaped to their
    \uXXXX form, which JSON parsers read back as the original characters.
    .PARAMETER InputObject
    The object to serialize.
    .PARAMETER Depth
    Maximum serialization depth.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        $InputObject,
        [int]$Depth = 8
    )

    $json = ConvertTo-Json -InputObject $InputObject -Depth $Depth -Compress
    if ($null -eq $json) { return 'null' }
    return $json.Replace('<', '\u003c').Replace('>', '\u003e').Replace('&', '\u0026')
}

function Get-INRSideLabel {
    <#
    .SYNOPSIS
    Derives a friendly run/machine label from a ResultList CSV filename.
    .DESCRIPTION
    ResultList files are named ResultList_<yyyyMMdd>_<HHmmss>_<name>.csv; the
    trailing name is used as the label. Falls back to the bare file name.
    .PARAMETER CsvPath
    Path to the CSV file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath
    )

    $label = [System.IO.Path]::GetFileNameWithoutExtension($CsvPath)
    if ($label -match 'ResultList_\d{8}_\d{6}_(?<name>.+)$') {
        return $matches['name']
    }
    return $label
}

function Get-INRComparisonTemplate {
    <#
    .SYNOPSIS
    Returns the static HTML/JS template for the comparison report.
    .DESCRIPTION
    A single-quoted here-string so the embedded JavaScript (which uses $ and
    backticks) is treated literally. The caller substitutes the __INR_*__ tokens.
    #>
    [CmdletBinding()]
    param()

    return @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>__INR_TITLE_HTML__</title>
__INR_ASSET_BLOCK__
<style>
  :root {
    --bg:#f7f9fc; --surface:#ffffff; --border:#d4dde8; --text:#17324d; --muted:#5a6e82;
    --green-bg:#EAF3DE; --green-border:#3B6D11; --green-text:#27500A;
    --amber-bg:#FAEEDA; --amber-border:#BA7517; --amber-text:#633806;
    --red-bg:#FCEBEB; --red-border:#A32D2D; --red-text:#791F1F;
    --purple-border:#534AB7; --teal-border:#0F6E56;
  }
  * { box-sizing:border-box; margin:0; padding:0; }
  body { font-family:'Segoe UI', system-ui, sans-serif; background:var(--bg); color:var(--text); }
  header { padding:16px 24px; background:var(--surface); border-bottom:1px solid var(--border); }
  header h1 { font-size:18px; font-weight:600; }
  header .meta { font-size:13px; color:var(--muted); margin-top:2px; }
  main { padding:18px 24px; display:flex; flex-direction:column; gap:16px; }
  .card { background:var(--surface); border:1px solid var(--border); border-radius:10px; padding:16px; }
  .card h2 { font-size:14px; font-weight:600; margin-bottom:12px; }
  #inr-graph { height:600px; border:1px solid var(--border); border-radius:8px; background:var(--surface); }
  .legend { display:flex; gap:16px; flex-wrap:wrap; margin-bottom:12px; font-size:12px; color:var(--muted); align-items:center; }
  .dot { width:10px; height:10px; border-radius:50%; display:inline-block; margin-right:4px; vertical-align:middle; }
  .toolbar { display:flex; gap:8px; margin-bottom:10px; flex-wrap:wrap; align-items:center; }
  .toolbar button { font-size:12px; padding:5px 12px; border-radius:6px; border:1px solid var(--border); background:transparent; color:var(--text); cursor:pointer; font-family:inherit; }
  .toolbar button:hover { background:var(--bg); }
  .toolbar button.active { background:#E6F1FB; color:#185FA5; border-color:#85B7EB; }
  #col-checks { display:flex; gap:14px; flex-wrap:wrap; align-items:center; margin-bottom:12px; font-size:12px; }
  .col-check { display:inline-flex; align-items:center; gap:4px; color:var(--text); cursor:pointer; font-family:monospace; }
  #inr-detail { margin-top:12px; background:var(--bg); border-radius:6px; padding:12px 14px; font-size:12px; min-height:38px; border:1px solid var(--border); }
  .d-head { font-weight:600; font-family:monospace; margin-bottom:8px; }
  .d-table { width:100%; border-collapse:collapse; font-size:12px; }
  .d-table th, .d-table td { text-align:left; padding:4px 8px; border-bottom:1px solid #eef2f7; }
  .d-table th { color:var(--muted); font-weight:600; }
  .d-table td:first-child { font-family:monospace; color:var(--muted); }
  .d-table tr.d-diff td { background:var(--red-bg); }
  .d-table tr.d-sel td:first-child { font-weight:700; color:var(--text); }
  .muted { color:var(--muted); }
  table.data { width:100%; border-collapse:collapse; font-size:12px; }
  table.data thead th { background:#f0f5fb; text-align:left; padding:7px 10px; font-weight:600; border-bottom:1px solid var(--border); }
  table.data tbody td { padding:6px 10px; border-bottom:1px solid #eef2f7; vertical-align:top; }
  .mono { font-family:monospace; font-size:11px; }
  .badge { display:inline-block; padding:2px 7px; border-radius:4px; font-size:11px; font-weight:600; }
  .badge-pass { background:var(--green-bg); color:var(--green-text); }
  .badge-fail { background:var(--red-bg); color:var(--red-text); }
  .badge-warn { background:var(--amber-bg); color:var(--amber-text); }
  .summary-grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(130px, 1fr)); gap:10px; }
  .stat { background:var(--bg); border:1px solid var(--border); border-radius:8px; padding:12px; text-align:center; }
  .stat .num { font-size:22px; font-weight:700; }
  .stat .lbl { font-size:11px; color:var(--muted); margin-top:2px; }
  .num-green { color:var(--green-border); } .num-amber { color:var(--amber-border); } .num-red { color:var(--red-border); }
</style>
</head>
<body>
<header>
  <h1>INR Run Comparison</h1>
  <div class="meta">Left: __INR_SIDEA_HTML__ &nbsp;|&nbsp; Right: __INR_SIDEB_HTML__ &nbsp;|&nbsp; Generated: __INR_GENERATED_HTML__</div>
</header>
<main>

  <div class="card">
    <h2>Summary</h2>
    <div class="summary-grid" id="summary-grid"></div>
  </div>

  <div class="card">
    <h2>Comparison Map</h2>
    <div style="font-size:12px;color:var(--muted);margin-bottom:6px;">Select the columns to compare. A middle node is green when all selected columns match between both runs, red when any differ, amber when the endpoint exists on only one side.</div>
    <div id="col-checks"></div>
    <div class="legend">
      <span><span class="dot" style="background:var(--green-border)"></span>All selected columns match</span>
      <span><span class="dot" style="background:var(--red-border)"></span>One or more differ</span>
      <span><span class="dot" style="background:var(--amber-border)"></span>Present on one side only</span>
    </div>
    <div class="toolbar">
      <button id="btn-all" class="active" onclick="setFilter('all')">All endpoints</button>
      <button id="btn-issues" onclick="setFilter('issues')">Issues only</button>
      <button onclick="network.fit()">Fit view</button>
    </div>
    <div id="inr-graph"></div>
    <div id="inr-detail"><span class="muted">Click an endpoint node to inspect both runs.</span></div>
  </div>

  <div class="card">
    <h2>Endpoint Comparison Table</h2>
    <div style="overflow-x:auto">
      <table class="data" id="cmp-table">
        <thead><tr><th>URL</th><th>Port</th><th>Protocol</th><th>Status</th><th>Differences (selected columns)</th></tr></thead>
        <tbody></tbody>
      </table>
    </div>
  </div>

</main>

<script>
const DATA = __INR_DATA_JSON__;
const byId = id => document.getElementById(id);
function esc(s){ return String(s==null?'':s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;'); }
function val(o,c){ return (o && o[c]!=null) ? String(o[c]) : ''; }

const COLOR = {
  green:{ bg:'#EAF3DE', border:'#3B6D11', font:'#27500A' },
  red:  { bg:'#FCEBEB', border:'#A32D2D', font:'#791F1F' },
  amber:{ bg:'#FAEEDA', border:'#BA7517', font:'#633806' },
};
const SIDE_X = 540;
const ROW_SPACING = 64;

// --- comparison column checkboxes ---
const colBox = byId('col-checks');
DATA.compareColumns.forEach(col => {
  const checked = DATA.defaultColumns.indexOf(col) !== -1 ? 'checked' : '';
  const wrap = document.createElement('label');
  wrap.className = 'col-check';
  wrap.innerHTML = '<input type="checkbox" id="col_' + col + '" value="' + esc(col) + '" ' + checked + '>' + esc(col);
  colBox.appendChild(wrap);
});
colBox.addEventListener('change', apply);
function selectedColumns(){
  return DATA.compareColumns.filter(c => { const el = byId('col_' + c); return el && el.checked; });
}

function severity(ep, cols){
  if (ep.presence !== 'both') return 'amber';
  for (let i = 0; i < cols.length; i++){
    if (val(ep.a, cols[i]) !== val(ep.b, cols[i])) return 'red';
  }
  return 'green';
}

// --- build network ---
const nodes = new vis.DataSet();
const edges = new vis.DataSet();
const epByKey = {};

nodes.add({ id:'__A__', label: DATA.sideA, x:-SIDE_X, y:0, fixed:true, physics:false,
  shape:'ellipse', borderWidth:2, color:{ background:'#EEEDFE', border:'#534AB7' },
  font:{ color:'#3C3489', size:15, bold:true } });
nodes.add({ id:'__B__', label: DATA.sideB, x:SIDE_X, y:0, fixed:true, physics:false,
  shape:'ellipse', borderWidth:2, color:{ background:'#E1F5EE', border:'#0F6E56' },
  font:{ color:'#085041', size:15, bold:true } });

DATA.endpoints.forEach(ep => {
  epByKey[ep.key] = ep;
  nodes.add({ id: ep.key, label: ep.url + '\n:' + ep.port, x:0, y:0,
    fixed:{ x:true, y:false }, physics:false, shape:'box', borderWidth:1,
    font:{ size:11, face:'Consolas, monospace' } });
  if (ep.presence === 'both' || ep.presence === 'onlyA') edges.add({ id:'a_'+ep.key, from:'__A__', to:ep.key });
  if (ep.presence === 'both' || ep.presence === 'onlyB') edges.add({ id:'b_'+ep.key, from:ep.key, to:'__B__' });
});

const network = new vis.Network(byId('inr-graph'), { nodes, edges }, {
  physics:false,
  interaction:{ hover:true, dragNodes:true, tooltipDelay:120 },
  nodes:{ margin:{ top:5, bottom:5, left:8, right:8 } },
  edges:{ smooth:{ type:'cubicBezier', roundness:0.25 }, width:0.9 }
});

function apply(){
  const cols = selectedColumns();
  const issuesOnly = byId('btn-issues').classList.contains('active');
  const visible = [];
  DATA.endpoints.forEach(ep => {
    ep._sev = severity(ep, cols);
    if (!issuesOnly || ep._sev !== 'green') visible.push(ep);
  });
  const n = visible.length;
  visible.forEach((ep, idx) => {
    const y = (idx - (n - 1) / 2) * ROW_SPACING;
    const c = COLOR[ep._sev];
    nodes.update({ id: ep.key, hidden:false, y:y,
      color:{ background:c.bg, border:c.border, highlight:{ background:c.bg, border:c.font } },
      font:{ color:c.font, size:11, face:'Consolas, monospace' } });
  });
  DATA.endpoints.forEach(ep => { if (visible.indexOf(ep) === -1) nodes.update({ id: ep.key, hidden:true }); });
  DATA.endpoints.forEach(ep => {
    const c = ep._sev === 'green' ? '#97C459' : ep._sev === 'red' ? '#F09595' : '#FAC775';
    const hidden = issuesOnly && ep._sev === 'green';
    if (edges.get('a_'+ep.key)) edges.update({ id:'a_'+ep.key, color:{ color:c }, hidden:hidden });
    if (edges.get('b_'+ep.key)) edges.update({ id:'b_'+ep.key, color:{ color:c }, hidden:hidden });
  });
  renderSummary(cols);
  renderTable(cols);
  network.fit();
}

function setFilter(mode){
  byId('btn-all').classList.toggle('active', mode === 'all');
  byId('btn-issues').classList.toggle('active', mode === 'issues');
  apply();
}

function card(num, lbl, cls){ return '<div class="stat"><div class="num ' + cls + '">' + num + '</div><div class="lbl">' + lbl + '</div></div>'; }
function renderSummary(cols){
  let g = 0, r = 0, a = 0;
  DATA.endpoints.forEach(ep => { const s = severity(ep, cols); if (s === 'green') g++; else if (s === 'red') r++; else a++; });
  byId('summary-grid').innerHTML =
    card(DATA.endpoints.length, 'Total endpoints', '') +
    card(g, 'Matching', 'num-green') +
    card(r, 'Different', 'num-red') +
    card(a, 'One side only', 'num-amber');
}

function renderTable(cols){
  const tb = byId('cmp-table').querySelector('tbody');
  tb.innerHTML = '';
  DATA.endpoints.forEach(ep => {
    const sev = severity(ep, cols);
    let diffs;
    if (ep.presence !== 'both') {
      diffs = '<span class="muted">present on ' + esc(ep.presence === 'onlyA' ? DATA.sideA : DATA.sideB) + ' only</span>';
    } else {
      const list = cols.filter(c => val(ep.a, c) !== val(ep.b, c));
      diffs = list.length
        ? list.map(c => '<div><strong>' + esc(c) + '</strong>: ' + esc(val(ep.a, c)) + ' &rarr; ' + esc(val(ep.b, c)) + '</div>').join('')
        : '<span class="muted">no differences in selected columns</span>';
    }
    const badge = sev === 'green' ? '<span class="badge badge-pass">Match</span>'
      : sev === 'red' ? '<span class="badge badge-fail">Differ</span>'
      : '<span class="badge badge-warn">One side</span>';
    const tr = document.createElement('tr');
    tr.innerHTML = '<td class="mono">' + esc(ep.url) + '</td><td>' + esc(ep.port) + '</td><td>' + esc(ep.protocol) + '</td><td>' + badge + '</td><td>' + diffs + '</td>';
    tb.appendChild(tr);
  });
}

network.on('click', p => {
  const d = byId('inr-detail');
  if (!p.nodes.length){ d.innerHTML = '<span class="muted">Click an endpoint node to inspect both runs.</span>'; return; }
  const key = p.nodes[0];
  if (key === '__A__' || key === '__B__'){ d.innerHTML = '<span class="muted">' + esc(key === '__A__' ? DATA.sideA : DATA.sideB) + '</span>'; return; }
  const ep = epByKey[key];
  if (!ep){ d.innerHTML = '<span class="muted">Unknown node.</span>'; return; }
  const cols = selectedColumns();
  const rows = DATA.compareColumns.map(c => {
    const av = ep.a ? val(ep.a, c) : '(absent)';
    const bv = ep.b ? val(ep.b, c) : '(absent)';
    const sel = cols.indexOf(c) !== -1;
    const diff = ep.presence === 'both' && av !== bv;
    return '<tr class="' + (diff ? 'd-diff ' : '') + (sel ? 'd-sel' : '') + '"><td>' + esc(c) + '</td><td>' + esc(av) + '</td><td>' + esc(bv) + '</td></tr>';
  }).join('');
  d.innerHTML = '<div class="d-head">' + esc(ep.url) + ':' + esc(ep.port) + ' <span class="muted">(' + esc(ep.presence) + ')</span></div>'
    + '<table class="d-table"><thead><tr><th>Column</th><th>' + esc(DATA.sideA) + '</th><th>' + esc(DATA.sideB) + '</th></tr></thead><tbody>' + rows + '</tbody></table>';
});

apply();
</script>
</body>
</html>
'@
}

function New-INRComparisonReport {
    <#
    .SYNOPSIS
    Generates an interactive vis.js report comparing two ResultList CSV runs.
    .DESCRIPTION
    Pairs endpoints from two scan result files by id|url|Port|Protocol and emits
    a standalone HTML report. Run A is anchored on the left, run B on the right,
    and each tested URL:port appears as a node down the middle. The viewer chooses
    which columns to compare; a node is green when every selected column matches,
    red when any differ, and amber when the endpoint exists on only one side.
    .PARAMETER CsvPathA
    First ResultList CSV (left / run A).
    .PARAMETER CsvPathB
    Second ResultList CSV (right / run B).
    .PARAMETER OutputHtmlPath
    Destination path for the generated HTML report.
    .PARAMETER AssetMode
    'Offline' inlines the bundled vis-network library (works with no internet);
    'Online' references a pinned CDN copy.
    .PARAMETER DefaultCompareColumns
    Columns checked by default in the viewer. Filtered to those present in both files.
    .PARAMETER VisNetworkPath
    Override path to the offline vis-network.min.js asset.
    .OUTPUTS
    The output HTML path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CsvPathA,
        [Parameter(Mandatory)]
        [string]$CsvPathB,
        [Parameter(Mandatory)]
        [string]$OutputHtmlPath,
        [ValidateSet('Offline', 'Online')]
        [string]$AssetMode = 'Offline',
        [string[]]$DefaultCompareColumns = @('DNSResult', 'TCPResult', 'HTTPStatusCode', 'SSLTest', 'SSLInterception'),
        [string]$VisNetworkPath
    )

    foreach ($p in @($CsvPathA, $CsvPathB)) {
        if (-not (Test-Path -LiteralPath $p)) { throw "Comparison CSV not found: $p" }
    }

    $rowsA = @(Import-Csv -LiteralPath $CsvPathA)
    $rowsB = @(Import-Csv -LiteralPath $CsvPathB)
    if ($rowsA.Count -eq 0) { throw "CSV A has no rows: $CsvPathA" }
    if ($rowsB.Count -eq 0) { throw "CSV B has no rows: $CsvPathB" }

    $identity = @('id', 'url', 'Port', 'Protocol')
    $headersA = $rowsA[0].PSObject.Properties.Name
    $headersB = $rowsB[0].PSObject.Properties.Name
    $comparable = @($headersA | Where-Object { $_ -notin $identity -and $_ -in $headersB })
    if ($comparable.Count -eq 0) {
        $comparable = @($headersA | Where-Object { $_ -notin $identity })
    }

    $defaults = @($DefaultCompareColumns | Where-Object { $_ -in $comparable })
    if ($defaults.Count -eq 0) { $defaults = $comparable }

    $sideA = Get-INRSideLabel -CsvPath $CsvPathA
    $sideB = Get-INRSideLabel -CsvPath $CsvPathB

    $mapA = [ordered]@{}
    foreach ($r in $rowsA) {
      $k = '{0}|{1}|{2}|{3}' -f $r.id, $r.url, $r.Port, $r.Protocol
      if (-not $mapA.Contains($k)) { $mapA[$k] = [System.Collections.ArrayList]::new() }
      [void]$mapA[$k].Add($r)
    }
    $mapB = [ordered]@{}
    foreach ($r in $rowsB) {
      $k = '{0}|{1}|{2}|{3}' -f $r.id, $r.url, $r.Port, $r.Protocol
      if (-not $mapB.Contains($k)) { $mapB[$k] = [System.Collections.ArrayList]::new() }
      [void]$mapB[$k].Add($r)
    }

    $orderedKeys = [System.Collections.Generic.List[string]]::new()
    foreach ($k in $mapA.Keys) { [void]$orderedKeys.Add($k) }
    foreach ($k in $mapB.Keys) { if (-not $mapA.Contains($k)) { [void]$orderedKeys.Add($k) } }

    $endpoints = foreach ($k in $orderedKeys) {
      $listA = if ($mapA.Contains($k)) { $mapA[$k] } else { [System.Collections.ArrayList]::new() }
      $listB = if ($mapB.Contains($k)) { $mapB[$k] } else { [System.Collections.ArrayList]::new() }
      if ($null -eq $listA) { $listA = @() }
      if ($null -eq $listB) { $listB = @() }
      if ($listA -isnot [System.Collections.IList]) { $listA = @($listA) }
      if ($listB -isnot [System.Collections.IList]) { $listB = @($listB) }
      $count = [Math]::Max($listA.Count, $listB.Count)

      for ($i = 0; $i -lt $count; $i++) {
        $ra = if ($i -lt $listA.Count) { $listA[$i] } else { $null }
        $rb = if ($i -lt $listB.Count) { $listB[$i] } else { $null }
        $presence = if ($ra -and $rb) { 'both' } elseif ($ra) { 'onlyA' } else { 'onlyB' }
        $ref = if ($ra) { $ra } else { $rb }

        $a = $null
        $b = $null
        if ($ra) { $a = [ordered]@{}; foreach ($c in $comparable) { $a[$c] = [string]$ra.$c } }
        if ($rb) { $b = [ordered]@{}; foreach ($c in $comparable) { $b[$c] = [string]$rb.$c } }

        $instanceKey = if ($count -gt 1) { '{0}|#{1}' -f $k, ($i + 1) } else { $k }

        [pscustomobject]@{
          key        = $instanceKey
          id         = [string]$ref.id
          url        = [string]$ref.url
          port       = [string]$ref.Port
          protocol   = [string]$ref.Protocol
          occurrence = $i + 1
          presence   = $presence
          a          = $a
          b          = $b
        }
      }
    }
    $endpoints = @($endpoints)

    $data = [ordered]@{
        sideA          = $sideA
        sideB          = $sideB
        compareColumns = $comparable
        defaultColumns = $defaults
        endpoints      = $endpoints
    }
    $dataJson = ConvertTo-INRJsonForHtml -InputObject $data -Depth 12

    if ($AssetMode -eq 'Offline') {
        if (-not $VisNetworkPath) {
            $repoRoot = Split-Path -Path $PSScriptRoot -Parent
            $VisNetworkPath = Join-Path $repoRoot 'Assets/vis-network/vis-network.min.js'
        }
        if (-not (Test-Path -LiteralPath $VisNetworkPath)) {
            throw "Offline vis-network asset not found at '$VisNetworkPath'. Use -AssetMode Online or restore Assets/vis-network."
        }
        $libJs = Get-Content -LiteralPath $VisNetworkPath -Raw
        # Defuse any literal </script in the minified bundle so it can't close
        # the host <script> element early. The escaped slash is equivalent JS.
        $libJs = $libJs.Replace('</script', '<\/script')
        $assetBlock = "<script>$libJs</script>"
    } else {
        $assetBlock = '<script src="https://unpkg.com/vis-network@9.1.9/standalone/umd/vis-network.min.js"></script>'
    }

    $titleHtml = ConvertTo-INRHtmlText ("INR Run Comparison - {0} vs {1}" -f $sideA, $sideB)
    $sideAHtml = ConvertTo-INRHtmlText $sideA
    $sideBHtml = ConvertTo-INRHtmlText $sideB
    $generatedHtml = ConvertTo-INRHtmlText (Get-Date -Format 'yyyy-MM-dd HH:mm')

    $template = Get-INRComparisonTemplate

    $html = $template
    $html = $html.Replace('__INR_TITLE_HTML__', $titleHtml)
    $html = $html.Replace('__INR_SIDEA_HTML__', $sideAHtml)
    $html = $html.Replace('__INR_SIDEB_HTML__', $sideBHtml)
    $html = $html.Replace('__INR_GENERATED_HTML__', $generatedHtml)
    $html = $html.Replace('__INR_ASSET_BLOCK__', $assetBlock)
    $html = $html.Replace('__INR_DATA_JSON__', $dataJson)

    $dir = Split-Path -Path $OutputHtmlPath -Parent
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $html | Set-Content -LiteralPath $OutputHtmlPath -Encoding UTF8
    return $OutputHtmlPath
}

Export-ModuleMember -Function @(
    'ConvertTo-INRHtmlText',
    'ConvertTo-INRStatusEmoji',
    'ConvertTo-INRJsonForHtml',
    'New-INRMindMapReport',
    'New-INRComparisonReport'
)
