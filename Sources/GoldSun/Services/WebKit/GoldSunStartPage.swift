import Foundation
import GoldSunCore

enum GoldSunStartPage {
    static let url = BrowserDestination.goldSunStartPage

    static func isStartPage(_ url: URL) -> Bool {
        url.scheme?.caseInsensitiveCompare(Self.url.scheme ?? "") == .orderedSame
            && url.host(percentEncoded: false)?.caseInsensitiveCompare(Self.url.host(percentEncoded: false) ?? "") == .orderedSame
    }

    static func html() -> String {
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
                --ridge-near: #151512;
                --ridge-mid: #252016;
                --ridge-far: #4c3b24;
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
                overflow-x: hidden;
                background: #111315;
              }

              .scene {
                position: fixed;
                inset: 0;
                overflow: hidden;
                pointer-events: none;
                background:
                  radial-gradient(circle at 76% 68%, rgba(255, 211, 123, 0.72) 0 7vmin, rgba(233, 141, 36, 0.28) 7.4vmin 22vmin, transparent 36vmin),
                  radial-gradient(circle at 48% 12%, rgba(255, 238, 193, 0.12), transparent 46%),
                  linear-gradient(135deg, #101315 0%, #181817 42%, #3c2c1b 68%, #e39a35 100%);
              }

              .scene::before,
              .scene::after {
                content: "";
                position: absolute;
                inset: 0;
              }

              .scene::before {
                background:
                  linear-gradient(90deg, rgba(8, 9, 10, 0.82), transparent 34%, rgba(255, 186, 76, 0.18) 78%, rgba(255, 229, 162, 0.26)),
                  linear-gradient(180deg, rgba(255, 255, 255, 0.08), transparent 34%, rgba(12, 13, 14, 0.18));
              }

              .scene::after {
                background: radial-gradient(ellipse at center, transparent 28%, rgba(5, 6, 7, 0.56) 100%);
              }

              .sunrise {
                position: absolute;
                right: clamp(48px, 10vw, 150px);
                bottom: 18vh;
                width: clamp(120px, 14vw, 220px);
                aspect-ratio: 1;
                border-radius: 50%;
                background: radial-gradient(circle at 38% 35%, #fff0bd 0 12%, #ffd06e 38%, #f2a23a 68%, rgba(211, 112, 23, 0.2) 100%);
                box-shadow: 0 0 70px rgba(255, 190, 87, 0.58), 0 0 180px rgba(239, 147, 44, 0.34);
                opacity: 0.88;
              }

              .lake {
                position: absolute;
                left: 0;
                right: 0;
                bottom: 0;
                height: 26vh;
                background:
                  linear-gradient(180deg, rgba(59, 41, 24, 0.38), rgba(13, 14, 14, 0.9)),
                  repeating-linear-gradient(176deg, rgba(255, 205, 109, 0.14) 0 1px, transparent 2px 18px);
                opacity: 0.82;
              }

              .ridge {
                position: absolute;
                left: -8vw;
                right: -8vw;
                bottom: 0;
                transform-origin: bottom;
              }

              .ridge.far {
                bottom: 16vh;
                height: 30vh;
                background: linear-gradient(180deg, var(--ridge-far), #1d1a15);
                clip-path: polygon(0 76%, 10% 58%, 18% 64%, 28% 42%, 38% 70%, 48% 52%, 58% 68%, 70% 38%, 82% 62%, 92% 50%, 100% 68%, 100% 100%, 0 100%);
                filter: blur(0.5px);
                opacity: 0.58;
              }

              .ridge.mid {
                bottom: 8vh;
                height: 34vh;
                background: linear-gradient(180deg, #332817, var(--ridge-mid) 58%, #151513);
                clip-path: polygon(0 72%, 8% 50%, 17% 66%, 26% 32%, 38% 72%, 49% 44%, 59% 66%, 70% 28%, 82% 64%, 91% 46%, 100% 72%, 100% 100%, 0 100%);
                opacity: 0.86;
              }

              .ridge.near {
                height: 27vh;
                background: linear-gradient(180deg, #211a11, var(--ridge-near) 68%, #0d0e0d);
                clip-path: polygon(0 64%, 9% 44%, 21% 72%, 31% 40%, 43% 78%, 55% 48%, 67% 72%, 79% 36%, 90% 66%, 100% 48%, 100% 100%, 0 100%);
              }

              main {
                display: grid;
                position: relative;
                z-index: 1;
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
                color: transparent;
                background: linear-gradient(180deg, #fff9e8 0 46%, #f6c767 47%, #d68d20 76%, #8f5d14 100%);
                background-clip: text;
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                filter: drop-shadow(0 16px 24px rgba(0, 0, 0, 0.42));
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
                .sunrise {
                  right: 8vw;
                  bottom: 24vh;
                }

                .ridge.far {
                  bottom: 18vh;
                }

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
            <div class="scene" aria-hidden="true">
              <div class="sunrise"></div>
              <div class="lake"></div>
              <div class="ridge far"></div>
              <div class="ridge mid"></div>
              <div class="ridge near"></div>
            </div>
            <main>
              <section class="panel" aria-label="GoldSun start page">
                <div class="sun" aria-hidden="true"></div>
                <h1>GoldSun</h1>
                <form action="https://duckduckgo.com/" method="get">
                  <input name="q" type="search" autofocus autocomplete="off" spellcheck="false" placeholder="Search privately or enter a site">
                  <button type="submit">Search</button>
                </form>
                <div class="links">
                  <a class="link" href="goldsun://bookmarks">Bookmarks</a>
                  <a class="link" href="goldsun://history">History</a>
                  <a class="link" href="goldsun://passwords">Passwords</a>
                  <a class="link" href="goldsun://downloads">Downloads</a>
                  <a class="link" href="https://github.com/eMacTh3Creator/GoldSun">Source</a>
                  <a class="link" href="https://github.com/eMacTh3Creator/GoldSun/releases">Releases</a>
                  <a class="link" href="https://chromewebstore.google.com/">Extensions</a>
                </div>
                <div class="proof" aria-label="GoldSun priorities">
                  <span>HTTPS first</span>
                  <span>Tracker blocking</span>
                  <span>Keychain passwords</span>
                  <span>No startup network call</span>
                </div>
              </section>
            </main>
          </body>
        </html>
        """
    }

}
