# Parses CDS History Final.pdf (via pdftotext layout) + merges the answer-key DOCX.
# Outputs docs/data/history.json. Run from anywhere.
$ErrorActionPreference='Stop'
$SCR="C:\Users\ASUS\AppData\Local\Temp\claude\C--Users-ASUS\c7806228-5ef8-41a1-94b6-53d5ffb50a73\scratchpad"
$proj="C:\Users\ASUS\victhree-pyq"
$lines=Get-Content "$SCR\hist.txt" -Encoding UTF8

$parts=@('Ancient India','Medieval India','Modern India','World History')

# rebuild subtopic set from TOC
$bodyMark=($lines | Select-String -Pattern 'Page 4 of 56' | Select-Object -First 1).LineNumber
$subsSet=[System.Collections.Generic.HashSet[string]]::new()
for($i=0;$i -lt $bodyMark;$i++){
  $l=$lines[$i]
  if($l -match '^\s*(.*?)(?:\s*\.){4,}'){ $name=$Matches[1].Trim()
    if($name -and $name -notmatch '^Contents' -and $name -notmatch '^VicThree' -and $parts -notcontains $name){ [void]$subsSet.Add($name) } }
}

function IsFooter($l){ return ($l -match 'Page \d+ of 56' -or $l -match '^Contents' -or $l -match '^VicThree Defence\s+Page') }
function NormPaper($pp){ if($pp -eq '1'){return 'I'} elseif($pp -eq '2'){return 'II'} else {return $pp} }

$cdsRx='^\s*\[CDS\s+(\d{4})-([I12]+),\s*Q\.(\d+)\]\s*$'

# --- pass 1: collect raw question blocks with part/subtopic ---
$raw=@()
$curPart='';$curSub=''
$n=$lines.Count;$idx=0
while($idx -lt $n -and $lines[$idx] -notmatch $cdsRx){
  $t=$lines[$idx].Trim()
  if($parts -contains $t){$curPart=$t} elseif($subsSet.Contains($t)){$curSub=$t}
  $idx++
}
while($idx -lt $n){
  $m=[regex]::Match($lines[$idx],$cdsRx)
  $year=$m.Groups[1].Value;$pp=NormPaper $m.Groups[2].Value;$qno=[int]$m.Groups[3].Value
  $qPart=$curPart;$qSub=$curSub
  $buf=@()
  $idx++
  while($idx -lt $n -and $lines[$idx] -notmatch $cdsRx){
    $rawln=$lines[$idx];$t=$rawln.Trim()
    if(IsFooter $rawln){$idx++;continue}
    if($parts -contains $t){$curPart=$t;$idx++;continue}
    if($subsSet.Contains($t)){$curSub=$t;$idx++;continue}
    if($t -ne ''){$buf+=$t}
    $idx++
  }
  $raw+=[pscustomobject]@{ year=$year;paper="$year-$pp";qno=$qno;part=$qPart;sub=$qSub;text=($buf -join ' ') }
}

# --- option splitter ---
function SplitOptions($text){
  $text = ($text -replace ([char]0xFFFD),'-') -replace '\s+',' '
  $text = $text.Trim()
  $rxA='\(a\)';$rxB='\(b\)';$rxC='\(c\)';$rxD='\(d\)'
  $pa=[regex]::Match($text,$rxA); if(-not $pa.Success){return $null}
  $pb=[regex]::Match($text.Substring($pa.Index+3),$rxB);
  if(-not $pb.Success){return $null}; $pbI=$pa.Index+3+$pb.Index
  $pc=[regex]::Match($text.Substring($pbI+3),$rxC); if(-not $pc.Success){return $null}; $pcI=$pbI+3+$pc.Index
  $pd=[regex]::Match($text.Substring($pcI+3),$rxD); if(-not $pd.Success){return $null}; $pdI=$pcI+3+$pd.Index
  $stem=$text.Substring(0,$pa.Index).Trim()
  $oa=$text.Substring($pa.Index+3,$pbI-($pa.Index+3)).Trim()
  $ob=$text.Substring($pbI+3,$pcI-($pbI+3)).Trim()
  $oc=$text.Substring($pcI+3,$pdI-($pcI+3)).Trim()
  $od=$text.Substring($pdI+3).Trim()
  return [pscustomobject]@{stem=$stem;options=@($oa,$ob,$oc,$od)}
}

