# Parses CDS Geography PDF text + DOCX answer key into docs/data/geography.json
# Inputs: $env:TEMP\geo.txt (pdftotext -layout), $env:TEMP\geoans.txt (docx->text)
$ErrorActionPreference = 'Stop'
$root = 'C:\Users\ASUS\victhree-pyq'

# ---------- repair map (ligature / space corruption from PDF extraction) ----------
$repairs = @(
  @('remarkablyflatfloor','remarkably flat floor'),
  @('Theflatfloor','The flat floor'),
  @('includingfishing','including fishing'),
  @('increasefish','increase fish'),
  @('polewardflowing','poleward flowing'),
  @('nutrientsflow','nutrients flow'),
  @('nutrientflow','nutrient flow'),
  @('Energyflow','Energy flow'),
  @('notflow','not flow'),
  @('theirflown','their own'),
  @('Flyflash','Fly ash'),
  @('headquartersflat','headquarters at'),
  @('approximatelyflat','approximately at'),
  @('atmosphereflat','atmosphere at'),
  @('carbonatesflat','carbonates at'),
  @('discoveredflat','discovered at'),
  @('Engineersflat','Engineers at'),
  @('tropopauseflat','tropopause at'),
  @('descendsflat','descends at'),
  @('situatedflat','situated at'),
  @('locatedflat','located at'),
  @('minimumflat','minimum at'),
  @('maximumflat','maximum at'),
  @('absentflat','absent at'),
  @('streamflat','stream at'),
  @('mostlyflat','mostly at'),
  @('formedflat','formed at'),
  @('stonesflat','stones at'),
  @('Shahjiflat','Shahji at'),
  @('Ranbirflat','Ranbir at'),
  @('Maitriflat','Maitri at'),
  @('Maltiflat','Malti at'),
  @('arriveflat','arrive at'),
  @('drawnflat','drawn at'),
  @('haveflat','have at'),
  @('heldflat','held at'),
  @('timeflat','time at'),
  @('turnflat','turn at'),
  @('aimedflat','aimed at'),
  @('aimsflat','aims at'),
  @('pinkflat','pink at'),
  @('dayflat','day at'),
  @('butflat','but at'),
  @('isflat','is at'),
  @('beflat','be at'),
  @('offlat','of at'),
  @('offlow','of flow'),
  @('thefirst','the first'),
  @('andfinally','and finally'),
  @('thefloor','the floor'),
  @('lava ows','lava flows'),
  @('repeated ows','repeated flows'),
  @('or uid','or fluid'),
  @('de ects','deflects'),
  @('de ne','define'),
  @('con ned','confined'),
  @('afire ned','a refined'),
  @('Coal elds','Coalfields'),
  @('the eld','the field')
)
function Repair([string]$s){
  if([string]::IsNullOrEmpty($s)){return $s}
  foreach($p in $repairs){
    $pat = '(?<![A-Za-z])' + [regex]::Escape($p[0]) + '(?![A-Za-z])'
    $s = [regex]::Replace($s, $pat, $p[1])
  }
  return $s
}

