param([int]$Port=4178,[string]$Root='C:\Users\ASUS\victhree-pyq\docs')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue
$mime=@{ '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='application/javascript; charset=utf-8'; '.json'='application/json; charset=utf-8'; '.jpg'='image/jpeg'; '.jpeg'='image/jpeg'; '.png'='image/png'; '.svg'='image/svg+xml'; '.ico'='image/x-icon'; '.webp'='image/webp' }
$listener=New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Root at http://localhost:$Port/"
while($listener.IsListening){
  try{
    $ctx=$listener.GetContext()
    $path=[System.Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath)
    if($path -eq '/'){ $path='/index.html' }
    $file=Join-Path $Root ($path.TrimStart('/') -replace '/','\')
    if(Test-Path $file -PathType Leaf){
      $ext=[System.IO.Path]::GetExtension($file).ToLower()
      $ct= if($mime.ContainsKey($ext)){$mime[$ext]}else{'application/octet-stream'}
      $bytes=[System.IO.File]::ReadAllBytes($file)
      $ctx.Response.ContentType=$ct
      $ctx.Response.Headers.Add('Cache-Control','no-cache, no-store')
      $ctx.Response.ContentLength64=$bytes.Length
      $ctx.Response.OutputStream.Write($bytes,0,$bytes.Length)
    } else {
      $ctx.Response.StatusCode=404
      $msg=[System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $path")
      $ctx.Response.OutputStream.Write($msg,0,$msg.Length)
    }
    $ctx.Response.OutputStream.Close()
  }catch{ }
}
