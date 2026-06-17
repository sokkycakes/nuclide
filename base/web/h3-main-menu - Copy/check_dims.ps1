Add-Type -AssemblyName System.Drawing
Get-ChildItem 'D:\Steam\steamapps\common\H3EK\web_menu\assets' -File -Include *.png | ForEach-Object {
    try {
        $img = [System.Drawing.Image]::FromFile($_.FullName)
        "{0,-30} {1}x{2}" -f $_.Name, $img.Width, $img.Height
        $img.Dispose()
    } catch {
        "{0,-30} (cant read)" -f $_.Name
    }
}
Get-ChildItem 'D:\Steam\steamapps\common\H3EK\web_menu\assets\*.png' | ForEach-Object {
    try {
        $img = [System.Drawing.Image]::FromFile($_.FullName)
        "{0,-30} {1}x{2}" -f $_.Name, $img.Width, $img.Height
        $img.Dispose()
    } catch {
        "{0,-30} (cant read)" -f $_.Name
    }
}
