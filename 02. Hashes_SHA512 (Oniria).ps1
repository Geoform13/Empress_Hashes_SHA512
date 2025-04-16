$folder = "D:\²Oniria"  # Caminho mais simples para teste
$txtOut = Join-Path $folder "hashes_sha512.txt"
$jsonOut = Join-Path $folder "hashes_sha512.json"

"Arquivo | SHA512 | Tamanho (bytes) | Criado | Modificado" | Out-File $txtOut
$hashList = @()

Get-ChildItem -Path $folder -Recurse -File | ForEach-Object {
    $filePath = $_.FullName
    $hash = Get-FileHash -Path $filePath -Algorithm SHA512

    $relPath = $filePath.Substring($folder.Length).TrimStart('\','/')
    $size = $_.Length
    $created = $_.CreationTimeUtc.ToString("o")   # ISO 8601
    $modified = $_.LastWriteTimeUtc.ToString("o") # ISO 8601

    # Utilizando o Path.GetExtension para determinar tipo MIME
    $mime = [System.IO.Path]::GetExtension($_.Name).ToLower()

    "$($_.Name) | $($hash.Hash) | $size | $created | $modified" | Out-File $txtOut -Append

    $hashList += [pscustomobject]@{
        filename       = $_.Name
        relative_path  = $relPath
        full_path      = $filePath
        sha512         = $hash.Hash
        size_bytes     = $size
        created_utc    = $created
        modified_utc   = $modified
        extension      = $_.Extension
        mime_type      = $mime
    }
}

$hashList | ConvertTo-Json -Depth 3 | Out-File $jsonOut -Encoding UTF8

Write-Host ""
Write-Host "✅ Hashes gerados com todos os metadados:"
Write-Host "- TXT:   $txtOut"
Write-Host "- JSON:  $jsonOut"
