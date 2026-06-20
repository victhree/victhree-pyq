# Replaces explanations in a subject JSON from a new Markdown explanations doc.
# Rule: replace explanation ONLY where the doc's answer letter matches our current answer
#       AND our answer is non-blank. Keeps answers unchanged; preserves defective/blank/
#       answer-mismatched questions' current text. Strips markdown emphasis (* and **).
# Usage: powershell -File apply_explanations.ps1 -Md <path.md> -Json <path.json>
param(
  [Parameter(Mandatory=$true)][string]$Md,
  [Parameter(Mandatory=$true)][string]$Json
)
$ErrorActionPreference='Stop'

function StripMd([string]$s){
  if([string]::IsNullOrEmpty($s)){return $s}
  $s = $s -replace '\*\*',''      # bold
  $s = $s -replace '\*',''        # italic
  $s = $s -replace '`',''         # code ticks
  $s = ($s -replace '\s+',' ').Trim()
  return $s
}

# ---- parse the markdown doc (line-based) ----
$map=@{}
$curKey=$null
foreach($line in (Get-Content $Md -Encoding UTF8)){
  $qm=[regex]::Match($line,'^\*\*Q\.(\d+)\s*\(CDS\s*(\d{4})-([I12]+)\)\*\*')
  if($qm.Success){
    $sess=$qm.Groups[3].Value; if($sess -eq '1'){$sess='I'} elseif($sess -eq '2'){$sess='II'}
    $curKey=$qm.Groups[2].Value+'-'+$sess+'|'+$qm.Groups[1].Value
    $map[$curKey]=[pscustomobject]@{ letter=''; expl='' }
    continue
  }
  if($null -eq $curKey){ continue }
  $am=[regex]::Match($line,'^\*\*Correct Answer:\*\*\s*([a-d])'); if($am.Success){ $map[$curKey].letter=$am.Groups[1].Value; continue }
  $em=[regex]::Match($line,'^\*\*Explanation:\*\*\s*(.+)$'); if($em.Success){ $map[$curKey].expl=(StripMd $em.Groups[1].Value); continue }
}
Write-Host ("Doc entries parsed: "+$map.Count)

# ---- load JSON, apply ----
$qs = Get-Content $Json -Raw -Encoding UTF8 | ConvertFrom-Json
$replaced=0; $keptBlank=0; $keptMismatch=0; $keptNoDoc=0; $keptNoExpl=0
$mismatch=@()
foreach($q in $qs){
  $k="$($q.year)-$($q.session)|$($q.qno)"
  if(-not $map.ContainsKey($k)){ $keptNoDoc++; continue }
  $d=$map[$k]
  if($q.answer -eq ''){ $keptBlank++; continue }
  if($d.letter -eq '' -or $d.letter -ne $q.answer){ $keptMismatch++; $mismatch+=("$($q.ref): ours=$($q.answer) doc=$($d.letter)"); continue }
  if($d.expl -eq ''){ $keptNoExpl++; continue }
  $q.explanation = $d.expl
  $replaced++
}
$json2 = $qs | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($Json,$json2,(New-Object System.Text.UTF8Encoding($false)))

Write-Host ("Replaced: $replaced")
Write-Host ("Kept (blank answer): $keptBlank")
Write-Host ("Kept (answer mismatch vs doc): $keptMismatch"); $mismatch | ForEach-Object{ Write-Host "   KEEP $_" }
Write-Host ("Kept (not in doc): $keptNoDoc")
Write-Host ("Kept (doc had no explanation): $keptNoExpl")
Write-Host ("Total: "+$qs.Count)
