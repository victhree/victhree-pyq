# Parses CDS Polity PDF text + DOCX answer key -> docs/data/polity.json
# Inputs (scratchpad): pol.txt (pdftotext -layout), polans.txt (docx->text)
$ErrorActionPreference = 'Stop'
$root = 'C:\Users\ASUS\victhree-pyq'
$SCR  = 'C:\Users\ASUS\AppData\Local\Temp\claude\C--Users-ASUS\c7806228-5ef8-41a1-94b6-53d5ffb50a73\scratchpad'

# ---------- repair map (space/ligature corruption from PDF extraction) ----------
$repairs = @(
  @('aimingflat','aiming at'),@('aimsflat','aims at'),@('andflat','and at'),@('Benchflat','Bench at'),
  @('bothflat','both at'),@('Conferenceflat','Conference at'),@('consumptionflat','consumption at'),
  @('curriculumflat','curriculum at'),@('existingflat','existing at'),@('fundsflat','funds at'),
  @('Gandhiflat','Gandhi at'),@('Inquiryflat','Inquiry at'),@('isflat','is at'),
  @('jurisdictionflat','jurisdiction at'),@('locatedflat','located at'),@('Ordinanceflat','Ordinance at'),
  @('Panchayatsflat','Panchayats at'),@('taxedflat','taxed at'),@('toiletflat','toilet at'),
  @('hisflown','his own'),@('itsflown','its own'),@('theirflown','their own'),@('toflown','to own'),
  @('the eld','the field'),@('thefirst','the first'),@('offirst','of first'),
  @('declarefinancial','declare financial'),@('everyfinancial','every financial'),
  @('introducedfirst','introduced first'),@('minoritiesfind','minorities find'),@('opportunityfind','opportunity find'),
  @('full- edged','full-fledged'),@('its rst','its first'),@('191f','19(1)(f)')
)
function Repair([string]$s){
  if([string]::IsNullOrEmpty($s)){return $s}
  foreach($p in $repairs){
    $pat = '(?<![A-Za-z])' + [regex]::Escape($p[0]) + '(?![A-Za-z])'
    $s = [regex]::Replace($s, $pat, $p[1])
  }
  return $s
}

# ---------- taxonomy: 14 topics; subtopics derived from the TOC ----------
$polTopics = @(
 'Historical Constitutional Development','Constitutional Framework','Fundamental Rights, Duties & DPSPs',
 'Union Executive','Parliament','Judiciary','Federalism & State Government','Local Government',
 'Constitutional & Statutory Bodies','Elections & Representation','Emergency & Special Provisions',
 'Governance & Public Policy','Amendments, Committees & Commissions','International & Comparative Polity'
)
$topicSet=@{}; foreach($t in $polTopics){ $topicSet[$t]=$true }

$allLines = Get-Content "$SCR\pol.txt" -Encoding UTF8
# locate TOC bounds and build subtopic->topic from it
$tocStart=0;$tocEnd=0
for($i=0;$i -lt $allLines.Count;$i++){ if($allLines[$i] -match 'Table of Contents'){ $tocStart=$i; break } }
for($i=$tocStart;$i -lt $allLines.Count;$i++){ if($allLines[$i] -match 'Polity Questions -- Topic-wise'){ $tocEnd=$i; break } }
$subToTopic=[ordered]@{}
$curT=''
for($i=$tocStart;$i -lt $tocEnd;$i++){
  $name = ($allLines[$i] -replace '\s*\.*\s*\d+\s*$','').Trim()
  if($name -eq '' ){ continue }
  if($name -match 'Table of Contents|Each topic shows|first question begins|Appendix --'){ continue }
  if($topicSet.ContainsKey($name)){ $curT=$name; continue }
  if($curT -ne ''){ $subToTopic[$name]=$curT }
}
$subSet=@{}; foreach($k in $subToTopic.Keys){ $subSet[$k]=$true }
Write-Host ("Topics: "+$polTopics.Count+"  Subtopics mapped: "+$subToTopic.Count)

