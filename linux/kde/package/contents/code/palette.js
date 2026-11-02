.pragma library
// Farben wie in der Windows-Version (src/build-skin.ps1): dunkel, halbdurchsichtig, Akzentfarbe waehlbar.
// Format #AARRGGBB. Akzent und Deckkraft kommen aus den Einstellungen (Plasmoid.configuration).
var formBg = "#EB0C0C12";    // Formular/Einstellungen etwas deckender
var text = "#FFFFFFFF";
var done = "#F0AFAFBC";      // erledigt, Termine, Zaehler
var note = "#FFE8E8F0";      // Notizen
var box = "#FFC8C8D4";       // Rahmen des offenen Kaestchens
var hover = "#16FFFFFF";
var over = "#FFFF7373";      // ueberfaellig
var today = "#FFFFB95A";     // heute faellig
var field = "#0EFFFFFF";     // Eingabefelder
var fieldBorder = "#28FFFFFF";
var chip = "#0EFFFFFF";      // Knoepfe (wie im Windows-Einstellungen-Fenster)
var chipHover = "#28FFFFFF";
var chipStroke = "#26FFFFFF";
var btnFill = "#EB16161E";   // Symbol-Knoepfe (Zahnrad, Pfeil, Bueroklammer): dunkel und deckend
var btnHover = "#F530303E";
var btnStroke = "#30FFFFFF";
var danger = "#FFFF8C8C";

// Akzentfarben: [Kaestchen/Knoepfe, Links/Ueberschriften]
var ACCENTS = {
    lila: ["#FF8A6CF5", "#FFA5B9FF"],
    blau: ["#FF3C82F0", "#FF8CBEFF"],
    gruen: ["#FF32AA64", "#FF8CDCAA"],
    orange: ["#FFEB8728", "#FFFFC382"],
    rot: ["#FFDC4646", "#FFFFA0A0"],
    pink: ["#FFDC50A5", "#FFFFA5D7"]
};
var ACCENT_NAMES = ["lila", "blau", "gruen", "orange", "rot", "pink"];
function check(name) { return (ACCENTS[name] || ACCENTS.lila)[0]; }
function accent(name) { return (ACCENTS[name] || ACCENTS.lila)[1]; }
// Akzent halbdurchsichtig (Zusammenfassung im Formular)
function soft(name) { return "#28" + check(name).substring(3); }
// Hintergrund der Liste: 12,12,18 mit waehlbarer Deckkraft
function bg(opacity) {
    var a = Math.max(0, Math.min(255, opacity | 0)).toString(16);
    return "#" + (a.length < 2 ? "0" + a : a) + "0C0C12";
}

function dueColor(state) {
    if (state === "over") return over;
    if (state === "today") return today;
    return done;
}
