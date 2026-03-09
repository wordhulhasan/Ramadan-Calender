const PRAYER_ORDER = [
  { key: "Imsak", label: "Suhoor Cut-off" },
  { key: "Fajr", label: "Fajr" },
  { key: "Sunrise", label: "Sunrise" },
  { key: "Dhuhr", label: "Dhuhr" },
  { key: "Asr", label: "Asr" },
  { key: "Maghrib", label: "Maghrib / Iftar" },
  { key: "Isha", label: "Isha" },
];

const PRAYER_WINDOWS = [
  {
    key: "Fajr",
    label: "Fajr",
    start: "Fajr",
    end: "Sunrise",
    description: "Fajr is active until sunrise.",
  },
  {
    key: "Dhuhr",
    label: "Dhuhr",
    start: "Dhuhr",
    end: "Asr",
    description: "Dhuhr is active until Asr begins.",
  },
  {
    key: "Asr",
    label: "Asr",
    start: "Asr",
    end: "Maghrib",
    description: "Asr is active until Maghrib.",
  },
  {
    key: "Maghrib",
    label: "Maghrib",
    start: "Maghrib",
    end: "Isha",
    description: "Maghrib is active until Isha begins.",
  },
  {
    key: "Isha",
    label: "Isha",
    start: "Isha",
    end: "TomorrowFajr",
    description: "Isha remains open until Fajr tomorrow.",
  },
];

const els = {
  locationName: document.getElementById("location-name"),
  gregorianDate: document.getElementById("gregorian-date"),
  hijriDate: document.getElementById("hijri-date"),
  ramadanDayDisplay: document.getElementById("ramadan-day-display"),
  ramadanDaySubtitle: document.getElementById("ramadan-day-subtitle"),
  suhoorTime: document.getElementById("suhoor-time"),
  suhoorNote: document.getElementById("suhoor-note"),
  iftarTime: document.getElementById("iftar-time"),
  iftarNote: document.getElementById("iftar-note"),
  currentWaqt: document.getElementById("current-waqt"),
  currentWaqtNote: document.getElementById("current-waqt-note"),
  nextWaqt: document.getElementById("next-waqt"),
  nextWaqtNote: document.getElementById("next-waqt-note"),
  timeline: document.getElementById("timeline"),
  timelineCaption: document.getElementById("timeline-caption"),
  calendarTitle: document.getElementById("calendar-title"),
  calendarTag: document.getElementById("calendar-tag"),
  calendarGrid: document.getElementById("calendar-grid"),
  insightText: document.getElementById("insight-text"),
  toast: document.getElementById("toast"),
  refreshLocation: document.getElementById("refresh-location"),
  fastingChip: document.getElementById("fasting-chip"),
};

const hijriLongFormatter = new Intl.DateTimeFormat("en-u-ca-islamic-umalqura", {
  day: "numeric",
  month: "long",
  year: "numeric",
});

const hijriNumericFormatter = new Intl.DateTimeFormat("en-u-ca-islamic-umalqura", {
  day: "numeric",
  month: "numeric",
  year: "numeric",
});

const dateFormatter = new Intl.DateTimeFormat("en-US", {
  weekday: "long",
  month: "long",
  day: "numeric",
  year: "numeric",
});

const shortDateFormatter = new Intl.DateTimeFormat("en-US", {
  month: "short",
  day: "numeric",
});

const weekdayFormatter = new Intl.DateTimeFormat("en-US", {
  weekday: "short",
});

let appState = {
  coords: null,
  locationLabel: "Awaiting location",
  prayerData: null,
  ramadanInfo: null,
  intervalId: null,
  activeDateKey: null,
};

