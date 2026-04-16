// ==UserScript==
// @name         Theme Hot Reload
// @namespace    userChrome.js
// @description  A UI reloader watching userChrome.css.
// @version      2.1
// @include      *
// @onlyonce
// ==/UserScript==

(function () {
  "use strict";

  console.warn("[ThemeReloader] SCRIPT EVALUATED");

  const Reloader = {
    lastModified: 0,
    file: null,
    timer: null,

    init() {
      try {
        console.warn("[ThemeReloader] Initializing...");

        this.file = Services.dirsvc.get("UChrm", Ci.nsIFile);
        this.file.append("userChrome.css");

        if (!this.file.exists() || !this.file.isFile()) {
          console.warn(
            `[ThemeReloader] userChrome.css NOT FOUND at: ${this.file.path}`,
          );
          return;
        }

        this.lastModified = this.file.lastModifiedTime;
        console.warn(`[ThemeReloader] Watching: ${this.file.path}`);

        this.start();
      } catch (e) {
        console.error(`[ThemeReloader] Init Error: ${e}`);
      }
    },

    start() {
      if (this.timer) clearInterval(this.timer);
      this.timer = setInterval(() => {
        try {
          const fresh = this.file.clone();
          if (fresh.exists() && fresh.lastModifiedTime > this.lastModified) {
            console.warn("[ThemeReloader] Change detected. Reloading theme...");
            this.lastModified = fresh.lastModifiedTime;
            this.reload();
          }
        } catch (e) {
          console.error(`[ThemeReloader] Watch Error: ${e}`);
        }
      }, 1000);
    },

    reload() {
      try {
        const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(
          Ci.nsIStyleSheetService,
        );
        const uri = Services.io.newFileURI(this.file);

        [sss.USER_SHEET, sss.AGENT_SHEET].forEach((type) => {
          if (sss.sheetRegistered(uri, type)) {
            sss.unregisterSheet(uri, type);
          }
          sss.loadAndRegisterSheet(uri, type);
        });

        Services.obs.notifyObservers(null, "chrome-flush-caches", null);
        console.warn("[ThemeReloader] Reload complete.");
      } catch (e) {
        console.error(`[ThemeReloader] Reload Error: ${e}`);
      }
    },
  };

  setTimeout(() => {
    Reloader.init();
  }, 1000);
})();
