import Foundation
import GoldSunCore

enum GoldSunStartPage {
    static let url = BrowserDestination.goldSunStartPage

    static func isStartPage(_ url: URL) -> Bool {
        url.scheme?.caseInsensitiveCompare(Self.url.scheme ?? "") == .orderedSame
            && url.host(percentEncoded: false)?.caseInsensitiveCompare(Self.url.host(percentEncoded: false) ?? "") == .orderedSame
    }

    static func html() -> String {
        let backgroundImage = heroImageURL().map { "url('\($0.absoluteString)')" } ?? "none"

        return """
        <!doctype html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>GoldSun</title>
            <style>
              :root {
                color-scheme: dark;
                --gold: #f0b34d;
                --gold-soft: #ffe6a3;
                --text: #fff7e6;
                --muted: rgba(255, 247, 230, 0.72);
                --line: rgba(255, 216, 139, 0.26);
                --field: rgba(25, 25, 25, 0.64);
              }

              * { box-sizing: border-box; }

              html, body {
                min-height: 100%;
              }

              body {
                margin: 0;
                color: var(--text);
                font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", sans-serif;
                letter-spacing: 0;
                background:
                  linear-gradient(135deg, rgba(14, 15, 16, 0.86), rgba(18, 17, 15, 0.54) 44%, rgba(240, 162, 54, 0.32)),
                  \(backgroundImage) center / cover fixed,
                  radial-gradient(circle at 78% 70%, rgba(248, 177, 70, 0.92), transparent 34%),
                  linear-gradient(135deg, #161819, #302216 58%, #f0a949);
              }

              main {
                display: grid;
                min-height: 100vh;
                place-items: center;
                padding: 7vh 28px;
              }

              .panel {
                width: min(760px, 100%);
                text-align: center;
              }

              .sun {
                position: relative;
                width: 166px;
                height: 166px;
                margin: 0 auto 28px;
                filter: drop-shadow(0 16px 28px rgba(0, 0, 0, 0.36));
              }

              .sun::before,
              .sun::after {
                content: "";
                position: absolute;
                inset: 0;
                background: linear-gradient(155deg, var(--gold-soft), #d48c20 72%, #8c580f);
              }

              .sun::before {
                clip-path: polygon(50% 0, 58% 30%, 85% 12%, 70% 40%, 100% 50%, 70% 60%, 85% 88%, 58% 70%, 50% 100%, 42% 70%, 15% 88%, 30% 60%, 0 50%, 30% 40%, 15% 12%, 42% 30%);
              }

              .sun::after {
                inset: 36px;
                border-radius: 50%;
                box-shadow: inset 0 2px 14px rgba(255, 247, 206, 0.48), inset 0 -16px 30px rgba(116, 67, 10, 0.2);
              }

              h1 {
                margin: 0;
                font-size: clamp(64px, 12vw, 128px);
                line-height: 0.9;
                font-weight: 760;
                text-shadow: 0 16px 26px rgba(0, 0, 0, 0.38);
              }

              p {
                max-width: 650px;
                margin: 22px auto 0;
                color: var(--muted);
                font-size: clamp(18px, 2.2vw, 23px);
                line-height: 1.5;
              }

              form {
                display: flex;
                gap: 10px;
                width: min(620px, 100%);
                margin: 34px auto 0;
                padding: 7px;
                border: 1px solid var(--line);
                border-radius: 16px;
                background: var(--field);
                box-shadow: 0 24px 80px rgba(0, 0, 0, 0.34);
                backdrop-filter: blur(18px);
              }

              input,
              button,
              a {
                font: inherit;
              }

              input {
                min-width: 0;
                flex: 1;
                border: 0;
                outline: 0;
                padding: 0 16px;
                color: var(--text);
                background: transparent;
                font-size: 16px;
              }

              input::placeholder {
                color: rgba(255, 247, 230, 0.48);
              }

              button,
              .link {
                min-height: 42px;
                border-radius: 10px;
                border: 1px solid transparent;
                font-weight: 700;
                text-decoration: none;
              }

              button {
                padding: 0 18px;
                color: #19130b;
                background: linear-gradient(155deg, var(--gold-soft), var(--gold));
                cursor: pointer;
              }

              .links {
                display: flex;
                flex-wrap: wrap;
                justify-content: center;
                gap: 10px;
                margin-top: 18px;
              }

              .link {
                display: inline-flex;
                align-items: center;
                justify-content: center;
                padding: 0 14px;
                color: var(--text);
                border-color: var(--line);
                background: rgba(255, 255, 255, 0.08);
                backdrop-filter: blur(16px);
              }

              .proof {
                display: flex;
                flex-wrap: wrap;
                justify-content: center;
                gap: 8px;
                margin-top: 26px;
                color: rgba(255, 247, 230, 0.66);
                font-size: 13px;
                font-weight: 700;
              }

              .proof span {
                padding: 7px 10px;
                border: 1px solid var(--line);
                border-radius: 999px;
                background: rgba(255, 255, 255, 0.07);
              }

              @media (max-width: 620px) {
                form {
                  flex-direction: column;
                }

                input {
                  min-height: 42px;
                  text-align: center;
                }
              }
            </style>
          </head>
          <body>
            <main>
              <section class="panel" aria-label="GoldSun start page">
                <div class="sun" aria-hidden="true"></div>
                <h1>GoldSun</h1>
                <p>A stripped down Mac browser built for fast launches, quiet chrome, and stricter privacy defaults.</p>
                <form action="https://duckduckgo.com/" method="get">
                  <input name="q" type="search" autofocus autocomplete="off" spellcheck="false" placeholder="Search privately or enter a site">
                  <button type="submit">Search</button>
                </form>
                <div class="links">
                  <a class="link" href="https://github.com/eMacTh3Creator/GoldSun">Source</a>
                  <a class="link" href="https://github.com/eMacTh3Creator/GoldSun/releases">Releases</a>
                  <a class="link" href="https://chromewebstore.google.com/">Extensions</a>
                </div>
                <div class="proof" aria-label="GoldSun priorities">
                  <span>HTTPS first</span>
                  <span>Tracker blocking</span>
                  <span>No startup network call</span>
                </div>
              </section>
            </main>
          </body>
        </html>
        """
    }

    private static func heroImageURL() -> URL? {
        if let bundledURL = Bundle.main.url(
            forResource: "goldsun-hero",
            withExtension: "png",
            subdirectory: "StartPage"
        ) {
            return bundledURL
        }

        let projectURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("docs/assets/goldsun-hero.png")
        return FileManager.default.fileExists(atPath: projectURL.path) ? projectURL : nil
    }
}
