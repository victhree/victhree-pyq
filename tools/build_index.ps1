# Scans docs/data/*.json (subject files) and rebuilds docs/data/index.json manifest.
# Re-run this whenever you add or update a subject file.
$ErrorActionPreference='Stop'
$root='C:\Users\ASUS\victhree-pyq'
$dataDir="$root\docs\data"

# preferred subject order (others appended alphabetically)
$subjectOrder=@('Geography','History','Polity','Economics','General Science','English','Current Affairs','Elementary Mathematics')
# bucket display order per subject (extend as needed)
$bucketOrder=@('Physical Geography','Climatology & Oceanography','Environmental Geography & Sustainability','Indian Geography','World & Regional Geography','Human, Economic & Agricultural Geography','Miscellaneous & Mapping',
 'Ancient India','Medieval India','Modern India','World History',
 'Historical Constitutional Development','Constitutional Framework','Fundamental Rights, Duties & DPSPs','Union Executive','Parliament','Judiciary','Federalism & State Government','Local Government','Constitutional & Statutory Bodies','Elections & Representation','Emergency & Special Provisions','Governance & Public Policy','Amendments, Committees & Commissions','International & Comparative Polity')

$files = Get-ChildItem $dataDir -Filter *.json | Where-Object { $_.Name -ne 'index.json' }
$subjects=@()
$allYears=@()
$grandTotal=0; $grandAnswered=0
foreach($f in $files){
  $qs = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
  if(-not $qs){ continue }
  $name = ($qs | Select-Object -First 1).subject
  $count = $qs.Count
  $answered = ($qs | Where-Object {$_.answer -ne ''}).Count
  $grandTotal += $count; $grandAnswered += $answered

  # topics with counts (ordered)
  $topicGroups = $qs | Group-Object topic
  $topics=@()
  foreach($t in $bucketOrder){ $g=$topicGroups|Where-Object{$_.Name -eq $t}; if($g){ $topics += [ordered]@{name=$t;count=$g.Count} } }
  foreach($g in ($topicGroups | Sort-Object Name)){ if($bucketOrder -notcontains $g.Name){ $topics += [ordered]@{name=$g.Name;count=$g.Count} } }

  # subtopics per topic (for optional nested use)
  $subtopics=@{}
  foreach($g in ($qs | Group-Object topic)){
    $subtopics[$g.Name] = @($g.Group | Group-Object subtopic | Sort-Object Name | ForEach-Object { [ordered]@{name=$_.Name;count=$_.Count} })
  }

  # papers sorted chronologically (year, then I before II)
  $papers = $qs | Group-Object paper | ForEach-Object {
    $n=$_.Name; $yr=[int]($n -replace '\D',''); $sess= if($n -match '-II$'){2}else{1}
    [pscustomobject]@{ name=$n; count=$_.Count; yr=$yr; sess=$sess }
  } | Sort-Object yr,sess
  $papersOut = @($papers | ForEach-Object { [ordered]@{name=$_.name;count=$_.count} })

  $yrs = $qs | ForEach-Object {$_.year}
  $allYears += $yrs
  $ymin=($yrs|Measure-Object -Minimum).Minimum; $ymax=($yrs|Measure-Object -Maximum).Maximum

  $subjects += [ordered]@{
    key = ($f.BaseName)
    name = $name
    file = "data/$($f.Name)"
    count = $count
    answered = $answered
    yearMin = $ymin
    yearMax = $ymax
    topics = $topics
    subtopics = $subtopics
    papers = $papersOut
  }
}

# order subjects
$subjectsSorted=@()
foreach($s in $subjectOrder){ $m=$subjects|Where-Object{$_.name -eq $s}; if($m){ $subjectsSorted+=$m } }
foreach($s in ($subjects|Sort-Object {$_.name})){ if($subjectOrder -notcontains $s.name){ $subjectsSorted+=$s } }

$gymin=($allYears|Measure-Object -Minimum).Minimum; $gymax=($allYears|Measure-Object -Maximum).Maximum
$manifest=[ordered]@{
  brand='VicThree Defence'
  owner='by Anmol Sharma'
  tagline='CDS Previous Year Questions — Topic-wise'
  updated=''
  totals=[ordered]@{ questions=$grandTotal; answered=$grandAnswered; subjects=$subjectsSorted.Count; yearMin=$gymin; yearMax=$gymax }
  subjects=$subjectsSorted
}
$json = $manifest | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText("$dataDir\index.json",$json,(New-Object System.Text.UTF8Encoding($false)))
Write-Host "index.json written."
Write-Host ("Subjects: "+$subjectsSorted.Count+" | Questions: "+$grandTotal+" | Answered: "+$grandAnswered+" | Years: $gymin-$gymax")
foreach($s in $subjectsSorted){ Write-Host ("  - "+$s.name+": "+$s.count+" Qs, "+$s.topics.Count+" topics, "+$s.papers.Count+" papers") }
