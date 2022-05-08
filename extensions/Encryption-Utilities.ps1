using namespace System.Security.Cryptography;
using namespace System.Text;

function AesCbcEncryptFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position=0)]
        [Alias("File", "In", "Input")]
        [String]
        $InputFile,

        [Parameter(Position=1)]
        [Alias("Out", "Output")]
        [String]
        $OutputFile,

        [Parameter(Mandatory, Position=2)]
        [Alias("Password")]
        [String]
        $Key,

        [Parameter()]
        [Alias("SameOutput", "Force")]
        [Switch]
        $Overwrite,

        [Parameter()]
        [Int32]
        $IvMask = 16,

        [Parameter()]
        [Alias("PaddingMode", "PadMode")]
        [PaddingMode]
        $Padding = [PaddingMode]::PKCS7,

        [Parameter()]
        [HashAlgorithm]
        $HashObject = [SHA256]::Create()
    )

    if($IvMask -lt 16) {
        Write-Error -ErrorAction Stop "Cannot accept a value less than 16 for parameter `"IvMask`", received $IvMask instead."
    }

    if(-not (Test-Path $InputFile -PathType Leaf)) {
        Write-Error -ErrorAction Stop "Invalid value for `"InputFile`" parameter, cannot find file `"$InputFile`""
    }

    if(-not $OutputFile) {
        if($Overwrite) {
            $OutputFile = $InputFile
        } else {
            Write-Error -ErrorAction Stop "The `"OutputFile`" parameter has no value, in order to overwrite the input file, use the -Overwrite switch."
        }
    }
    
    $input_file_bytes = Get-Content -Path $InputFile -ReadCount 0 -AsByteStream
    
    $encryption_input_bytes = [RandomNumberGenerator]::GetBytes($IvMask)
    $encryption_input_bytes += $input_file_bytes
    
    $key_digest = $HashObject.ComputeHash([Encoding]::UTF8.GetBytes($Key))

    $aes_object = [Aes]::Create()
    $aes_object.Mode = [CipherMode]::CBC
    $aes_object.GenerateIV()
    $aes_object.Key = $key_digest[0..31]

    $encrypted_bytes = $aes_object.IV + $aes_object.EncryptCbc($encryption_input_bytes, $aes_object.IV, $Padding)

    Set-Content -Path $OutputFile -AsByteStream -Value $encrypted_bytes
}

function AesCbcDecryptFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position=0)]
        [Alias("File", "In", "Input")]
        [String]
        $InputFile,

        [Parameter(Position=1)]
        [Alias("Out", "Output")]
        [String]
        $OutputFile,
        
        [Parameter(Mandatory, Position=2)]
        [Alias("Password")]
        [String]
        $Key,

        [Parameter()]
        [Alias("SameOutput", "Force")]
        [Switch]
        $Overwrite,

        [Parameter()]
        [Int32]
        $IvMask = 16,

        [Parameter()]
        [Alias("PaddingMode", "PadMode")]
        [PaddingMode]
        $Padding = [PaddingMode]::PKCS7,

        [Parameter()]
        [HashAlgorithm]
        $HashObject = [SHA256]::Create()
    )

    if($IvMask -lt 16) {
        Write-Warning -ErrorAction Continue "The value for the `"IvMask`" parameter is most likely incorrect, as a value less than 16 ($IvMask) does not make sense, and would not have been accepted by the corresponding encrypt function. $IvMask bytes will be stripped anyway."
    }

    if(-not (Test-Path $InputFile -PathType Leaf)) {
        Write-Error -ErrorAction Stop "Invalid value for the `"InputFile`" parameter, cannot find file `"$InputFile`""
    }

    if(-not $OutputFile) {
        if($Overwrite) {
            $OutputFile = $InputFile
        } else {
            Write-Error -ErrorAction Stop "The `"OutputFile`" parameter has no value, in order to overwrite the input file, use the -Overwrite switch."
        }
    }
    
    $key_digest = $HashObject.ComputeHash([Encoding]::UTF8.GetBytes($Key))

    $input_file_bytes = Get-Content -Path $InputFile -ReadCount 0 -AsByteStream

    $iv = $input_file_bytes[0..15]
    $input_file_bytes = $input_file_bytes[16..($input_file_bytes.length - 1)]

    $aes_object = [Aes]::Create()
    $aes_object.Mode = [CipherMode]::CBC
    $aes_object.Key = $key_digest[0..31]
    
    $decrypted_bytes = $aes_object.DecryptCbc($input_file_bytes, $iv, $Padding)
    $decrypted_bytes = $decrypted_bytes[($IvMask)..($decrypted_bytes.length - 1)]

    Set-Content -Path $OutputFile -AsByteStream -Value $decrypted_bytes
}