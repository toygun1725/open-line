const $ = (id) => document.getElementById(id);
const catalog = BUNDLE.catalog;
const entries = catalog.stories;
const key = "openline.preview.v1";
const blank = () => ({ lang: "tr", paid: false, muted: false, font: "serif", replyFont: "serif", runs: {} });
function readSave() {
  try {
    return { ...blank(), ...JSON.parse(localStorage.getItem(key)) };
  } catch {
    return blank();
  }
}
let state = readSave(),
  scene = "play",
  active = null,
  expanded = null,
  modal = null,
  lastStamp = "",
  ad = null;
const tr = (a, b) => (state.lang === "tr" ? a : b);
const loc = (o) => o?.[state.lang] || "";
const esc = (x) =>
  String(x).replace(
    /[&<>"']/g,
    (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c],
  );
const entry = (id) => entries.find((s) => s.id === id);
const visible = (run, now) => run?.events.filter((e) => e.at <= now) || [];
const msg = (e) => loc(e.text).replace(/\{(\w+)\}/g, (_, k) => e.vars?.[k] ?? "");
function save() {
  if (scene === "play") {
    try {
      localStorage.setItem(key, JSON.stringify(state));
    } catch {}
  }
}
function sound(src) {
  if (!state.muted && src) {
    const a = new Audio("data:audio/wav;base64," + src);
    a.volume = 0.3;
    a.play().catch(() => {});
  }
}
function btn(action, label, cls = "action", extra = "") {
  return '<button class="' + cls + '" data-action="' + action + '" ' + extra + ">" + esc(label) + "</button>";
}
function openRun(id) {
  const s = entry(id);
  if (!s.isFree && !state.paid) {
    modal = "purchase";
    return;
  }
  state.runs[id] ??= newRun(id, Date.now());
  active = id;
  expanded = null;
  save();
}
function home() {
  const now = Date.now(),
    locale = tr("tr-TR", "en-GB");
  return (
    '<header class="top"><span class="wordmark">' +
    esc(loc(catalog.appTitle)) +
    "</span>" +
    btn("settings", "⚙", "gear", 'aria-label="' + tr("Ayarlar", "Settings") + '"') +
    '</header><div class="clockarea"><div class="date">' +
    esc(new Date(now).toLocaleDateString(locale, { weekday: "long", day: "numeric", month: "long" })) +
    '</div><div class="clock" id="menuClock">' +
    '</div></div><section class="inbox">' +
    entries
      .map((s) => {
        const run = state.runs[s.id],
          events = visible(run, now),
          last = events.filter((e) => e.kind === "message").at(-1),
          locked = !s.isFree && !state.paid;
        const direct = Boolean(run) && !locked;
        const isExpanded = !direct && expanded === s.id;
        const action = locked
          ? tr("Tam Erişimi aç", "Unlock All Access")
          : tr("Hatta bağlan", "Connect");
        const time = last ? new Date(last.at).toLocaleTimeString(locale, {
          hour: "2-digit", minute: "2-digit", hourCycle: "h23",
        }) : "";
        const name = loc(s.senderName);
        return (
          '<article class="card ' +
          (s.theme === "ice_blue" ? "ice" : "") +
          '"><button class="row" data-action="' + (direct ? "connect" : "expand") +
          '" data-id="' + s.id + '"' +
          (direct ? "" : ' aria-expanded="' + isExpanded + '"') +
          '><span class="avatar" aria-hidden="true">' +
          esc(name[0]) +
          '</span><span class="msg"><span class="by">' +
          esc(name) +
          '</span><span class="storytitle">' +
          esc(loc(s.title)) +
          '</span><span class="snippet">' +
          esc(last ? msg(last) : loc(s.invitation)) +
          '</span></span><span class="row-tail">' +
          (time ? '<time>' + esc(time) + '</time>' : "") +
          (locked ? '<span class="line-lock" role="img" aria-label="' + tr("Kilitli", "Locked") + '"></span>' :
            '<span class="row-chevron" aria-hidden="true">' + (isExpanded ? "⌄" : "›") + '</span>') +
          "</span></button>" +
          (isExpanded
            ? '<div class="detail"><p>' +
              esc(loc(s.synopsis)) +
              "</p>" +
              (locked ? '<p class="notice">' + esc(loc(catalog.iapPriceDisplay)) + "</p>" : "") +
              btn("connect", action, "action", 'data-id="' + s.id + '"') +
              "</div>"
            : "") +
          "</article>"
        );
      })
      .join("") +
    "</section>"
  );
}
function isTyping(run, count, now) {
  const last = run.events[count - 1];
  return run.events[count]?.kind === "message" && !(last?.kind === "delay" && last.until > now);
}
let renderedRun = null;
let renderedCount = 0;
let renderedModal = null;
let renderedLine = null;
let restoreFocus = null;
function chatHeader(story, events, now) {
  const lastDelay = events.findLast((event) => event.kind === "delay");
  const activeDelay = lastDelay?.until > now ? lastDelay : null;
  const stage = activeDelay?.spec.currentStage ?? events.reduce(
    (current, event) => event.kind === "delay" ? Math.max(current, event.spec.currentStage) : current,
    1,
  );
  const total = story.stageLabels.length;
  const value = events.findLast((event) => event.vars)?.vars[story.metricVar] ??
    BUNDLE.stories[story.id].manifest.variables[story.metricVar]?.default ?? 100;
  const status = value >= 80 ? tr("Çok İyi", "Great")
    : value >= 55 ? tr("İyi", "Good")
    : value >= 35 ? tr("Gergin", "Tense") : tr("Kritik", "Critical");
  const stageLabel = tr("Aşama " + stage + " / " + total, "Stage " + stage + " of " + total);
  const bars = story.stageLabels.map((_, index) => index < stage ? "<i class=\"filled\"></i>" : "<i></i>").join("");
  return (
    '<header class="chathead"><div class="chatnav">' +
    btn("home", "‹", "navback", 'aria-label="' + tr("Ana menü", "Main menu") + '"') +
    "<h1>" + esc(loc(story.title)) + "</h1>" +
    btn("settings", "⚙", "gear", 'aria-label="' + tr("Ayarlar", "Settings") + '"') +
    '</div><div class="chatmeta">' +
    '<div class="chatprogress' + (value < 30 ? ' critical' : '') + '" role="img" aria-label="' +
    esc(stageLabel) + '">' + bars + '</div><div class="chatmetrics">' +
    '<span class="chatstatus' + (value < 35 ? ' urgent' : '') + '" aria-label="' +
    esc(loc(story.metricLabel) + ", " + status) + '">' + esc(status) + "</span>" +
    (activeDelay ? '<span class="chattimer"><span class="timer-icon" aria-hidden="true"></span><span data-until="' +
      activeDelay.until + '"></span></span>' : "") +
    "</div></div></header>"
  );
}
function chat() {
  const s = entry(active),
    run = state.runs[active],
    now = Date.now(),
    events = visible(run, now);
  const typing = isTyping(run, events.length, now)
    ? '<div class="typing" role="status"><span class="typing-dots" aria-hidden="true"><i></i><i></i><i></i></span>' +
      esc(loc(s.senderName) + tr(" yazıyor…", " is typing…")) + "</div>"
    : "";
  const markup = events
    .map((e, i) => {
      if (e.kind === "message") {
        const arriving = renderedRun === run && i >= renderedCount && now - e.at < 1000;
        const newGroup = events[i - 1]?.kind !== "message";
        return (newGroup ? '<div class="sender-label">' + esc(loc(s.senderName)) + '</div>' : '') +
          '<div class="bubble' + (newGroup ? ' first-in-group' : '') + (arriving ? ' arriving' : '') + '">' +
          esc(msg(e)) + "</div>";
      }
      if (e.kind === "system") return '<div class="tele">' + esc(msg(e)) + "</div>";
      if (e.kind === "delay")
        return e.until > now
          ? '<div class="tele">' +
              esc(loc(e.spec.statusBody)) +
              ' · <span data-until="' +
              e.until +
              '"></span></div>'
          : "";
      if (e.kind === "choice")
        return (
          '<div class="choices' + (e.chosen != null ? ' answered' : '') + '">' +
          e.options
            .map((o, k) =>
              btn(
                "answer",
                loc(o.label),
                e.chosen === k ? "selected" : "",
                'data-num="' + i + '" data-opt="' + k + '" ' + (e.chosen != null ? "disabled" : ""),
              ),
            )
            .join("") +
          "</div>"
        );
      if (e.kind === "gate")
        return (
          '<section class="panel"><h3>' +
          esc(loc(e.title)) +
          "</h3>" +
          (e.cleared
            ? ""
            : "<p>" +
              esc(loc(e.subtitle)) +
              "</p>" +
              btn("gate", tr("Reklam izle ve devam et", "Watch ad and continue")) +
              btn("paywall", tr("Tam Erişim", "All Access"), "alt")) +
          "</section>"
        );
      if (e.kind === "ending")
        return (
          '<section class="panel"><h3>' +
          esc(loc(e.title)) +
          "</h3><p>" +
          esc(loc(e.summary)) +
          "</p>" +
          btn(
            "replay",
            state.paid
              ? tr("Yeniden başla", "Play again")
              : tr("Reklam izle ve yeniden başla", "Watch ad and play again"),
          ) +
          btn("home", tr("Ana menüye dön", "Main menu"), "alt") +
          "</section>"
        );
      return "";
    })
    .join("");
  renderedRun = run;
  renderedCount = events.length;
  return (
    chatHeader(s, events, now) +
    '<section class="feed">' +
    markup + typing +
    "</section>"
  );
}
function sheet() {
  if (!modal) return "";
  let inner = "";
  if (modal === "settings") {
    const extraFonts = Object.entries(PREVIEW_FONTS)
      .map(([id, name]) => '<option value="' + esc(id) + '">' + esc(name) + '</option>').join("");
    inner =
      "<h2>" +
      tr("Ayarlar", "Settings") +
      '</h2><div class="setting-list"><label>' +
      tr("Dil", "Language") +
      '<select id="language"><option value="tr">Türkçe</option><option value="en">English</option></select></label><label>' +
      tr("Mesaj yazısı", "Message font") +
      '<select id="font"><option value="serif">Serif</option><option value="mono">' +
      tr("Daktilo", "Typewriter") +
      '</option><option value="sans">' +
      tr("Geometrik", "Geometric") +
      "</option>" + extraFonts + '</select></label><p class="reply-sample message-sample">' +
      tr("Merhaba, mesajım ulaştı mı?", "Hello, did my message reach you?") + "</p>" +
      '<label>' + tr("Cevap yazısı", "Reply font") +
      '<select id="replyFont"><option value="serif">Serif</option><option value="sans">' +
      tr("Sade", "Sans serif") + '</option><option value="mono">' +
      tr("Eş aralıklı", "Monospaced") + '</option>' + extraFonts + '</select></label><p class="reply-sample">' +
      tr("Biraz bekle, buradayım.", "Give it a moment. I'm here.") + '</p>' +
      '<button class="sound-toggle" data-action="mute" role="switch" aria-checked="' + !state.muted + '">' +
      tr("Ses efektleri", "Sound effects") + '<i aria-hidden="true"></i></button></div>';
    if (!state.paid) inner += btn("paywall", tr("Tam Erişim", "All Access"), "access-link");
  } else if (modal === "purchase") {
    inner =
      "<h2>" +
      tr("Tam Erişim", "All Access") +
      "</h2><p>" +
      tr(
        "Tüm hikâyeler, reklamsız perdeler ve tekrarlar. Tek ödeme.",
        "All stories, ad-free acts and replays. One payment.",
      ) +
      "</p>" +
      btn("buy", tr("Satın almayı canlandır · $0.99", "Simulate purchase · $0.99"));
  } else {
    inner =
      "<h2>" +
      tr("Örnek ödüllü reklam", "Sample rewarded ad") +
      "</h2><p>" +
      tr(
        "Bu önizlemede reklamın tamamlanmasını veya erken kapatılmasını deneyebilirsin.",
        "Try completing the simulated ad or closing it early.",
      ) +
      "</p>" +
      btn("reward", tr("Reklamı tamamla", "Complete ad"));
  }
  return (
    '<div class="overlay"><section class="sheet' + (modal === "settings" ? " preferences" : "") +
    '" role="dialog" aria-modal="true" aria-label="' + (modal === "settings" ? tr("Ayarlar", "Settings") :
      modal === "purchase" ? tr("Tam Erişim", "All Access") : tr("Örnek ödüllü reklam", "Sample rewarded ad")) + '">' +
    inner +
    btn("close", tr("Kapat", "Close"), "alt") +
    "</section></div>"
  );
}
function render() {
  const screen = $("screen");
  const previous = screen.querySelector(".feed");
  const stick = !previous || previous.scrollHeight - previous.scrollTop - previous.clientHeight < 65;
  const pos = previous?.scrollTop ?? 0;
  const focused = document.activeElement;
  const action = focused?.dataset.action;
  const focusedSelector = focused?.id ? "#" + CSS.escape(focused.id) : action
    ? '[data-action="' + action + '"]' + (focused.dataset.id ? '[data-id="' + focused.dataset.id + '"]' : "")
    : null;
  if (modal && !renderedModal) restoreFocus = focusedSelector;

  document.documentElement.lang = state.lang;
  const phone = $("phone");
  phone.className =
    "phone " + state.font + (active ? " chat " + (entry(active).theme === "ice_blue" ? "icechat" : "") : "");
  phone.dataset.replyFont = state.replyFont;
  const messageFamily = Object.hasOwn(PREVIEW_FONTS, state.font) ? PREVIEW_FONTS[state.font] : "";
  const replyFamily = Object.hasOwn(PREVIEW_FONTS, state.replyFont) ? PREVIEW_FONTS[state.replyFont] : "";
  phone.style.setProperty("--message-family", messageFamily ? '"' + messageFamily + '", serif' : "");
  phone.style.setProperty("--reply-family", replyFamily ? '"' + replyFamily + '", sans-serif' : "");
  phone.style.setProperty("--reply-weight", replyFamily ? "400" : "");
  screen.innerHTML = active ? chat() : home();
  screen.inert = Boolean(modal);
  if (!active) {
    renderedRun = null;
    renderedCount = 0;
  }
  $("modal").innerHTML = sheet();
  if ($("language")) {
    $("language").value = state.lang;
    $("font").value = state.font;
    $("replyFont").value = state.replyFont;
  }
  const feed = $("screen").querySelector(".feed");
  if (feed) feed.scrollTop = stick ? feed.scrollHeight : pos;
  $("sceneLabel").textContent = tr("Önizleme sahneleri", "Preview scenes");
  const options = [
    ["play", tr("Benim telefonum", "My phone")],
    ["ending", tr("Final ve reklam", "Ending and ad")],
    ["paidEnding", tr("Tam Erişim ile final", "All Access ending")],
    ["dual", tr("İki açık hat", "Two live lines")],
    ["lock", tr("iOS bildirimleri", "iOS notifications")],
  ];
  $("scenes").innerHTML = options
    .map(([id, title]) => '<option value="' + id + '">' + title + "</option>")
    .join("");
  $("scenes").value = scene;
  if (scene === "lock" && !active && !modal) {
    const cards = entries.map((s) => {
      const seen = visible(state.runs[s.id], Date.now());
      const delay = seen.filter((e) => e.kind === "delay").at(-1);
      const last = seen.filter((e) => e.kind === "message").at(-1);
      if (!delay) return "";
      const spec = delay.spec;
      const stages = spec.stages
        .map(
          (label, i) =>
            '<span class="' + (i < spec.currentStage ? "filled" : "") + '">' + esc(loc(label)) + "</span>",
        )
        .join("");
      return (
        '<article class="card syscard"><button class="sysbtn" data-action="notice" data-id="' +
        s.id +
        '"><b>' +
        esc(loc(s.title)) +
        "</b><span>" +
        esc(loc(spec.statusBody)) +
        '</span><span class="stages">' +
        stages +
        "</span></button></article>" +
        (last
          ? '<article class="card syscard"><button class="sysbtn" data-action="notice" data-id="' +
            s.id +
            '"><b>' +
            esc(loc(s.senderName)) +
            "</b><span>" +
            esc(msg(last)) +
            "</span></button></article>"
          : "")
      );
    });
    $("screen").querySelector(".inbox").innerHTML = cards.join("");
  }
  updateCounter();
  updateWallpaper();
  if (modal) {
    const dialog = $("modal");
    const target = modal === renderedModal && focusedSelector ? dialog.querySelector(focusedSelector) : null;
    (target ?? dialog.querySelector('[data-action="close"]'))?.focus({ preventScroll: true });
  } else if (renderedModal) {
    const target = restoreFocus ? screen.querySelector(restoreFocus) : null;
    (target ?? (active ? screen.querySelector(".navback") : null))?.focus({ preventScroll: true });
    restoreFocus = null;
  } else if (active !== renderedLine) {
    const target = active ? screen.querySelector(".navback") : screen.querySelector('.row[data-id="' + renderedLine + '"]');
    target?.focus({ preventScroll: true });
  } else if (focusedSelector && screen.contains(focused) === false && focused !== document.body) {
    const target = screen.querySelector(focusedSelector);
    if (target && action !== "answer") target.focus({ preventScroll: true });
  }
  renderedModal = modal;
  renderedLine = active;
  lastStamp = stamp();
}
function stamp() {
  const now = Date.now();
  return [
    active,
    Math.floor(now / 60000),
    ...Object.values(state.runs).map((r) => {
      const count = visible(r, now).length;
      return r.id === active ? count + ":" + isTyping(r, count, now) : count;
    }),
  ].join("/");
}
function updateCounter() {
  const now = Date.now();
  for (const counter of $("screen").querySelectorAll("[data-until]")) {
    const seconds = Math.max(0, Math.ceil((Number(counter.dataset.until) - now) / 1000));
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor(seconds / 60) % 60;
    const remainder = String(seconds % 60).padStart(2, "0");
    const time = hours ? hours + ":" + String(minutes).padStart(2, "0") + ":" + remainder : minutes + ":" + remainder;
    if (counter.textContent !== time) counter.textContent = time;
  }
}
function grant(run, action, now) {
  if (action === "gate") clearGate(run, now);
  else if (reachedEnd(run, now)) state.runs[run.id] = newRun(run.id, now, run.endings);
  save();
}
function collectEndings(now) {
  for (const run of Object.values(state.runs)) {
    const end = reachedEnd(run, now);
    if (end && !run.endings.includes(end.endingId)) {
      run.endings.push(end.endingId);
      save();
    }
  }
}
function setScene(value) {
  scene = value;
  state = value === "play" ? readSave() : { ...blank(), lang: state.lang, replyFont: state.replyFont };
  active = null;
  modal = null;
  ad = null;
  expanded = null;
  if (value !== "play") {
    const now = Date.now();
    state.paid = value !== "ending";
    for (const s of entries) {
      const finalScene = value === "ending" || value === "paidEnding";
      if (finalScene && !s.isFree) continue;
      const run = newRun(s.id, 0);
      state.runs[s.id] = run;
      for (let n = 0; n < 100; n++) {
        const tail = run.events.at(-1),
          delay = run.events.find((e) => e.kind === "delay");
        if (!finalScene && delay) {
          const shift = now - delay.at - 8000;
          for (const e of run.events) {
            e.at += shift;
            if (e.until != null) e.until += shift;
          }
          break;
        }
        if (tail.kind === "choice") answer(run, run.events.length - 1, 0, tail.at);
        else if (tail.kind === "gate") clearGate(run, tail.at);
        else break;
      }
    }
    if (value === "ending" || value === "paidEnding") active = entries[0].id;
  }
  collectEndings(Date.now());
  render();
}
$("scenes").addEventListener("change", (e) => setScene(e.target.value));
document.addEventListener("keydown", (event) => {
  if (!modal) return;
  if (event.key === "Escape") {
    event.preventDefault();
    $("modal").querySelector('[data-action="close"]').click();
  }
  if (event.key !== "Tab") return;
  const controls = Array.from($("modal").querySelectorAll("button:enabled, select:enabled"));
  const index = controls.indexOf(document.activeElement);
  if (event.shiftKey ? index <= 0 : index === -1 || index === controls.length - 1) {
    event.preventDefault();
    controls[event.shiftKey ? controls.length - 1 : 0]?.focus();
  }
});
document.addEventListener("change", (e) => {
  if (e.target.id === "language") state.lang = e.target.value;
  else if (e.target.id === "font") state.font = e.target.value;
  else if (e.target.id === "replyFont") state.replyFont = e.target.value;
  else return;
  save();
  render();
});
document.addEventListener("click", (event) => {
  const b = event.target.closest("[data-action]");
  if (!b || b.disabled) return;
  const action = b.dataset.action,
    id = b.dataset.id,
    run = state.runs[active],
    now = Date.now();
  switch (action) {
    case "expand":
      expanded = expanded === id ? null : id;
      break;
    case "connect":
      openRun(id);
      break;
    case "notice":
      active = id;
      break;
    case "home":
      active = null;
      expanded = null;
      break;
    case "settings":
      modal = "settings";
      break;
    case "paywall":
      modal = "purchase";
      break;
    case "buy":
      state.paid = true;
      modal = null;
      for (const r of Object.values(state.runs)) clearGate(r, now);
      if (expanded) openRun(expanded);
      break;
    case "close":
      modal = null;
      ad = null;
      break;
    case "mute":
      state.muted = !state.muted;
      break;
    case "answer":
      answer(run, Number(b.dataset.num), Number(b.dataset.opt), now);
      break;
    case "replay":
    case "gate":
      if (!run || (action === "replay" && !reachedEnd(run, now))) return;
      if (state.paid) grant(run, action, now);
      else {
        ad = { id: active, session: run.session, action };
        modal = "ad";
      }
      break;
    case "reward":
      if (ad && run?.session === ad.session && active === ad.id) grant(run, ad.action, now);
      ad = null;
      modal = null;
      break;
  }
  sound(SWITCH);
  save();
  render();
});
function refresh() {
  const now = Date.now();
  if (modal && !active) updateWallpaper(new Date(now));
  collectEndings(now);
  if (state.paid)
    for (const run of Object.values(state.runs)) {
      if (run.events.at(-1)?.kind === "gate" && run.events.at(-1).at <= now) {
        clearGate(run, now);
        save();
      }
    }
  if (stamp() !== lastStamp && !modal) {
    const seen = active ? visible(state.runs[active], now) : [];
    if (seen.length > renderedCount && seen.slice(renderedCount).some((e) => e.kind === "message")) sound(CLICK);
    render();
  } else updateCounter();
}
initializeWallpaper();
setScene("play");
setInterval(refresh, 500);
document.addEventListener("visibilitychange", () => {
  if (!document.hidden) refresh();
});
