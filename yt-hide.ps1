param(
    [Parameter(Mandatory = $true)]
    [long]$Handle
)

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class Win32 {

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(
        IntPtr hWnd,
        int nCmdShow
    );

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(
        IntPtr hWnd
    );

    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(
        IntPtr hWnd,
        int id,
        uint fsModifiers,
        uint vk
    );

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(
        IntPtr hWnd,
        int id
    );

    [DllImport("user32.dll")]
    public static extern int GetMessage(
        out MSG lpMsg,
        IntPtr hWnd,
        uint wMsgFilterMin,
        uint wMsgFilterMax
    );

    [StructLayout(LayoutKind.Sequential)]
    public struct MSG {
        public IntPtr hwnd;
        public uint message;
        public IntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public int pt_x;
        public int pt_y;
    }
}
"@

$SW_HIDE = 0
$SW_SHOW = 5

$MOD_CONTROL = 0x0002
$VK_H = 0x48

$WM_HOTKEY = 0x0312
$HOTKEY_ID = 12345

# ============================================================
# VENSTER
# ============================================================

$hwnd = [IntPtr]$Handle

if ($hwnd -eq [IntPtr]::Zero) {
    exit
}

# ============================================================
# HOTKEY
# ============================================================

if (![Win32]::RegisterHotKey(
    [IntPtr]::Zero,
    $HOTKEY_ID,
    $MOD_CONTROL,
    $VK_H
)) {
    exit
}

# ============================================================
# DIRECT VERBERGEN
# ============================================================

[Win32]::ShowWindow(
    $hwnd,
    $SW_HIDE
) | Out-Null

# ============================================================
# WACHT OP CTRL + H
# ============================================================

try {

    $msg = New-Object Win32+MSG

    while ([Win32]::GetMessage(
        [ref]$msg,
        [IntPtr]::Zero,
        0,
        0
    ) -gt 0) {

        if (
            $msg.message -eq $WM_HOTKEY -and
            $msg.wParam.ToInt32() -eq $HOTKEY_ID
        ) {

            [Win32]::ShowWindow(
                $hwnd,
                $SW_SHOW
            ) | Out-Null

            [Win32]::SetForegroundWindow(
                $hwnd
            ) | Out-Null

            break
        }
    }

}
finally {

    [Win32]::UnregisterHotKey(
        [IntPtr]::Zero,
        $HOTKEY_ID
    ) | Out-Null
}