function formatApiDate(date) {
  const day = String(date.getDate()).padStart(2, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const year = date.getFullYear();
  return `${day}-${month}-${year}`;
}

function parseHijriParts(date) {
  const longParts = Object.fromEntries(
    hijriLongFormatter
      .formatToParts(date)
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, part.value]),
  );

  const numericParts = Object.fromEntries(
    hijriNumericFormatter
      .formatToParts(date)
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, part.value]),
  );

  return {
    day: Number(numericParts.day),
    monthNumber: Number(numericParts.month),
    monthName: longParts.month,
    year: Number(numericParts.year),
    formatted: hijriLongFormatter.format(date),
  };
}

function formatTime(value) {
  const [hours, minutes] = value.split(":").map(Number);
  return new Intl.DateTimeFormat("en-US", {
    hour: "numeric",
    minute: "2-digit",
  }).format(new Date(2026, 0, 1, hours, minutes));
}

function buildDateTime(baseDate, timeValue) {
  const [hours, minutes] = timeValue.split(":").map(Number);
  const next = new Date(baseDate);
  next.setHours(hours, minutes, 0, 0);
  return next;
}

function formatCountdown(ms) {
  if (ms <= 0) {
    return "now";
  }

  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);

  if (!hours && !minutes) {
    return "under a minute";
  }

  if (!hours) {
    return `${minutes}m`;
  }

  if (!minutes) {
    return `${hours}h`;
  }

  return `${hours}h ${minutes}m`;
}

function setToast(message) {
  els.toast.textContent = message;
  els.toast.classList.add("is-visible");
  clearTimeout(setToast.timeoutId);
  setToast.timeoutId = setTimeout(() => {
    els.toast.classList.remove("is-visible");
  }, 3600);
}

function saveLocation(coords, label) {
  localStorage.setItem(
    "ramadan-compass-location",
    JSON.stringify({
      lat: coords.latitude,
      lon: coords.longitude,
      label,
    }),
  );
}

function loadSavedLocation() {
  try {
    const saved = JSON.parse(localStorage.getItem("ramadan-compass-location"));
    if (!saved || typeof saved.lat !== "number" || typeof saved.lon !== "number") {
      return null;
    }
    return saved;
  } catch {
    return null;
  }
}

async function reverseGeocode(lat, lon) {
  try {
    const response = await fetch(
      `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=en`,
    );
    if (!response.ok) {
      throw new Error("Reverse geocoding failed.");
    }
    const data = await response.json();
    return [
      data.city || data.locality,
      data.principalSubdivisionCode || data.principalSubdivision,
      data.countryName,
    ]
      .filter(Boolean)
      .join(", ");
  } catch {
    return `${lat.toFixed(2)}, ${lon.toFixed(2)}`;
  }
}

async function fetchPrayerData(lat, lon) {
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  const base = "https://api.aladhan.com/v1/timings";
  const todayUrl = `${base}/${formatApiDate(today)}?latitude=${lat}&longitude=${lon}&method=2`;
  const tomorrowUrl = `${base}/${formatApiDate(tomorrow)}?latitude=${lat}&longitude=${lon}&method=2`;

  const [todayResponse, tomorrowResponse] = await Promise.all([
    fetch(todayUrl),
    fetch(tomorrowUrl),
  ]);

  if (!todayResponse.ok || !tomorrowResponse.ok) {
    throw new Error("Prayer time service is unavailable right now.");
  }

  const [todayData, tomorrowData] = await Promise.all([
    todayResponse.json(),
    tomorrowResponse.json(),
  ]);

  return {
    today: todayData.data,
    tomorrow: tomorrowData.data,
  };
}

function buildPrayerMoments(prayerData) {
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  return {
    Imsak: buildDateTime(today, prayerData.today.timings.Imsak),
    Fajr: buildDateTime(today, prayerData.today.timings.Fajr),
    Sunrise: buildDateTime(today, prayerData.today.timings.Sunrise),
    Dhuhr: buildDateTime(today, prayerData.today.timings.Dhuhr),
    Asr: buildDateTime(today, prayerData.today.timings.Asr),
    Maghrib: buildDateTime(today, prayerData.today.timings.Maghrib),
    Isha: buildDateTime(today, prayerData.today.timings.Isha),
    TomorrowFajr: buildDateTime(tomorrow, prayerData.tomorrow.timings.Fajr),
  };
}

