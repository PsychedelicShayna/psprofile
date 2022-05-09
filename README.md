# Shayna's PowerShell Extensions (SPSE)
This is my personal PowerShell profile, containing my own extensions and extension loader. The extension loader can be found in `spse-init.ps1`, which is intended to be imported from your PowerShell profile script (`Microsoft.PowerShell_profile.ps1`). Inside of `spse-init.ps1`, an object called `SPSEEnv` is defined - this object stores the configuration for the extension loader.

The `SPSEEnv` object is defined like this, and should have its values modified according to where the repository is stored on your computer:

```PowerShell
New-Variable -Name SPSEEnv -Value @{
    repositoryDirectory            = [String]"$HOME\Dropbox\Repositories\shaynas-powershell-extensions"
    repositoryExtensionsDirectory  = [String]"$HOME\Dropbox\Repositories\shaynas-powershell-extensions\extensions"
    enabledUserExtensionsDirectory = [String]"$HOME\shaynas-powershell-extensions\enabled-user-extensions\"
    loadedExtensions               = [Array]@()
}
```

The extension loader recognizes all `.ps1` PowerShell scripts within `repositoryExtensionsDirectory` to be "extensions", and it will consider the extension enabled if a symlink exists within `enabledUserExtensionsDirectory` that points to that extension. Upon startup, all symlinks within `enabledUserExtensionsDirectory` that point to `.ps1` files inside of `repositoryExtensionsDirectory` will be imported.

Extensions can be "enabled" or "disabled" using the `SPSE_SetExtensionEnabled` command, which will create or delete a symlink within `enabledUserExtensionsDirectory` for the given extension, like this:
```PowerShell
SPSE_SetExtensionEnabled Get-Weather.ps1 -Disable
```

Extensions and their state can be viewed using the `SPSE_GetExtensions` command, where the `-Pretty` switch can also be specified to prettify the output.

```PowerShell
➜ SPSE_GetExtensions -Pretty
--------------------------------------------------
[ E ] Encryption-Utilities.ps1
[ E ] Get-PublicIP.ps1
[ E ] Get-Weather.ps1
[ E ] OhMyPosh-Setup.ps1
[ D ] RegistryConsoleFontManager.ps1
[ E ] Set-TitlebarColor.ps1
```

When the `-Pretty` switch isn't used, an array of `PSCustomObject`'s is returned, which can have the following methods called on them: `.IsEnabled()`, `.Enable()`, `.Disable()` to be able to query and manage the state of the extensions programmatically.

Additionally, the state of a specific extension can be queried using the `SPSE_IsExtensionEnabled` command.

If for whatever reason, an extension is deleted from `repositoryExtensionsDirectory` without being disabled first, any lingering symlinks can be cleaned up using the `SPSE_RemoveZombieSymlinks` command.
