// TodoHotkey: globales Tastenkuerzel fuer "Neuer Punkt" der Rainmeter-Todo-Liste.
// Wartet unsichtbar auf Win+Shift+T (falls belegt: Strg+Alt+T) und oeffnet dann das Formular.
// Wird von Todo.ini beim Laden gestartet, laeuft nur einmal (Mutex).
// Aufruf: TodoHotkey.exe "<Pfad zu Rainmeter.exe>"
// Bauen: csc /target:winexe /out:TodoHotkey.exe hotkey.cs
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

class TodoHotkey : Form
{
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint mod, uint vk);
    [DllImport("user32.dll")] static extern bool AllowSetForegroundWindow(int pid);
    const uint MOD_ALT = 1, MOD_CONTROL = 2, MOD_SHIFT = 4, MOD_WIN = 8, MOD_NOREPEAT = 0x4000;
    const int WM_HOTKEY = 0x0312;

    readonly string rainmeter;
    public string Combo;

    // Waehlbare Kuerzel (Einstellungen-Fenster schreibt "Hotkey=<schluessel>" in prefs.inc)
    static readonly string[][] Choices = {
        new[] { "ctrl+alt+t", "Strg+Alt+T" },
        new[] { "win+shift+t", "Win+Shift+T" },
        new[] { "ctrl+shift+space", "Strg+Shift+Leertaste" },
        new[] { "ctrl+alt+n", "Strg+Alt+N" },
    };

    bool TryRegister(string key)
    {
        uint mod = MOD_NOREPEAT; uint vk = 0;
        foreach (var part in key.Split('+'))
        {
            switch (part)
            {
                case "ctrl": mod |= MOD_CONTROL; break;
                case "alt": mod |= MOD_ALT; break;
                case "shift": mod |= MOD_SHIFT; break;
                case "win": mod |= MOD_WIN; break;
                case "space": vk = (uint)Keys.Space; break;
                default: vk = (uint)(Keys)Enum.Parse(typeof(Keys), part.ToUpperInvariant()); break;
            }
        }
        return RegisterHotKey(Handle, 1, mod, vk);
    }

    TodoHotkey(string rainmeter, string wish)
    {
        this.rainmeter = rainmeter;
        ShowInTaskbar = false;
        CreateHandle();
        if (wish == "aus") { Combo = "aus"; return; }
        // gewuenschtes Kuerzel; ohne Wunsch (oder belegt) wie bisher: Win+Shift+T, sonst Strg+Alt+T
        foreach (var c in Choices)
            if (c[0] == wish && TryRegister(c[0])) { Combo = c[1]; return; }
        if (TryRegister("win+shift+t")) Combo = "Win+Shift+T";
        else if (TryRegister("ctrl+alt+t")) Combo = "Strg+Alt+T";
    }

    // "Hotkey=..." aus prefs.inc (UTF-16) lesen
    static string ReadWish(string dir)
    {
        try
        {
            foreach (var line in File.ReadAllLines(Path.Combine(dir, "prefs.inc")))
            {
                var l = line.Trim();
                if (l.StartsWith("Hotkey=", StringComparison.OrdinalIgnoreCase)) return l.Substring(7).Trim().ToLowerInvariant();
            }
        }
        catch { }
        return "";
    }

    // Fenster nie anzeigen
    protected override void SetVisibleCore(bool value) { base.SetVisibleCore(false); }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_HOTKEY)
        {
            // Rainmeter darf das Formular in den Vordergrund holen
            AllowSetForegroundWindow(-1);
            Process.Start(rainmeter, "!CommandMeasure MeasureTodo \"OpenDialog(0, 1)\" ObsidianTodo");
        }
        base.WndProc(ref m);
    }

    // ---------- Pruefung fuer den Installer: TodoHotkey.exe --check "<Fensterende>" ----------
    // Exitcode 0, wenn ein sichtbares Fenster existiert, dessen Titel so endet (Rainmeter benennt
    // Skin-Fenster nach dem Pfad der .ini), sonst 1. So muss der Installer nichts zur Laufzeit uebersetzen.
    delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc e, IntPtr p);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);

    static int CheckWindow(string end)
    {
        bool found = false;
        EnumWindows(delegate (IntPtr h, IntPtr p) {
            var sb = new System.Text.StringBuilder(512);
            GetWindowText(h, sb, 512);
            if (IsWindowVisible(h) && sb.ToString().EndsWith(end, StringComparison.OrdinalIgnoreCase)) found = true;
            return true;
        }, IntPtr.Zero);
        return found ? 0 : 1;
    }

    [STAThread]
    static int Main(string[] args)
    {
        if (args.Length >= 2 && args[0] == "--check") return CheckWindow(args[1]);
        Run(args);
        return 0;
    }

    static void Run(string[] args)
    {
        bool first;
        using (new Mutex(true, "ObsidianTodoHotkey", out first))
        {
            if (!first) return;
            string dir = Path.GetDirectoryName(Application.ExecutablePath);
            // Pfad zu Rainmeter.exe kommt von Todo.ini (#PROGRAMPATH#), sonst portables Layout annehmen
            string rm = args.Length > 0 && File.Exists(args[0])
                ? args[0]
                : Path.GetFullPath(Path.Combine(dir, @"..\..\..\Rainmeter.exe"));
            var f = new TodoHotkey(rm, ReadWish(dir));
            // gewaehltes Kuerzel fuer Hilfe/Einstellungen festhalten
            File.WriteAllText(Path.Combine(dir, "hotkey.txt"), f.Combo ?? "keins frei");
            // fuer das Einstellungen-Fenster (hebt das aktive Kuerzel hervor)
            File.WriteAllText(Path.Combine(dir, "hotkey.inc"), "[Variables]\r\nHotkeyNow=" + (f.Combo ?? "keins frei") + "\r\n", System.Text.Encoding.Unicode);
            if (f.Combo == null || f.Combo == "aus") return;
            Application.Run(f);
        }
    }
}
