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

    TodoHotkey(string rainmeter)
    {
        this.rainmeter = rainmeter;
        ShowInTaskbar = false;
        CreateHandle();
        if (RegisterHotKey(Handle, 1, MOD_WIN | MOD_SHIFT | MOD_NOREPEAT, (uint)Keys.T)) Combo = "Win+Shift+T";
        else if (RegisterHotKey(Handle, 1, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, (uint)Keys.T)) Combo = "Strg+Alt+T";
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

    [STAThread]
    static void Main(string[] args)
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
            var f = new TodoHotkey(rm);
            // gewaehltes Kuerzel fuer Hilfe/Doku festhalten
            File.WriteAllText(Path.Combine(dir, "hotkey.txt"), f.Combo ?? "keins frei");
            if (f.Combo == null) return;
            Application.Run(f);
        }
    }
}