# ---------- parse answer key (docx text): 'Q.N - (CDS YYYY-P, Q.N) Correct Answer: a) .. Explanation: ..' ----------
$ansMap=@{}
$ansRx='^Q\.\d+\D{1,6}?\(CDS\s*(\d{4})-([I12]+),\s*Q\.(\d+)\)\s*Correct Answer:\s*(.*?)\s*Explanation:\s*(.*)$'
foreach($l in (Get-Content "$SCR\polans.txt" -Encoding UTF8)){
  $m=[regex]::Match($l,$ansRx); if(-not $m.Success){ continue }
  $sess=$m.Groups[2].Value; if($sess -eq '1'){$sess='I'} elseif($sess -eq '2'){$sess='II'}
  $yp=$m.Groups[1].Value+'-'+$sess; $qn=[int]$m.Groups[3].Value
  $ansText=$m.Groups[4].Value.Trim(); $expl=($m.Groups[5].Value -replace '\s+',' ').Trim()
  $letter=''; $lm=[regex]::Match($ansText,'^\(?([a-d])\)'); if($lm.Success){ $letter=$lm.Groups[1].Value }
  $ansMap["$yp|$qn"]=[pscustomobject]@{ letter=$letter; text=$ansText; expl=$expl }
}
Write-Host ("Answer entries parsed: "+$ansMap.Count)

# ---------- parse PDF questions ----------
$lines=$allLines
$startIdx=0
for($i=0;$i -lt $lines.Count;$i++){ if($lines[$i] -match 'Each question is preserved in its original wording'){ $startIdx=$i+1; break } }
$endIdx=$lines.Count
for($i=$startIdx;$i -lt $lines.Count;$i++){ if($lines[$i] -match 'Per-paper Question Summary|Per-topic question count|Per-topic Question Count'){ $endIdx=$i; break } }
Write-Host ("Body lines $startIdx..$endIdx")

$questions=New-Object System.Collections.ArrayList
$curTopic='';$curSub=''
$script:q=$null
function Finalize(){ if($null -ne $script:q){ [void]$script:questions.Add($script:q); $script:q=$null } }
$cdsRx='^\[CDS\s+(\d{4})-([I12]+),\s*Q\.(\d+)\]$'
$optRx='^([a-d])\)\s?(.*)$'
$subMarkerRx='^(\d+[\.\)]\s)|^([A-Z][\.\)]\s)|^(List\b|Code\b|Code:|Select\b|Consider\b|Match\b|Statement\b|Assertion\b|Reason\b|Choose\b|Given\b)'

for($i=$startIdx;$i -lt $endIdx;$i++){
  $t=$lines[$i].Trim()
  if($t -eq ''){ continue }
  if($t -match '^Page \d+ of 64$'){ continue }
  if($t -match '^VicThree Defence -- CDS Polity'){ continue }
  $cm=[regex]::Match($t,$cdsRx)
  if($cm.Success){
    Finalize
    $sess=$cm.Groups[2].Value; if($sess -eq '1'){$sess='I'} elseif($sess -eq '2'){$sess='II'}
    $yp=$cm.Groups[1].Value+'-'+$sess
    $script:q=[pscustomobject]@{
      year=[int]$cm.Groups[1].Value; session=$sess; paper="CDS $yp"; ypkey=$yp;
      qno=[int]$cm.Groups[3].Value; topicOrig=$curTopic; subtopic=$curSub;
      stem=''; subs=(New-Object System.Collections.ArrayList); opts=[ordered]@{}; _first=$true; _phase='stem'; _curOpt=$null
    }
    continue
  }
  if($subSet.ContainsKey($t)){ $curSub=$t; $curTopic=$subToTopic[$t]; continue }
  if($topicSet.ContainsKey($t)){ $curTopic=$t; continue }
  if($null -eq $script:q){ continue }
  $om=[regex]::Match($t,$optRx)
  if($om.Success){
    $L=$om.Groups[1].Value
    if(-not $script:q.opts.Contains($L)){ $script:q.opts[$L]=$om.Groups[2].Value; $script:q._curOpt=$L; $script:q._phase='opt'; $script:q._first=$false; continue }
  }
  if($script:q._first){ $script:q.stem=($t -replace '^\d+[\.\)]\s*',''); $script:q._first=$false; $script:q._phase='stem'; continue }
  if($script:q._phase -eq 'opt'){ $script:q.opts[$script:q._curOpt]=$script:q.opts[$script:q._curOpt]+' '+$t; continue }
  if($t -match $subMarkerRx){ [void]$script:q.subs.Add($t); $script:q._phase='subs'; continue }
  if($script:q._phase -eq 'subs'){ $n=$script:q.subs.Count-1; $script:q.subs[$n]=$script:q.subs[$n]+' '+$t; continue }
  $script:q.stem=($script:q.stem+' '+$t).Trim()
}
Finalize
Write-Host ("Questions parsed: "+$questions.Count)