function getPrayerStatus(prayerData) {
  const moments = buildPrayerMoments(prayerData);
  const now = new Date();

  if (now < moments.Fajr) {
    return {
      current: {
        label: "Isha",
        expiresAt: moments.Fajr,
        note: "Last night's Isha window remains open until Fajr.",
      },
      next: {
        label: "Fajr",
        at: moments.Fajr,
        note: "Fajr begins at dawn.",
      },
      moments,
    };
  }

  for (const windowInfo of PRAYER_WINDOWS) {
    const start = moments[windowInfo.start];
    const end = moments[windowInfo.end];
    if (now >= start && now < end) {
      const nextLabel = windowInfo.key === "Isha" ? "Fajr" : PRAYER_WINDOWS[PRAYER_WINDOWS.findIndex((item) => item.key === windowInfo.key) + 1].label;
      const nextAt = windowInfo.key === "Isha" ? moments.TomorrowFajr : moments[PRAYER_WINDOWS[PRAYER_WINDOWS.findIndex((item) => item.key === windowInfo.key) + 1].start];
      return {
        current: {
          label: windowInfo.label,
          expiresAt: end,
          note: windowInfo.description,
        },
        next: {
          label: nextLabel,
          at: nextAt,
          note: `${nextLabel} is the next prayer window.`,
        },
        moments,
      };
    }
  }

  return {
    current: {
      label: "Between prayers",
      expiresAt: moments.Dhuhr,
      note: "There is no active fard prayer window after sunrise until Dhuhr.",
    },
    next: {
      label: "Dhuhr",
      at: moments.Dhuhr,
      note: "Dhuhr is the next prayer window.",
    },
    moments,
  };
}

function buildTimeline(prayerData, prayerStatus) {
  const now = new Date();
  const currentLabel = prayerStatus.current.label;
  const nextLabel = prayerStatus.next.label;

  els.timeline.innerHTML = PRAYER_ORDER.map((item) => {
    const eventTime = prayerStatus.moments[item.key];
    const isPast = now > eventTime;
    const isCurrent =
      (item.key === "Fajr" && currentLabel === "Fajr") ||
      (item.key === "Dhuhr" && currentLabel === "Dhuhr") ||
      (item.key === "Asr" && currentLabel === "Asr") ||
      (item.key === "Maghrib" && currentLabel === "Maghrib") ||
      (item.key === "Isha" && currentLabel === "Isha" && now >= prayerStatus.moments.Isha);
    const isNext =
      (item.key === "Fajr" && nextLabel === "Fajr") ||
      (item.key === "Dhuhr" && nextLabel === "Dhuhr") ||
      (item.key === "Asr" && nextLabel === "Asr") ||
      (item.key === "Maghrib" && nextLabel === "Maghrib") ||
      (item.key === "Isha" && nextLabel === "Isha");

    return `
      <div class="timeline-item ${isPast ? "past" : ""} ${isCurrent ? "current" : ""} ${isNext ? "next" : ""}">
        <span class="timeline-dot"></span>
        <div>
          <div class="timeline-title">
            <strong>${item.label}</strong>
            <span>${isCurrent ? "Active now" : isNext ? "Coming next" : isPast ? "Passed" : "Upcoming"}</span>
          </div>
          <p class="timeline-subtext">${getTimelineSubtext(item.key, prayerData)}</p>
        </div>
        <span class="timeline-time">${formatTime(prayerData.today.timings[item.key] || prayerData.tomorrow.timings.Fajr)}</span>
      </div>
    `;
  }).join("");

  els.timelineCaption.textContent =
    currentLabel === "Between prayers" ? "Waiting for Dhuhr" : `${currentLabel} is active`;
}

