.pragma library
// Farben wie in der Windows-Version (src/build-skin.ps1): dunkel, halbdurchsichtig, lila Akzent.
// Format #AARRGGBB.
var bg = "#DA0C0C12";        // Liste: 12,12,18 bei 218/255 Deckkraft
var formBg = "#EB0C0C12";    // Formular etwas deckender
var text = "#FFFFFFFF";
var done = "#F0AFAFBC";      // erledigt, Termine, Zaehler
var note = "#FFE8E8F0";      // Notizen
var box = "#FFC8C8D4";       // Rahmen des offenen Kaestchens
var check = "#FF8A6CF5";     // lila: abgehakt, Auswahl, Speichern
var accent = "#FFA5B9FF";    // Links, "+ Neuer Punkt"
var hover = "#16FFFFFF";
var over = "#FFFF7373";      // ueberfaellig
var today = "#FFFFB95A";     // heute faellig
var field = "#0EFFFFFF";     // Eingabefelder
var fieldBorder = "#28FFFFFF";
var chip = "#10FFFFFF";      // Knoepfe im Formular
var chipHover = "#1EFFFFFF";
var summaryBg = "#288A6CF5";
var danger = "#FFFF8C8C";

function dueColor(state) {
    if (state === "over") return over;
    if (state === "today") return today;
    return done;
}