# ---------- taxonomy ----------
$subToTopic = [ordered]@{
  'Interior of Earth'='Physical Geography';'Rocks'='Physical Geography';'Volcanoes'='Physical Geography';'Earthquakes'='Physical Geography';'Weathering & Erosion'='Physical Geography';'Landforms'='Physical Geography';
  'Atmosphere'='Climatology';'Winds'='Climatology';'Monsoon'='Climatology';'Cyclones & Storms'='Climatology';'Climate types & classification'='Climatology';'Solstice, Equinox & Seasons'='Climatology';'Clouds, Rainfall & Humidity'='Climatology';
  'Ocean currents'='Oceanography';'Tides'='Oceanography';'Marine resources & ports'='Oceanography';'Salinity, Sea level & Coral reefs'='Oceanography';
  'Ecosystems'='Environmental Geography';'Biodiversity & conservation'='Environmental Geography';'Pollution'='Environmental Geography';'Climate change & emissions'='Environmental Geography';'Conservation & treaties'='Environmental Geography';
  'Physiography (Himalayas, Plateaux, Coasts)'='Indian Geography';'Indian Rivers'='Indian Geography';'Indian Soils'='Indian Geography';'Natural vegetation'='Indian Geography';'Indian Agriculture & Crops'='Indian Geography';'Indian Minerals & Industries'='Indian Geography';'Indian Transport & Waterways'='Indian Geography';'Indian States & UTs'='Indian Geography';
  'Continents & Countries'='World Geography';'World Rivers & Lakes'='World Geography';'Straits, Seas & Canals'='World Geography';'Important locations & landmarks'='World Geography';
  'Population & Migration'='Human & Economic Geography';'Urbanization & Settlements'='Human & Economic Geography';
  'Cropping patterns & Irrigation'='Agriculture & Resources';'Crops (sugar, cotton, jute, coconut, tea)'='Agriculture & Resources';'Energy resources'='Agriculture & Resources';'Water resources'='Agriculture & Resources';
  'Floods & Cloudbursts'='Disaster Management & Environment';'Droughts & Desertification'='Disaster Management & Environment';'Earthquakes & Tsunami'='Disaster Management & Environment';'Disaster preparedness & institutions'='Disaster Management & Environment';
  'Latitude, Longitude & Time'='Mapping & Cartography';
  'Asia & SAARC'='Regional Geography';'Europe'='Regional Geography';'Africa'='Regional Geography';'Australia & Oceania'='Regional Geography';
  'Sustainable development & SDGs'='Environmental Issues & Sustainability';
  'Other'='Miscellaneous Geography'
}
$topicToBucket = @{
  'Physical Geography'='Physical Geography';
  'Climatology'='Climatology & Oceanography';'Oceanography'='Climatology & Oceanography';
  'Environmental Geography'='Environmental Geography & Sustainability';'Disaster Management & Environment'='Environmental Geography & Sustainability';'Environmental Issues & Sustainability'='Environmental Geography & Sustainability';
  'Indian Geography'='Indian Geography';
  'World Geography'='World & Regional Geography';'Regional Geography'='World & Regional Geography';
  'Human & Economic Geography'='Human, Economic & Agricultural Geography';'Agriculture & Resources'='Human, Economic & Agricultural Geography';
  'Mapping & Cartography'='Miscellaneous & Mapping';'Miscellaneous Geography'='Miscellaneous & Mapping'
}
# bucket display order
$bucketOrder = @('Physical Geography','Climatology & Oceanography','Environmental Geography & Sustainability','Indian Geography','World & Regional Geography','Human, Economic & Agricultural Geography','Miscellaneous & Mapping')

$topicSet = @{}
foreach($v in $subToTopic.Values){ $topicSet[$v]=$true }
$subSet = @{}
foreach($k in $subToTopic.Keys){ $subSet[$k]=$true }

# ---------- parse answer key (docx text) ----------
$ansMap = @{}
$ansLines = Get-Content "$env:TEMP\geoans.txt" -Encoding UTF8
$ansRx = 'Question No\.\s*\d+\s*.\s*\(CDS\s*(\d{4})-(I{1,2}),\s*Q\.(\d+)\)\s*Correct Answer:\s*(.*?)\s*Explanation:\s*(.*)$'
foreach($l in $ansLines){
  $m = [regex]::Match($l, $ansRx)
  if(-not $m.Success){ continue }
  $yp = $m.Groups[1].Value + '-' + $m.Groups[2].Value
  $qn = [int]$m.Groups[3].Value
  $ansText = $m.Groups[4].Value.Trim()
  $expl = $m.Groups[5].Value.Trim()
  $letter = ''
  $lm = [regex]::Match($ansText,'^([a-d])\)')
  if($lm.Success){ $letter = $lm.Groups[1].Value }
  $ansMap["$yp|$qn"] = [pscustomobject]@{ letter=$letter; text=$ansText; expl=$expl }
}
Write-Host ("Answer entries parsed: " + $ansMap.Count)

# ---------- parse PDF question text ----------
$lines = Get-Content "$env:TEMP\geo.txt" -Encoding UTF8
# find body bounds
$startIdx = 0
for($i=0;$i -lt $lines.Count;$i++){ if($lines[$i] -match 'Each question is preserved in its original wording'){ $startIdx=$i+1; break } }
$endIdx = $lines.Count
for($i=$startIdx;$i -lt $lines.Count;$i++){ if($lines[$i] -match 'Per-paper Question Summary|Per-topic question count'){ $endIdx=$i; break } }
Write-Host ("Body lines $startIdx..$endIdx")