function getTimelineSubtext(key, prayerData) {
  switch (key) {
    case "Imsak":
      return "Last moment before fasting fully begins.";
    case "Fajr":
      return "Begins the fasting day and the first fard prayer window.";
    case "Sunrise":
      return "Fajr closes at sunrise.";
    case "Dhuhr":
      return "The midday prayer window opens.";
    case "Asr":
      return "The late afternoon prayer window opens.";
    case "Maghrib":
      return "Fast opens at Maghrib.";
    case "Isha":
      return `Night prayer continues until ${formatTime(prayerData.tomorrow.timings.Fajr)} tomorrow.`;
    default:
      return "";
  }
}

function buildRamadanCalendar() {
  const today = new Date();
  const todayHijri = parseHijriParts(today);
  const targetHijriYear = todayHijri.monthNumber <= 9 ? todayHijri.year : todayHijri.year + 1;
  const isCurrentRamadan = todayHijri.monthNumber === 9;
  const searchStart = new Date(today);
  searchStart.setDate(searchStart.getDate() - 220);

  const entries = [];
  let collecting = false;

  for (let index = 0; index < 700; index += 1) {
    const probe = new Date(searchStart);
    probe.setDate(searchStart.getDate() + index);

    const hijri = parseHijriParts(probe);
    const isTargetDay = hijri.year === targetHijriYear && hijri.monthNumber === 9;

    if (isTargetDay) {
      collecting = true;
      entries.push({
        gregorian: new Date(probe),
        hijriDay: hijri.day,
        isToday: probe.toDateString() === today.toDateString(),
      });
    } else if (collecting) {
      break;
    }
  }

  els.calendarTitle.textContent = `Ramadan ${targetHijriYear} AH`;
  els.calendarTag.textContent = isCurrentRamadan ? "Today is in Ramadan" : "Previewing the next Ramadan";

  els.calendarGrid.innerHTML = entries
    .map((entry) => {
      const isPast = entry.gregorian < today && !entry.isToday;
      const isUpcoming = entry.gregorian > today;
      return `
        <div class="calendar-day ${entry.isToday ? "is-today" : ""} ${isPast ? "is-past" : ""} ${isUpcoming ? "is-upcoming" : ""}">
          <span class="calendar-day-number">${entry.hijriDay}</span>
          <small>${weekdayFormatter.format(entry.gregorian)}</small>
          <p>${shortDateFormatter.format(entry.gregorian)}</p>
          <p>${entry.isToday ? "Today in Ramadan" : isUpcoming ? "Upcoming day" : "Completed day"}</p>
        </div>
      `;
    })
    .join("");

  if (isCurrentRamadan) {
    els.ramadanDayDisplay.textContent = `Day ${todayHijri.day}`;
    els.ramadanDaySubtitle.textContent = `${entries.length || 30}-day Ramadan calendar with today highlighted.`;
  } else {
    els.ramadanDayDisplay.textContent = todayHijri.formatted;
    els.ramadanDaySubtitle.textContent = `Today is outside Ramadan, so the next Ramadan month is shown below.`;
  }

  return {
    isCurrentRamadan,
    todayHijri,
    totalDays: entries.length,
  };
}

function updateHeroDates(prayerData, locationLabel, ramadanInfo) {
  const today = new Date();
  const apiHijri = prayerData?.today?.date?.hijri;

  els.locationName.textContent = locationLabel;
  els.gregorianDate.textContent = dateFormatter.format(today);
  els.hijriDate.textContent = apiHijri
    ? `${apiHijri.day} ${apiHijri.month.en} ${apiHijri.year} AH`
    : ramadanInfo.todayHijri.formatted;
  els.fastingChip.textContent = ramadanInfo.isCurrentRamadan ? "Ramadan Live" : "Prayer Live";
}

