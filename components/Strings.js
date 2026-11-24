.pragma library
// Greeter copy in English and Spanish (Rioplatense voseo, like the rest of
// HorneroOS). The greeter runs before any session, so it picks the language
// from the system locale SDDM runs with (Qt.locale()), unless theme.conf
// sets language=en|es. Every key exists in both tables
// (tests/test_strings.py); a missing key falls back to English, then to
// the key itself, so a gap is visible instead of blank.
//
// Voice rules (shell Microcopy, visual language §17.3): short, no
// exclamation marks, no emoji, nothing that blames the user, and never the
// only carrier of state (errors also carry a glyph and an alert colour).

var EN = {
    "eyebrow.signIn": "01 · SIGN IN",
    "eyebrow.channels": "CHANNELS",
    "eyebrow.power": "POWER",
    "channel": "CH",
    "channel.other": "Other",
    "channel.otherHint": "Type a name",
    "user": "User",
    "password": "Password",
    "passwordFor": "Password · %1",
    "session": "Session",
    "layout": "Layout",
    "login": "Log in",
    "signingIn": "Signing in…",
    "noResponse": "No answer from the display manager yet. Try again.",
    "loginFailed": "That password did not work. Try again.",
    "loginFailedCount": "That password did not work (attempt %1). Try again.",
    "capsLock": "Caps Lock is on.",
    "noSessions": "No desktop sessions are installed. Ask your administrator.",
    "noUser": "Type a user name first.",
    "suspend": "Suspend",
    "restart": "Restart",
    "shutdown": "Shut down",
    "keyboard": "Keyboard",
    "cancel": "Cancel",
    "confirm.suspend": "Suspend the computer now?",
    "confirm.restart": "Restart the computer now?",
    "confirm.shutdown": "Shut down the computer now?",
    "secondary": "SIGN IN ON THE MAIN DISPLAY",
    "greeting.morning": "Good morning. The lamp is on",
    "greeting.afternoon": "Good afternoon. Tea is warm",
    "greeting.evening": "Good evening. Settle in",
    "greeting.night": "Late shift. Dim lights, steady hands",
    "greetingPlain.morning": "Good morning",
    "greetingPlain.afternoon": "Good afternoon",
    "greetingPlain.evening": "Good evening",
    "greetingPlain.night": "Good night",
    "zone": "ZONE",
    "out": "OUT",
    "a11y.username": "User name",
    "a11y.usernameHelp": "Type the account name to sign in with",
    "a11y.password": "Password",
    "a11y.passwordHelp": "Type the password for %1",
    "a11y.channels": "User accounts",
    "a11y.channelsHelp": "Left and Right choose an account; Enter moves to the password",
    "a11y.channel": "Account %1 of %2: %3",
    "a11y.login": "Log in",
    "a11y.session": "Desktop session",
    "a11y.layout": "Keyboard layout",
    "a11y.suspend": "Suspend computer",
    "a11y.restart": "Restart computer",
    "a11y.shutdown": "Shut down computer",
    "a11y.keyboard": "Toggle on-screen keyboard",
    "a11y.keyboardShow": "Show on-screen keyboard",
    "a11y.keyboardHide": "Hide on-screen keyboard",
    "a11y.confirm": "Confirm power action",
    "a11y.cancel": "Cancel and return",
    "a11y.time": "Current time %1",
    "a11y.date": "Current date %1",
    "a11y.computer": "Computer %1",
    "a11y.users": "Users",
    "experimental": "EXPERIMENTAL",
    "active": "ACTIVE",
    "continue": "Continue",
    "authFor": "Sign in · %1",
    "started": "Starting your session…",
    "daemonDown": "The login service is not reachable. Ask your administrator."
};