# --- stem/subs splitter ---
function SplitStem($ss){
  $ss=$ss.Trim()
  if($ss -match 'Match List'){
    return @{stem=$ss;subs=@()}
  } elseif($ss -match 'Statement\s+I\b'){
    $i=$ss.IndexOf('Statement I')
    $stem=$ss.Substring(0,$i).Trim()
    $rest=$ss.Substring($i)
    $arr=[regex]::Split($rest,'(?=Statement\s+II\b)') | ForEach-Object{$_.Trim()} | Where-Object{$_}
    if(-not $stem){$stem='Consider the following statements:'}
    return @{stem=$stem;subs=@($arr)}
  } elseif($ss -match '\s[1-9]\.\s'){
    $m=[regex]::Match($ss,'\s[1-9]\.\s')
    $stem=$ss.Substring(0,$m.Index).Trim()
    $rest=$ss.Substring($m.Index)
    $arr=[regex]::Split($rest,'\s(?=[1-9]\.\s)') | ForEach-Object{$_.Trim()} | Where-Object{$_}
    return @{stem=$stem;subs=@($arr)}
  } else {
    return @{stem=$ss;subs=@()}
  }
}

# --- parse answer DOCX (line-by-line: each entry is one paragraph; avoids header bleed) ---
$ansMap=@{}
$ansLineRx='^Q\.\d+\D{1,5}?\(CDS\s+(\d{4})-([I12]+),\s*Q\.(\d+)\)\s*Correct Answer:\s*(.*?)\s*Explanation:\s*(.*)$'
foreach($line in (Get-Content "$SCR\histans.txt" -Encoding UTF8)){
  $lm=[regex]::Match($line,$ansLineRx)
  if(-not $lm.Success){continue}
  $apaper=$lm.Groups[1].Value+'-'+(NormPaper $lm.Groups[2].Value)
  $aqno=[int]$lm.Groups[3].Value
  $araw=$lm.Groups[4].Value.Trim()
  $expl=($lm.Groups[5].Value -replace '\s+',' ').Trim()
  $letter=''
  if($araw -match '^\(?([a-d])\)'){$letter=$Matches[1]}
  $ansMap["$apaper|$aqno"]=[pscustomobject]@{letter=$letter;raw=$araw;expl=$expl}
}

# --- build questions ---
$out=@()
$noOpt=@();$noAns=@();$badCount=@()
foreach($r in $raw){
  $so=SplitOptions $r.text
  if($null -eq $so){ $noOpt+=("$($r.paper) Q$($r.qno)"); continue }
  $sp=SplitStem $so.stem
  $key="$($r.paper)|$($r.qno)"
  $a=$ansMap[$key]
  $ans='';$expl=''
  if($a){$ans=$a.letter;$expl=$a.expl} else {$noAns+=$key}
  $sess=($r.paper -split '-')[1]
  $out+=[pscustomobject]@{
    id="hist-$($r.paper)-q$($r.qno)"
    subject='History'
    topic=$r.part
    subtopic=$r.sub
    topicOriginal=$r.part
    year=[int]$r.year
    session=$sess
    paper="CDS $($r.paper)"
    qno=$r.qno
    ref="CDS $($r.paper), Q.$($r.qno)"
    stem=$sp.stem; subs=$sp.subs; options=$so.options
    answer=$ans; explanation=$expl; defective=$false
  }
}