# ---------- 17 user corrections (paper|qno) ----------
$corr=@{
 '2025-II|56'=@{letter='';defective=$true;expl="[Source / option defect] The correct chronological sequence is 3, 1, 4, 2 - Dandi March (3), Gandhi-Irwin Pact (1), Second Round Table Conference (4), Pakistan Resolution (2). The printed options do not contain this exact sequence, so it cannot be answered as transcribed."}
 '2024-II|69'=@{letter='';defective=$true;expl="[Source / option defect] All four Cabinet Mission statements are correct, so the answer should be 1, 2, 3 and 4 - but the printed options do not offer this combination (garbled / mis-transcribed option set)."}
 '2023-I|27'=@{letter='';defective=$true;expl="[Source / option defect] Certiorari requires both of the given conditions, but the printed options refer to a non-existent 'Statement 3' (garbled option set)."}
 '2021-II|76'=@{letter='';defective=$true;expl="[Defective question] The correct answer is the 38th Amendment, which made the Proclamation of Emergency immune from judicial review. The printed options do not include the 38th Amendment."}
 '2020-II|3'=@{letter='';defective=$true;expl="[Incomplete question] The source shows only 'Goods and Services Tax' with no complete question stem or options (formatting / extraction issue)."}
 '2018-II|103'=@{letter='a';defective=$true;expl="Answer retained as a) To discuss State matters. Note: the uploaded question wording is unclear/garbled (source-file issue), so treat with care rather than as a clean conceptual question."}
 '2021-II|74'=@{letter='';defective=$true;expl="[Defective framing] As printed there is no valid 'not correct' option. Statement a is factually true (Rajya Sabha representation of States is unequal and population-linked), and the other statements are also factually correct - so no option is actually 'not correct'."}
 '2019-I|105'=@{expl="Before the 2019 reorganisation, Article 19(1)(f) and Article 31(2) continued to apply to Jammu & Kashmir (the right to property survived there even after the 44th Amendment removed it elsewhere). DPSPs did not automatically extend to J&K, Article 35A operated under Article 370, and Article 368's amending power applied to J&K only with modifications."}
 '2025-I|90'=@{expl="Answer: d) Neither 1 nor 2. The Right to Work is a Directive Principle under Article 41 (not a Fundamental Right). The 86th Amendment inserted Article 21A (education as a Fundamental Right) and substituted Article 45 - it did not simply add the Right to Education to the DPSP chapter."}
 '2024-I|21'=@{expl="Answer: a) 1 only. The UDHR recognises the right to seek and enjoy asylum from persecution (statement 1, correct). On nationality, UDHR Article 15 bars arbitrary deprivation of nationality and denial of the right to change nationality - so the other statement is incorrectly framed."}
 '2020-II|19'=@{letter='c';expl="Answer: c) The Secretary-General works under the Speaker with delegated authority. The Secretary-General acts under authority in the name of the Speaker, so option d (Secretary-General passes orders in the name of the Speaker) should not be treated as false; option c is the weakest / not-correct wording."}
 '2020-II|74'=@{expl="Answer: b) 1 and 2 only. Parliamentary freedom of speech is not controlled by Article 19(1)(a); Article 105 protects speech and votes given in Parliament (not private speech outside it), and MPs do not enjoy general immunity from criminal prosecution."}
 '2023-II|89'=@{expl="Answer: a) Judicial Review. The Subhash Sharma case is more directly linked to judicial appointments and the independence of the judiciary; since 'independence of the judiciary' is not among the options, Judicial Review is the closest available answer."}
 '2023-I|92'=@{letter='c';defective=$true;expl="Intended answer: c) the post of Solicitor General of India is a constitutional post - which is itself the flawed statement, since the SGI is NOT a constitutional post. Note option a is also inaccurate if read strictly: the Attorney General (not the Solicitor General) is the chief legal adviser to the Government of India. So more than one option is flawed."}
 '2024-I|52'=@{letter='b';expl="Answer: b) 2. Statements 1 and 2 are correct; statement 3 is wrong - A.O. Hume's all-India body was not formed 'as a rival' to earlier organisations, nor specifically to represent poor/marginalised Indians."}
 '2023-II|33'=@{expl="Answer: d) Taxes on Petroleum and Petroleum Products (kept outside GST). Note: option a) Customs Duties is also somewhat ambiguous because basic customs duty lies outside GST; however, petroleum products remain the intended/keyed answer."}
 '2024-I|70'=@{expl="Answer: c) Precious metals are taxed at 1% under GST - this is the incorrect statement, since gold/precious metals are taxed at 3%, not 1%. (The statement on the 122nd/101st Amendment is loosely worded; unworked diamonds at 0.25% is correct.)"}
}

