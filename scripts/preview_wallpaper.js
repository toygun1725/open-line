let previewHour = null;
let requestedHour = -1;
let wallpaperFrame = null;

function updateWallpaper(now = new Date()) {
  const hour = previewHour ?? now.getHours();
  const displayTime = previewHour === null
    ? now.toLocaleTimeString(tr("tr-TR", "en-GB"), { hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
    : String(hour).padStart(2, "0") + ":00";
  const clock = $("menuClock");
  if (clock && clock.textContent !== displayTime) clock.textContent = displayTime;

  const controls = $("wallpaperControls");
  controls.hidden = active !== null;
  if (active) return;
  $("wallpaperLabel").textContent = tr("Önizleme saati", "Preview hour");
  $("wallpaperHour").value = hour;
  $("wallpaperHour").setAttribute("aria-valuetext", displayTime);
  $("wallpaperTime").textContent = displayTime;
  $("wallpaperLive").textContent = tr("Yerel saat", "Local time");
  $("wallpaperLive").setAttribute("aria-pressed", String(previewHour === null));
  if (hour === requestedHour) return;

  requestedHour = hour;
  const frame = new Image();
  frame.alt = "";
  frame.src = WALLPAPERS[hour];
  frame.decode().then(() => {
    if (requestedHour !== hour) return;
    const backdrop = $("wallpaper");
    const oldFrame = wallpaperFrame;
    wallpaperFrame = frame;
    if (oldFrame) frame.classList.add("incoming");
    backdrop.append(frame);
    backdrop.dataset.hour = hour;
    if (oldFrame) {
      for (const image of Array.from(backdrop.children)) {
        if (image !== frame && image !== oldFrame) image.remove();
      }
      setTimeout(() => oldFrame.remove(), 480);
    }
  }).catch(() => {
    if (requestedHour === hour) requestedHour = -1;
  });
}

function initializeWallpaper() {
  $("wallpaperHour").addEventListener("input", (event) => {
    previewHour = Number(event.target.value);
    updateWallpaper();
  });
  $("wallpaperLive").addEventListener("click", () => {
    previewHour = null;
    updateWallpaper();
  });
}