# --- apply the 11 fact-check corrections (overrides by paper|qno) ---
$corr=@{
 '2018-II|81'=@{letter='d';expl="Correct answer: brick and stone (option d). Jean-Baptiste Tavernier recorded that, unlike other towns where houses were of mud and thatch, the majority of houses in Varanasi (Benares) were built of brick and stone."}
 '2025-I|31'=@{letter='d';expl="Correct answer: Jyotisha (option d). Per the Ain-i Akbari, Akbar prescribed specific Indian sciences for Hindu scholars to learn, and Jyotisha (astronomy/astrology) was explicitly listed among them."}
 '2025-I|41'=@{letter='d';expl="Repeated question (same as Q.31): the correct answer is Jyotisha (option d), listed in the Ain-i Akbari among the Indian sciences Akbar prescribed for scholars."}
 '2025-II|66'=@{letter='c';expl="Only Statement 3 is correct (option c) - Sarojini Naidu led a delegation to London demanding female franchise. Statement 1 is false: Stri Purush Tulana (A Comparison Between Women and Men) was written by Tarabai Shinde, not Pandita Ramabai. Statement 2 is also incorrect."}
 '2025-II|56'=@{letter='';defective=$true;expl="[Defective / OCR issue] The correct chronological order is Dandi March (3) > Gandhi-Irwin Pact (1) > Second Round Table Conference (4) > Muslim League's Pakistan Resolution (2) = 3, 1, 4, 2. This exact sequence is missing from the printed options, so the question cannot be answered as transcribed; verify against the original paper."}
 '2024-II|69'=@{letter='';defective=$true;expl="[Defective / OCR issue] All four statements about the Cabinet Mission Plan (1946) are historically correct (1, 2, 3 and 4). The transcribed options only offer pairings (e.g. '1 and 2', '3 and 4'), so the correct answer '1, 2, 3 and 4' is not available; verify against the original paper."}
 '2024-I|81'=@{letter='';defective=$true;expl="[Defective / OCR issue] Statements 1 and 3 are correct, but Statement 2 is false - the Industrial Revolution began in Britain, not Germany. The correct combination '1 and 3 only' is not offered among the transcribed options; verify against the original paper."}
 '2023-II|73'=@{expl="Abdur Razzaq, the Persian ambassador, was sent to Calicut, but the fortifications that left him deeply impressed - the famous concentric lines of forts - were those of Vijayanagara, not Calicut. The keyed answer follows the paper's option wording (fortifications); note this nuance from the NCERT account."}
 '2023-II|85'=@{expl="The Katapayadi numeral system (Vararuchi) was used to compute the Moon's position (1), and Achyuta Pisharati wrote Uparagakriyakrama on eclipses (2). Statement 3 - that King Ravi Varma set up an observatory and inaugurated the Kollam era - is not supported by the established historical record. Hence 1 and 2 only (option c)."}
 '2024-I|91'=@{expl="Rana Kumbha of Mewar wrote a commentary on Jayadeva's Gita Govinda (1) and composed dramas using regional languages (2). On (3): the Tower of Victory he built at Chittorgarh to commemorate his victory over Malwa is the Vijaya Stambha; the Kirti Stambha there is an older Jain tower dedicated to Adinath. Taking the tower attribution broadly, all three are treated as correct (option a)."}
 '2020-II|20'=@{expl="Dr. M.S. Aney, as Leader of the House in the Viceroy's Executive Council, moved the procedural motion for the secret sitting session of the Central Legislative Assembly in 1942. (Verified.)"}
}
$applied=0
foreach($x in $out){
  $key="$($x.year)-$($x.session)|$($x.qno)"
  if($corr.ContainsKey($key)){
    $c=$corr[$key]
    if($c.ContainsKey('letter')){ $x.answer=$c.letter }
    if($c.ContainsKey('defective')){ $x.defective=$c.defective }
    if($c.ContainsKey('expl')){ $x.explanation=$c.expl }
    $applied++
  }
}
Write-Output ("Corrections applied: $applied of $($corr.Count)")

# (empty options from source OCR gaps are left blank: browse skips them, quiz excludes the question)
# any question without a usable answer letter is treated as defective (UI badges it; quiz excludes it)
foreach($x in $out){ if($x.answer -eq ''){ $x.defective=$true } }

Write-Output ("RAW blocks: "+$raw.Count)
Write-Output ("Parsed questions: "+$out.Count)
Write-Output ("No-option (skipped): "+$noOpt.Count); $noOpt | ForEach-Object{" skip $_"}
Write-Output ("No-answer-match: "+$noAns.Count); $noAns | Select-Object -First 20 | ForEach-Object{" noans $_"}
Write-Output "--- per part ---"
$out | Group-Object topic | Sort-Object Name | ForEach-Object{ "{0,-16} {1}" -f $_.Name,$_.Count }
Write-Output "--- answer-letter vs key correct-option text (parse validation) ---"
$mism=@()
foreach($x in $out){
  $key="$($x.year)-$($x.session)|$($x.qno)"
  if($corr.ContainsKey($key)){continue}
  if($x.answer -eq ''){continue}
  $a=$ansMap[$key]; if(-not $a){continue}
  $optText=$x.options[[int][char]$x.answer - 97]
  $rawText=($a.raw -replace '^\(?[a-d]\)\s*','').Trim()
  $o=($optText -replace '[^a-zA-Z0-9]','').ToLower()
  $r=($rawText -replace '[^a-zA-Z0-9]','').ToLower()
  if($r.Length -ge 6 -and $o.Length -ge 3){
    $nn=[Math]::Min(14,[Math]::Min($o.Length,$r.Length))
    if($o.Substring(0,$nn) -ne $r.Substring(0,$nn)){ $mism+=("$($x.year) Q$($x.qno) ans=$($x.answer): opt='"+$optText.Substring(0,[Math]::Min(34,$optText.Length))+"' | key='"+$rawText.Substring(0,[Math]::Min(34,$rawText.Length))+"'") }
  }
}
Write-Output ("mismatches: "+$mism.Count)
$mism | Select-Object -First 50 | ForEach-Object{ " MISM $_" }
Write-Output "--- option-count sanity (should all be 4 nonempty unless flagged) ---"
$emptyOpt=$out | Where-Object{ ($_.options | Where-Object{$_ -eq ''}).Count -gt 0 }
Write-Output ("questions with >=1 empty option: "+$emptyOpt.Count)
$emptyOpt | ForEach-Object{ " empty-opt $($_.year) Q$($_.qno)" }

# write final subject file (full schema, UTF-8 no BOM)
$outPath="$proj\docs\data\history.json"
$json=$out | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($outPath,$json,(New-Object System.Text.UTF8Encoding($false)))
Write-Output "WROTE $outPath ($($out.Count) questions)"