$questions = New-Object System.Collections.ArrayList
$curTopic = ''; $curSub = ''
$q = $null
function Finalize(){
  if($null -eq $script:q){ return }
  [void]$script:questions.Add($script:q); $script:q=$null
}
$cdsRx = '^\[CDS\s+(\d{4})-(I{1,2}),\s*Q\.(\d+)\]$'
$optRx = '^([a-d])\)\s?(.*)$'
$subMarkerRx = '^(\d+[\.\)]\s)|^([A-Z][\.\)]\s)|^(List\b|Code\b|Code:|Select\b|Consider\b|Match\b|Statement\b|Assertion\b|Reason\b|Choose\b|Given\b)'

for($i=$startIdx;$i -lt $endIdx;$i++){
  $raw = $lines[$i]
  $t = $raw.Trim()
  if($t -eq ''){ continue }
  if($t -match '^Page \d+ of 64$'){ continue }
  if($t -match '^VicThree Defence -- CDS Geography'){ continue }

  $cm = [regex]::Match($t,$cdsRx)
  if($cm.Success){
    Finalize
    $yp = $cm.Groups[1].Value + '-' + $cm.Groups[2].Value
    $script:q = [pscustomobject]@{
      year=[int]$cm.Groups[1].Value; session=$cm.Groups[2].Value; paper="CDS $yp"; ypkey=$yp;
      qno=[int]$cm.Groups[3].Value; topicOrig=$curTopic; subtopic=$curSub;
      stem=''; subs=(New-Object System.Collections.ArrayList); opts=[ordered]@{}; optOrder=(New-Object System.Collections.ArrayList);
      _first=$true; _phase='stem'; _curOpt=$null
    }
    continue
  }
  # headers (only when between/around questions; subtopic sets topic)
  if($subSet.ContainsKey($t)){ $curSub=$t; $curTopic=$subToTopic[$t]; continue }
  if($topicSet.ContainsKey($t)){ $curTopic=$t; continue }

  if($null -eq $script:q){ continue }

  $om = [regex]::Match($t,$optRx)
  if($om.Success -and $script:q._phase -ne 'optguard'){
    $L = $om.Groups[1].Value
    if(-not $script:q.opts.Contains($L)){
      $script:q.opts[$L] = $om.Groups[2].Value
      [void]$script:q.optOrder.Add($L)
      $script:q._curOpt = $L
      $script:q._phase = 'opt'
      $script:q._first = $false
      continue
    }
  }
  if($script:q._first){
    $script:q.stem = ($t -replace '^\d+[\.\)]\s*','')
    $script:q._first = $false
    $script:q._phase = 'stem'
    continue
  }
  if($script:q._phase -eq 'opt'){
    $script:q.opts[$script:q._curOpt] = $script:q.opts[$script:q._curOpt] + ' ' + $t
    continue
  }
  if($t -match $subMarkerRx){
    [void]$script:q.subs.Add($t)
    $script:q._phase = 'subs'
    continue
  }
  if($script:q._phase -eq 'subs'){
    $n = $script:q.subs.Count - 1
    $script:q.subs[$n] = $script:q.subs[$n] + ' ' + $t
    continue
  }
  # else: stem continuation
  $script:q.stem = ($script:q.stem + ' ' + $t).Trim()
}
Finalize

Write-Host ("Questions parsed: " + $questions.Count)

# ---------- answer-key corrections (verified against source option ordering) ----------
# 2017-II Q.104: key labels 'd' but its own sequence 3,2,4,1 is option (c) in this compilation.
if($ansMap.ContainsKey('2017-II|104')){
  $ansMap['2017-II|104'].letter = 'c'
  $ansMap['2017-II|104'].expl   = ($ansMap['2017-II|104'].expl -replace '=\s*option d\.?','= option c.')
  Write-Host "CORRECTION applied: 2017-II Q.104 answer d -> c (sequence 3,2,4,1 = option c here)"
}