var ES = {
    "eyebrow.signIn": "01 · INGRESO",
    "eyebrow.channels": "CANALES",
    "eyebrow.power": "ENERGÍA",
    "channel": "CH",
    "channel.other": "Otro",
    "channel.otherHint": "Escribí un nombre",
    "user": "Usuario",
    "password": "Contraseña",
    "passwordFor": "Contraseña · %1",
    "session": "Sesión",
    "layout": "Teclado",
    "login": "Ingresar",
    "signingIn": "Ingresando…",
    "noResponse": "El gestor de pantalla todavía no respondió. Probá de nuevo.",
    "loginFailed": "Esa contraseña no funcionó. Probá de nuevo.",
    "loginFailedCount": "Esa contraseña no funcionó (intento %1). Probá de nuevo.",
    "capsLock": "Bloq Mayús está activado.",
    "noSessions": "No hay sesiones de escritorio instaladas. Consultá a quien administra el equipo.",
    "noUser": "Primero escribí un nombre de usuario.",
    "suspend": "Suspender",
    "restart": "Reiniciar",
    "shutdown": "Apagar",
    "keyboard": "Teclado",
    "cancel": "Cancelar",
    "confirm.suspend": "¿Suspender la computadora ahora?",
    "confirm.restart": "¿Reiniciar la computadora ahora?",
    "confirm.shutdown": "¿Apagar la computadora ahora?",
    "secondary": "INICIÁ SESIÓN EN LA PANTALLA PRINCIPAL",
    "greeting.morning": "Buen día. La lámpara está prendida",
    "greeting.afternoon": "Buenas tardes. El mate está listo",
    "greeting.evening": "Buenas noches. Acomodate",
    "greeting.night": "Turno noche. Luz baja, pulso firme",
    "greetingPlain.morning": "Buen día",
    "greetingPlain.afternoon": "Buenas tardes",
    "greetingPlain.evening": "Buenas noches",
    "greetingPlain.night": "Buenas noches",
    "zone": "ZONA",
    "out": "SAL",
    "a11y.username": "Nombre de usuario",
    "a11y.usernameHelp": "Escribí el nombre de la cuenta con la que querés ingresar",
    "a11y.password": "Contraseña",
    "a11y.passwordHelp": "Escribí la contraseña de %1",
    "a11y.channels": "Cuentas de usuario",
    "a11y.channelsHelp": "Izquierda y Derecha eligen una cuenta; Enter pasa a la contraseña",
    "a11y.channel": "Cuenta %1 de %2: %3",
    "a11y.login": "Ingresar",
    "a11y.session": "Sesión de escritorio",
    "a11y.layout": "Distribución de teclado",
    "a11y.suspend": "Suspender la computadora",
    "a11y.restart": "Reiniciar la computadora",
    "a11y.shutdown": "Apagar la computadora",
    "a11y.keyboard": "Mostrar u ocultar el teclado en pantalla",
    "a11y.keyboardShow": "Mostrar el teclado en pantalla",
    "a11y.keyboardHide": "Ocultar el teclado en pantalla",
    "a11y.confirm": "Confirmar la acción de energía",
    "a11y.cancel": "Cancelar y volver",
    "a11y.time": "Hora actual %1",
    "a11y.date": "Fecha actual %1",
    "a11y.computer": "Computadora %1",
    "a11y.users": "Usuarios",
    "experimental": "EXPERIMENTAL",
    "active": "ACTIVA",
    "continue": "Continuar",
    "authFor": "Ingreso · %1",
    "started": "Iniciando tu sesión…",
    "daemonDown": "El servicio de ingreso no responde. Consultá a quien administra el equipo."
};

var TABLES = {
    "en": EN,
    "es": ES
};

// theme.conf language (auto|en|es) + locale name ("es_AR") -> "en" | "es".
function pick(setting, localeName) {
    if (setting === "en" || setting === "es")
        return setting;
    return String(localeName || "").toLowerCase().indexOf("es") === 0 ? "es" : "en";
}

function t(lang, key) {
    var table = TABLES[lang] || EN;
    if (table[key] !== undefined)
        return table[key];
    if (EN[key] !== undefined)
        return EN[key];
    return key;
}

// Hour (0-23) -> greeting daypart, the same windows as the shell's
// Microcopy service: morning 5-11, afternoon 12-17, evening 18-22, night.
function daypart(hour) {
    if (hour >= 5 && hour < 12)
        return "morning";
    if (hour >= 12 && hour < 18)
        return "afternoon";
    if (hour >= 18 && hour < 23)
        return "evening";
    return "night";
}