# ---------- build output, merge answers, repair, apply corrections ----------
$out=New-Object System.Collections.ArrayList
$noAnswer=New-Object System.Collections.ArrayList
$optMismatch=New-Object System.Collections.ArrayList
$noTopic=New-Object System.Collections.ArrayList
foreach($q in $questions){
  $opts=@(); foreach($L in @('a','b','c','d')){ if($q.opts.Contains($L)){ $opts+=(Repair (($q.opts[$L]).Trim())) } else { $opts+='' } }
  $subsArr=@(); foreach($s in $q.subs){ $subsArr+=(Repair $s.Trim()) }
  $ans=$ansMap["$($q.ypkey)|$($q.qno)"]
  $answer='';$expl=''
  if($ans){ $answer=$ans.letter; $expl=$ans.expl } else { [void]$noAnswer.Add("$($q.paper) Q.$($q.qno)") }
  if($q.topicOrig -eq ''){ [void]$noTopic.Add("$($q.paper) Q.$($q.qno)") }
  # QA: validate option text vs key correct-option text (pre-correction)
  if($ans -and $ans.letter -ne ''){
    $keyTxt=($ans.text -replace '^\(?[a-d]\)\s*','')
    $idx=[int][char]$ans.letter-[int][char]'a'
    if($idx -ge 0 -and $idx -lt 4){
      $a=(($opts[$idx]) -replace '[^A-Za-z0-9]','').ToLower(); $b=($keyTxt -replace '[^A-Za-z0-9]','').ToLower()
      if($a.Length -ge 4 -and $b.Length -ge 4){ $ml=[Math]::Min(12,[Math]::Min($a.Length,$b.Length)); if($a.Substring(0,$ml) -ne $b.Substring(0,$ml)){ [void]$optMismatch.Add("$($q.paper) Q.$($q.qno) [$($ans.letter)] pdf='$($opts[$idx])' key='$keyTxt'") } }
    }
  }
  $defective=$false
  $key="$($q.ypkey)|$($q.qno)"
  if($corr.ContainsKey($key)){
    $c=$corr[$key]
    if($c.ContainsKey('letter')){ $answer=$c.letter }
    if($c.ContainsKey('expl')){ $expl=$c.expl }
    if($c.ContainsKey('defective')){ $defective=$c.defective }
  }
  if($answer -eq ''){ $defective=$true }
  $obj=[ordered]@{
    id="pol-$($q.ypkey)-q$($q.qno)"; subject='Polity'; topic=$q.topicOrig; subtopic=$q.subtopic; topicOriginal=$q.topicOrig;
    year=$q.year; session=$q.session; paper=$q.paper; qno=$q.qno; ref="$($q.paper), Q.$($q.qno)";
    stem=(Repair $q.stem.Trim()); subs=$subsArr; options=$opts; answer=$answer; explanation=$expl; defective=$defective
  }
  [void]$out.Add([pscustomobject]$obj)
}

$json=$out | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText("$root\docs\data\polity.json",$json,(New-Object System.Text.UTF8Encoding($false)))

# ---------- QA ----------
Write-Host "`n===== QA ====="
Write-Host ("Total: "+$out.Count+"  Answered: "+($out|?{$_.answer -ne ''}).Count+"  Defective: "+($out|?{$_.defective}).Count)
Write-Host ("Missing from key: "+$noAnswer.Count); $noAnswer | ForEach-Object{ Write-Host "   MISS $_" }
Write-Host ("Blank topic: "+$noTopic.Count); $noTopic | Select-Object -First 20 | ForEach-Object{ Write-Host "   NOTOPIC $_" }
Write-Host ("<4 options: "+($out|?{ ($_.options|?{$_ -ne ''}).Count -lt 4 }).Count)
($out|?{ ($_.options|?{$_ -ne ''}).Count -lt 4 }) | ForEach-Object{ Write-Host ("   FEWOPTS $($_.ref) -> "+($_.options|?{$_ -ne ''}).Count+" opts | def=$($_.defective)") }
Write-Host ("Opt/key mismatches: "+$optMismatch.Count); $optMismatch | Select-Object -First 50 | ForEach-Object{ Write-Host "   MISM $_" }
$corrApplied=0; foreach($k in $corr.Keys){ $p,$n=$k -split '\|'; $yr=[int](($p -split '-')[0]); $se=($p -split '-')[1]; if($out|?{$_.year -eq $yr -and $_.session -eq $se -and $_.qno -eq [int]$n}){ $corrApplied++ } }
Write-Host ("Corrections matched to questions: $corrApplied / "+$corr.Count)
Write-Host "`n--- per topic ---"
$out | Group-Object topic | Sort-Object Name | ForEach-Object{ Write-Host ("{0,-42} {1}" -f $_.Name,$_.Count) }
Write-Host ("`nJSON bytes: "+(Get-Item "$root\docs\data\polity.json").Length)