# ---------- build output objects, merge answers, repair text ----------
$out = New-Object System.Collections.ArrayList
$noAnswer = New-Object System.Collections.ArrayList
$optMismatch = New-Object System.Collections.ArrayList
foreach($q in $questions){
  $opts = @()
  foreach($L in @('a','b','c','d')){ if($q.opts.Contains($L)){ $opts += (Repair (($q.opts[$L]).Trim())) } else { $opts += '' } }
  $subsArr = @(); foreach($s in $q.subs){ $subsArr += (Repair $s.Trim()) }
  $ans = $ansMap["$($q.ypkey)|$($q.qno)"]
  $answer=''; $expl=''; $ansNote=''
  if($ans){ $answer=$ans.letter; $expl=$ans.expl; if($ans.letter -eq ''){ $ansNote=$ans.text } }
  else { [void]$noAnswer.Add("$($q.paper) Q.$($q.qno)") }
  # QA: validate option text vs answer key correct-option text
  if($ans -and $ans.letter -ne ''){
    $keyTxt = ($ans.text -replace '^[a-d]\)\s*','')
    $norm = { param($x) (($x -replace '[^A-Za-z0-9]','').ToLower()) }
    $idx = [int][char]$ans.letter - [int][char]'a'
    if($idx -ge 0 -and $idx -lt 4){
      $a = & $norm $opts[$idx]; $b = & $norm $keyTxt
      if($a.Length -ge 4 -and $b.Length -ge 4){
        $minlen=[Math]::Min(12,[Math]::Min($a.Length,$b.Length))
        if($a.Substring(0,[Math]::Min($a.Length,$minlen)) -ne $b.Substring(0,[Math]::Min($b.Length,$minlen))){
          [void]$optMismatch.Add("$($q.paper) Q.$($q.qno) [$($ans.letter)] pdf='$($opts[$idx])' key='$keyTxt'")
        }
      }
    }
  }
  $bucket = $topicToBucket[$q.topicOrig]
  $obj = [ordered]@{
    id = "geo-$($q.ypkey)-q$($q.qno)"
    subject = 'Geography'
    topic = $bucket
    subtopic = $q.subtopic
    topicOriginal = $q.topicOrig
    year = $q.year
    session = $q.session
    paper = $q.paper
    qno = $q.qno
    ref = "$($q.paper), Q.$($q.qno)"
    stem = (Repair $q.stem.Trim())
    subs = $subsArr
    options = $opts
    answer = $answer
    explanation = $expl
  }
  if($ansNote -ne ''){ $obj.answerNote = $ansNote }
  [void]$out.Add([pscustomobject]$obj)
}

# ---------- write geography.json ----------
$json = $out | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText("$root\docs\data\geography.json", $json, (New-Object System.Text.UTF8Encoding($false)))

# ---------- QA report ----------
Write-Host "`n===== QA REPORT ====="
Write-Host ("Total questions: " + $out.Count)
Write-Host ("Answered (a-d): " + ($out | Where-Object {$_.answer -ne ''}).Count)
Write-Host ("No/blank answer: " + ($out | Where-Object {$_.answer -eq ''}).Count)
Write-Host ("Questions missing from answer key: " + $noAnswer.Count)
if($noAnswer.Count){ $noAnswer | ForEach-Object { Write-Host "   MISSING: $_" } }
Write-Host ("Questions with <4 options: " + ($out | Where-Object { ($_.options | Where-Object {$_ -ne ''}).Count -lt 4 }).Count)
($out | Where-Object { ($_.options | Where-Object {$_ -ne ''}).Count -lt 4 }) | ForEach-Object { Write-Host ("   FEWOPTS: $($_.ref) -> " + (($_.options | Where-Object {$_ -ne ''}).Count) + " opts") }
Write-Host ("Option/key mismatches (review): " + $optMismatch.Count)
$optMismatch | Select-Object -First 40 | ForEach-Object { Write-Host "   MISMATCH: $_" }

# residual damage scan
$alltext = ($out | ForEach-Object { $_.stem + ' ' + ($_.subs -join ' ') + ' ' + ($_.options -join ' ') }) -join ' '
$resid = [regex]::Matches($alltext,'[a-z]{2,}fl[a-z]|[A-Za-z]{2,}\s(ows|oods|uvial|eld)\b').Count
Write-Host ("Residual ligature artifacts: " + $resid)

# per-bucket and per-original-topic counts
Write-Host "`n--- Per topic (7 buckets) ---"
foreach($b in $bucketOrder){ Write-Host ("{0,-45} {1}" -f $b, ($out | Where-Object {$_.topic -eq $b}).Count) }
Write-Host "`n--- Per original topic (13) ---"
$out | Group-Object topicOriginal | Sort-Object Name | ForEach-Object { Write-Host ("{0,-40} {1}" -f $_.Name,$_.Count) }
Write-Host "`n--- Per paper ---"
$out | Group-Object paper | Sort-Object {[int]($_.Name -replace '\D','')}, Name | ForEach-Object { Write-Host ("{0,-16} {1}" -f $_.Name,$_.Count) }
Write-Host ("`nJSON bytes: " + (Get-Item "$root\docs\data\geography.json").Length)
