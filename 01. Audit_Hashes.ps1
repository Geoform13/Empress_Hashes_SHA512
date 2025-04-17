param (
    [string]$modo
)

function Prompt-Senha {
    param ([string]$mensagem)
    $secure = Read-Host $mensagem -AsSecureString
    $marshal = [Runtime.InteropServices.Marshal]
    $marshal::PtrToStringAuto($marshal::SecureStringToBSTR($secure))
}

function Derivar-Chave {
    param (
        [string]$senha,
        [string]$caminhoSalt,
        [bool]$gerarSalt = $false
    )

    if ($gerarSalt -or -not (Test-Path $caminhoSalt)) {
        $salt = New-Object byte[] 16
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($salt)
        [IO.File]::WriteAllBytes($caminhoSalt, $salt)
    } else {
        $salt = [IO.File]::ReadAllBytes($caminhoSalt)
    }

    $derivador = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($senha, $salt, 100000)
    $key = $derivador.GetBytes(32)
    return ,@($key, $salt)
}

function Gerar-Hash {
    param ([string]$senha)
    $dir = "D:\FOLDER"
    $saida_txt = "$dir\FOLDER_hashes_sha512.txt"
    $saida_json = "$dir\FOLDER_hashes_sha512.json"
    $salt_path = "$dir\salt.bin"
    $iv_path = "$dir\iv.bin"

    $iv = New-Object byte[] 16
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($iv)
    [IO.File]::WriteAllBytes($iv_path, $iv)

    $result = Derivar-Chave -senha $senha -caminhoSalt $salt_path -gerarSalt $true
    $key = $result[0]

    $hashes = @()

    Get-ChildItem -Path $dir -Recurse -File | ForEach-Object {
        $stream = [System.IO.File]::OpenRead($_.FullName)
        $sha512 = [System.BitConverter]::ToString(
            ([System.Security.Cryptography.SHA512]::Create()).ComputeHash($stream)
        ).Replace("-", "")
        $stream.Close()

        $nome_bytes = [System.Text.Encoding]::UTF8.GetBytes($_.Name)
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key
        $aes.IV = $iv
        $aes.Mode = 'CBC'
        $aes.Padding = 'PKCS7'
        $encryptor = $aes.CreateEncryptor()
        $nome_cifrado = $encryptor.TransformFinalBlock($nome_bytes, 0, $nome_bytes.Length)
        $nome_base64 = [Convert]::ToBase64String($nome_cifrado)

        $obj = [PSCustomObject]@{
            NomeCriptografado = $nome_base64
            SHA512 = $sha512
            Tamanho = $_.Length
            Criado = $_.CreationTimeUtc
            Modificado = $_.LastWriteTimeUtc
        }

        $hashes += $obj
    }

    $txt = "NomeCriptografado | SHA512 | Tamanho (bytes) | Criado | Modificado"
    $hashes | ForEach-Object {
        $txt += "`n$($_.NomeCriptografado) | $($_.SHA512) | $($_.Tamanho) | $($_.Criado) | $($_.Modificado)"
    }
    $txt | Out-File -FilePath $saida_txt
    $hashes | ConvertTo-Json -Depth 5 | Out-File -FilePath $saida_json

    Write-Host "Arquivos criptografados com sucesso em:"
    Write-Host "`t$saida_txt"
    Write-Host "`t$saida_json"
}

function Decifrar-Hash {
    param ([string]$senha)
    $entrada_json = "D:\FOLDER\FOLDER_hashes_sha512.json"
    $saida_txt = "C:\FOLDER\Decifrados\FOLDER_hashes_sha512.txt"
    $saida_json = "C:\FOLDER\Decifrados\FOLDER_hashes_sha512.json"
    $salt_path = "D:\FOLDER\salt.bin"
    $iv = [IO.File]::ReadAllBytes("D:\FOLDER\iv.bin")

    if (-not (Test-Path "C:\FOLDER\Decifrados")) {
        New-Item -ItemType Directory -Path "C:\FOLDER\Decifrados" | Out-Null
    }

    $result = Derivar-Chave -senha $senha -caminhoSalt $salt_path
    $key = $result[0]

    $json = Get-Content $entrada_json -Raw | ConvertFrom-Json
    $decifrados = @()
    $txt = "Nome | SHA512 | Tamanho (bytes) | Criado | Modificado"

    foreach ($item in $json) {
        $dados = [Convert]::FromBase64String($item.NomeCriptografado)
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key
        $aes.IV = $iv
        $aes.Mode = 'CBC'
        $aes.Padding = 'PKCS7'
        $decryptor = $aes.CreateDecryptor()
        $nome = [System.Text.Encoding]::UTF8.GetString($decryptor.TransformFinalBlock($dados, 0, $dados.Length))

        $obj = [PSCustomObject]@{
            Nome = $nome
            SHA512 = $item.SHA512
            Tamanho = $item.Tamanho
            Criado = $item.Criado
            Modificado = $item.Modificado
        }

        $txt += "`n$($nome) | $($item.SHA512) | $($item.Tamanho) | $($item.Criado) | $($item.Modificado)"
        $decifrados += $obj
    }

    $txt | Out-File -FilePath $saida_txt
    $decifrados | ConvertTo-Json -Depth 5 | Out-File -FilePath $saida_json

    Write-Host "Arquivos descriptografados com sucesso em:"
    Write-Host "`t$saida_txt"
    Write-Host "`t$saida_json"
}

# Execução interativa
if (-not $modo) {
    $modo = Read-Host "Digite o modo (criptografar / descriptografar)"
}
$modo = $modo.ToLower()

if ($modo -eq "criptografar") {
    $senha = Prompt-Senha "Digite a senha de criptografia"
    Gerar-Hash -senha $senha
}
elseif ($modo -eq "descriptografar") {
    $senha = Prompt-Senha "Digite a senha de descriptografia"
    Decifrar-Hash -senha $senha
}
else {
    Write-Host "Modo inválido. Use 'criptografar' ou 'descriptografar'."
}

Read-Host "`nPressione Enter para sair..."