function renderPrayerCards(prayerData, prayerStatus, ramadanInfo) {
  const now = new Date();
  const suhoorEndsAt = prayerStatus.moments.Imsak;
  const iftarAt = prayerStatus.moments.Maghrib;
  const iftarCountdown = iftarAt.getTime() - now.getTime();
  const suhoorCountdown = suhoorEndsAt.getTime() - now.getTime();
  const currentCountdown = prayerStatus.current.expiresAt.getTime() - now.getTime();
  const nextCountdown = prayerStatus.next.at.getTime() - now.getTime();

  els.suhoorTime.textContent = formatTime(prayerData.today.timings.Imsak);
  els.suhoorNote.textContent =
    suhoorCountdown > 0
      ? `Suhoor closes in ${formatCountdown(suhoorCountdown)}. Fajr begins at ${formatTime(prayerData.today.timings.Fajr)}.`
      : `Suhoor has ended for today. Fajr began at ${formatTime(prayerData.today.timings.Fajr)}.`;

  els.iftarTime.textContent = formatTime(prayerData.today.timings.Maghrib);
  els.iftarNote.textContent =
    iftarCountdown > 0
      ? `Iftar begins in ${formatCountdown(iftarCountdown)} at Maghrib.`
      : `Iftar began at ${formatTime(prayerData.today.timings.Maghrib)}.`;

  els.currentWaqt.textContent = prayerStatus.current.label;
  els.currentWaqtNote.textContent =
    prayerStatus.current.label === "Between prayers"
      ? `No active fard window right now. ${prayerStatus.next.label} starts in ${formatCountdown(nextCountdown)}.`
      : `${prayerStatus.current.note} This waqt ends in ${formatCountdown(currentCountdown)}.`;

  els.nextWaqt.textContent = prayerStatus.next.label;
  els.nextWaqtNote.textContent = `${prayerStatus.next.label} begins in ${formatCountdown(nextCountdown)} at ${formatPrayerMoment(
    prayerStatus.next.at,
    now,
  )}.`;

  els.insightText.textContent = ramadanInfo.isCurrentRamadan
    ? `Today is day ${ramadanInfo.todayHijri.day} of Ramadan ${ramadanInfo.todayHijri.year} AH. Suhoor closes at ${formatTime(prayerData.today.timings.Imsak)}, Iftar opens at ${formatTime(prayerData.today.timings.Maghrib)}, and ${prayerStatus.next.label} is the next prayer to watch.`
    : `Today is ${ramadanInfo.todayHijri.formatted}. The dashboard still tracks live prayer times for your location and previews the next Ramadan month below.`;
}

function formatPrayerMoment(targetDate, currentDate) {
  return new Intl.DateTimeFormat("en-US", {
    weekday: targetDate.toDateString() !== currentDate.toDateString() ? "short" : undefined,
    hour: "numeric",
    minute: "2-digit",
  }).format(targetDate);
}

function startLiveClock() {
  clearInterval(appState.intervalId);
  appState.intervalId = window.setInterval(() => {
    if (!appState.prayerData) {
      return;
    }

    const dateKey = new Date().toDateString();
    if (dateKey !== appState.activeDateKey) {
      initialize(false);
      return;
    }

    const prayerStatus = getPrayerStatus(appState.prayerData);
    updateHeroDates(appState.prayerData, appState.locationLabel, appState.ramadanInfo);
    renderPrayerCards(appState.prayerData, prayerStatus, appState.ramadanInfo);
    buildTimeline(appState.prayerData, prayerStatus);
  }, 1000);
}

async function resolveLocation(forceFresh = true) {
  const saved = loadSavedLocation();

  if (!forceFresh && saved) {
    return {
      latitude: saved.lat,
      longitude: saved.lon,
      label: saved.label,
    };
  }

  if (!navigator.geolocation) {
    throw new Error("Geolocation is not supported by this browser.");
  }

  const position = await new Promise((resolve, reject) => {
    navigator.geolocation.getCurrentPosition(resolve, reject, {
      enableHighAccuracy: true,
      timeout: 12000,
      maximumAge: 5 * 60 * 1000,
    });
  });

  const latitude = position.coords.latitude;
  const longitude = position.coords.longitude;
  const label = await reverseGeocode(latitude, longitude);
  saveLocation(position.coords, label);

  return {
    latitude,
    longitude,
    label,
  };
}

function setLoadingState(message) {
  els.locationName.textContent = message;
  els.gregorianDate.textContent = "Loading...";
  els.hijriDate.textContent = "Loading...";
  els.ramadanDayDisplay.textContent = "Loading...";
  els.ramadanDaySubtitle.textContent = "Preparing your Ramadan dashboard...";
  els.suhoorTime.textContent = "--:--";
  els.iftarTime.textContent = "--:--";
  els.currentWaqt.textContent = "Loading...";
  els.nextWaqt.textContent = "Loading...";
  els.suhoorNote.textContent = "Waiting for prayer data...";
  els.iftarNote.textContent = "Waiting for prayer data...";
  els.currentWaqtNote.textContent = "Calculating active prayer time...";
  els.nextWaqtNote.textContent = "Calculating what comes next...";
  els.timeline.innerHTML = "";
  els.timelineCaption.textContent = "Loading...";
  els.calendarTitle.textContent = "Loading Ramadan month...";
  els.calendarTag.textContent = "Loading...";
  els.calendarGrid.innerHTML = "";
}

async function initialize(forceFreshLocation = false) {
  try {
    setLoadingState(forceFreshLocation ? "Refreshing your location..." : "Finding your location...");

    const location = await resolveLocation(forceFreshLocation);
    appState.coords = {
      latitude: location.latitude,
      longitude: location.longitude,
    };
    appState.locationLabel = location.label;

    const prayerData = await fetchPrayerData(location.latitude, location.longitude);
    appState.prayerData = prayerData;
    appState.activeDateKey = new Date().toDateString();

    const ramadanInfo = buildRamadanCalendar();
    appState.ramadanInfo = ramadanInfo;
    const prayerStatus = getPrayerStatus(prayerData);

    updateHeroDates(prayerData, location.label, ramadanInfo);
    renderPrayerCards(prayerData, prayerStatus, ramadanInfo);
    buildTimeline(prayerData, prayerStatus);
    startLiveClock();
  } catch (error) {
    const saved = loadSavedLocation();
    if (saved && !appState.prayerData) {
      try {
        const prayerData = await fetchPrayerData(saved.lat, saved.lon);
        appState.prayerData = prayerData;
        appState.locationLabel = saved.label;
        appState.activeDateKey = new Date().toDateString();
        const ramadanInfo = buildRamadanCalendar();
        appState.ramadanInfo = ramadanInfo;
        const prayerStatus = getPrayerStatus(prayerData);
        updateHeroDates(prayerData, saved.label, ramadanInfo);
        renderPrayerCards(prayerData, prayerStatus, ramadanInfo);
        buildTimeline(prayerData, prayerStatus);
        startLiveClock();
        setToast("Using your last saved location because live location was unavailable.");
        return;
      } catch {
        // Fall through to the shared error state.
      }
    }

    clearInterval(appState.intervalId);
    setLoadingState("Location permission is required");
    els.currentWaqt.textContent = "Location blocked";
    els.currentWaqtNote.textContent =
      "Enable location access and reload or use the refresh button so prayer times can be calculated for your area.";
    els.nextWaqt.textContent = "Waiting";
    els.nextWaqtNote.textContent = "Prayer times need your location to load correctly.";
    els.insightText.textContent =
      "This dashboard depends on browser location access. Open it on localhost or HTTPS, allow location, and refresh.";
    setToast(error.message || "Unable to load your prayer dashboard.");
  }
}

els.refreshLocation.addEventListener("click", () => {
  initialize(true);
});

initialize();
