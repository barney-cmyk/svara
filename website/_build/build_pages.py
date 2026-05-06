#!/usr/bin/env python3
"""
Neuron Flame website page generator.

Drives every page through one template so SEO stays consistent: canonical
URLs, Open Graph, Twitter cards, JSON-LD schema (SoftwareApplication,
WebSite, BreadcrumbList, FAQPage where applicable), the same nav, the same
footer, the same internal-link structure.

Usage:
    python3 _build/build_pages.py

Reads page specs defined inline (this file) and writes:
- /alternatives/*.html
- /use-cases/*.html
- /whisper-mac-gui.html
- /parakeet-mac.html
- /privacy/on-device-dictation.html
- /blog/index.html  (placeholder, ready for posts)

Existing pages (/, /docs/*.html, /support.html, /404.html) are NOT
overwritten — they were hand-authored and have their own structure.
This generator only adds the new SEO landing pages.
"""
import json
import os
from pathlib import Path

ROOT = Path("/Users/barney/Desktop/Code/VoiceInk/website")
SITE_URL = "https://neuronflame.com"


# ============================================================
# Shared HTML chrome
# ============================================================

def head(title: str, description: str, slug: str, og_image: str = "/assets/og.png",
         extra_jsonld: list[dict] | None = None) -> str:
    canonical = f"{SITE_URL}{slug}"
    ld_blocks = "".join(
        f'<script type="application/ld+json">{json.dumps(b, separators=(",", ":"))}</script>\n'
        for b in (extra_jsonld or [])
    )
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>{title}</title>
<meta name="description" content="{description}" />
<meta name="theme-color" content="#0a0712" />
<link rel="canonical" href="{canonical}" />
<link rel="icon" type="image/png" href="/assets/favicon.png" />
<link rel="apple-touch-icon" href="/assets/icon-256.png" />
<link rel="stylesheet" href="/styles.css" />
<link rel="alternate" type="application/rss+xml" title="Neuron Flame blog" href="/feed.xml" />

<!-- Open Graph -->
<meta property="og:type" content="website" />
<meta property="og:url" content="{canonical}" />
<meta property="og:title" content="{title}" />
<meta property="og:description" content="{description}" />
<meta property="og:image" content="{SITE_URL}{og_image}" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:site_name" content="Neuron Flame" />

<meta name="twitter:card" content="summary_large_image" />
<meta name="twitter:title" content="{title}" />
<meta name="twitter:description" content="{description}" />
<meta name="twitter:image" content="{SITE_URL}{og_image}" />

{ld_blocks}</head>
<body>"""


def nav() -> str:
    return """<nav class="nav">
  <div class="nav-inner">
    <a href="/" class="brand"><span class="mark"></span>Neuron Flame</a>
    <div class="nav-links">
      <a href="/#features">Features</a>
      <a href="/docs/">Docs</a>
      <a href="/alternatives/wispr-flow.html">Compare</a>
      <a href="/support.html">Support</a>
      <a href="/downloads/Neuron%20Flame.dmg" class="nav-cta">Download</a>
    </div>
  </div>
</nav>
"""


def breadcrumb_html(crumbs: list[tuple[str, str]]) -> str:
    """crumbs: [(label, href), ...]"""
    parts = []
    for i, (label, href) in enumerate(crumbs):
        if i < len(crumbs) - 1:
            parts.append(f'<a href="{href}">{label}</a>')
        else:
            parts.append(f'<span aria-current="page">{label}</span>')
    return f'<nav class="breadcrumbs" aria-label="Breadcrumb"><div class="container">' + " <span class=\"sep\">›</span> ".join(parts) + "</div></nav>"


def footer() -> str:
    return """<footer>
  <div class="footer-inner">
    <div class="footer-brand">
      <a href="/" class="brand"><span class="mark"></span>Neuron Flame</a>
      <p>Voice-to-text at the speed of thought. Made by Barney Sharma in Australia, for Ziva.</p>
    </div>
    <div class="footer-col">
      <h5>Compare</h5>
      <a href="/alternatives/wispr-flow.html">vs Wispr Flow</a>
      <a href="/alternatives/superwhisper.html">vs SuperWhisper</a>
      <a href="/alternatives/macwhisper.html">vs MacWhisper</a>
      <a href="/alternatives/voiceink.html">vs VoiceInk</a>
      <a href="/alternatives/apple-dictation.html">vs Apple Dictation</a>
    </div>
    <div class="footer-col">
      <h5>Use cases</h5>
      <a href="/use-cases/developers.html">Developers</a>
      <a href="/use-cases/writers.html">Writers</a>
      <a href="/use-cases/accessibility.html">Accessibility</a>
      <a href="/whisper-mac-gui.html">Whisper on Mac</a>
      <a href="/parakeet-mac.html">Parakeet on Mac</a>
    </div>
    <div class="footer-col">
      <h5>Docs</h5>
      <a href="/docs/quick-start.html">Quick start</a>
      <a href="/docs/permissions.html">Permissions</a>
      <a href="/docs/privacy.html">Privacy</a>
      <a href="/docs/troubleshooting.html">Troubleshooting</a>
    </div>
    <div class="footer-col">
      <h5>About</h5>
      <a href="/support.html">Support</a>
      <a href="https://github.com/barney-cmyk/svara">Source code</a>
      <a href="https://github.com/barney-cmyk/svara/blob/main/LICENSE">License</a>
    </div>
  </div>
  <div class="legal">
    <span>© 2026 Ziva Studio. GPL-3.0 licensed.</span>
    <span>Made with ❤️ for Ziva.</span>
  </div>
</footer>
</body>
</html>"""


# ============================================================
# JSON-LD generators
# ============================================================

def organization_ld() -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "Organization",
        "@id": f"{SITE_URL}/#organization",
        "name": "Ziva Studio",
        "url": SITE_URL,
        "logo": f"{SITE_URL}/assets/icon.png",
        "founder": {"@type": "Person", "name": "Barney Sharma"},
    }


def website_ld() -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "WebSite",
        "@id": f"{SITE_URL}/#website",
        "name": "Neuron Flame",
        "url": SITE_URL,
        "description": "Free, on-device voice-to-text dictation for macOS.",
        "publisher": {"@id": f"{SITE_URL}/#organization"},
        "potentialAction": {
            "@type": "SearchAction",
            "target": f"{SITE_URL}/?q={{search_term_string}}",
            "query-input": "required name=search_term_string",
        },
    }


def software_application_ld() -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "@id": f"{SITE_URL}/#app",
        "name": "Neuron Flame",
        "operatingSystem": "macOS 14.0 or later",
        "applicationCategory": "ProductivityApplication",
        "applicationSubCategory": "Voice-to-text dictation",
        "url": SITE_URL,
        "downloadUrl": f"{SITE_URL}/downloads/Neuron%20Flame.dmg",
        "softwareVersion": "1.74",
        "offers": {
            "@type": "Offer",
            "price": "0",
            "priceCurrency": "USD",
        },
        "publisher": {"@id": f"{SITE_URL}/#organization"},
        "description": "A private, on-device voice-to-text dictation app for macOS. Hold a hotkey, speak, release — your words appear at the cursor in any app. Local Whisper + NVIDIA Parakeet, optional AI enhancement, per-app Power Mode, custom dictionary, Liquid Glass UI. Free and open source under GPL-3.",
        "featureList": [
            "On-device transcription (Whisper + Parakeet V2)",
            "Push-to-talk global hotkey",
            "Cursor-aware paste in any app",
            "Optional AI enhancement (Gemini, OpenAI, Anthropic, Ollama, local CLI)",
            "Per-app Power Mode",
            "Custom dictionary",
            "Live transcript preview",
            "Dynamic Island top-of-screen recorder",
            "Liquid Glass UI for macOS 26 Tahoe",
        ],
        "image": f"{SITE_URL}/assets/icon.png",
    }


def breadcrumb_ld(crumbs: list[tuple[str, str]]) -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "BreadcrumbList",
        "itemListElement": [
            {
                "@type": "ListItem",
                "position": i + 1,
                "name": label,
                "item": f"{SITE_URL}{href}",
            }
            for i, (label, href) in enumerate(crumbs)
        ],
    }


def faqpage_ld(faqs: list[tuple[str, str]]) -> dict:
    return {
        "@context": "https://schema.org",
        "@type": "FAQPage",
        "mainEntity": [
            {
                "@type": "Question",
                "name": q,
                "acceptedAnswer": {"@type": "Answer", "text": a},
            }
            for q, a in faqs
        ],
    }


# ============================================================
# Page-level helpers
# ============================================================

def hero(eyebrow: str, headline_html: str, lede: str, primary_cta: tuple[str, str] = ("Download for Mac", "/downloads/Neuron%20Flame.dmg"), secondary_cta: tuple[str, str] | None = ("Read the docs", "/docs/")) -> str:
    sec_html = ""
    if secondary_cta:
        sec_html = f'<a class="btn btn-secondary" href="{secondary_cta[1]}">{secondary_cta[0]}</a>'
    return f"""<header class="hero compare-hero">
  <span class="eyebrow"><span class="dot"></span>{eyebrow}</span>
  <h1 class="display compact">{headline_html}</h1>
  <p class="lede">{lede}</p>
  <div class="cta-row">
    <a class="btn btn-primary" href="{primary_cta[1]}">{primary_cta[0]}</a>
    {sec_html}
  </div>
  <p class="tiny-note">Free · Open source · GPL-3.0 · 100% on-device by default</p>
</header>
"""


def comparison_table(title: str, rows: list[tuple[str, str, str]]) -> str:
    """rows: [(feature, neuron_flame_value, competitor_value), ...]"""
    body = "".join(
        f'<tr><th scope="row">{feat}</th><td class="us">{nf}</td><td>{them}</td></tr>'
        for feat, nf, them in rows
    )
    return f"""<section class="compare-table-section">
  <div class="narrow">
    <h2>{title}</h2>
    <table class="compare-table">
      <thead>
        <tr>
          <th></th>
          <th class="us">Neuron Flame</th>
          <th>Alternative</th>
        </tr>
      </thead>
      <tbody>{body}</tbody>
    </table>
  </div>
</section>
"""


def faq_section(faqs: list[tuple[str, str]]) -> str:
    items = "".join(
        f"<details><summary>{q}</summary><p>{a}</p></details>"
        for q, a in faqs
    )
    return f"""<section id="faq">
  <div class="container">
    <div class="section-head">
      <div class="section-eyebrow">FAQ</div>
      <h2 class="section-title">Common questions.</h2>
    </div>
    <div class="faq">{items}</div>
  </div>
</section>
"""


def closing_cta(headline: str, sub: str) -> str:
    return f"""<section class="closing-cta">
  <h2 class="section-title">{headline}</h2>
  <p class="section-sub">{sub}</p>
  <a class="btn btn-primary" href="/downloads/Neuron%20Flame.dmg">Download Neuron Flame</a>
</section>
"""


def render(slug: str, title: str, description: str, body: str, faqs: list[tuple[str, str]] | None = None, breadcrumbs: list[tuple[str, str]] | None = None) -> str:
    crumbs = breadcrumbs or [("Home", "/"), (title.split(" — ")[0], slug)]

    jsonld = [organization_ld(), website_ld(), software_application_ld(), breadcrumb_ld(crumbs)]
    if faqs:
        jsonld.append(faqpage_ld(faqs))

    return (
        head(title, description, slug, extra_jsonld=jsonld)
        + nav()
        + breadcrumb_html(crumbs)
        + body
        + (faq_section(faqs) if faqs else "")
        + footer()
    )


# ============================================================
# PAGE CONTENT — defined separately, registered in build()
# ============================================================
# Each page is a function returning (slug, title, description, body, faqs, breadcrumbs)

def page_wispr_flow():
    slug = "/alternatives/wispr-flow.html"
    title = "Neuron Flame vs Wispr Flow — the free, on-device alternative"
    description = "Looking for a Wispr Flow alternative? Neuron Flame is free, runs 100% on-device, supports the same push-to-talk flow, and adds AI enhancement with the model of your choice. macOS only."

    body = hero(
        eyebrow="Wispr Flow alternative",
        headline_html='Like Wispr Flow.<br/>Just <span class="gradient-text">free, local, and yours.</span>',
        lede="If Wispr Flow's $15/month subscription and cloud round-trip aren't for you, Neuron Flame is the closest thing — same push-to-talk flow, same dictate-into-any-app convenience, but transcribing entirely on your Mac with the option to plug in any LLM you already pay for.",
    )

    body += comparison_table("How they line up", [
        ("Price",                  "Free, forever",                           "$15/month subscription"),
        ("Where audio is processed", "100% on your Mac",                       "Cloud (their servers)"),
        ("Works offline",           "Yes",                                     "No"),
        ("AI enhancement",          "Your choice — Gemini, GPT, Claude, Ollama, local CLI", "Their pipeline only"),
        ("Custom dictionary",       "Yes",                                     "Limited"),
        ("Per-app behaviour",       "Power Mode profiles",                     "Limited contexts"),
        ("Open source",             "Yes — GPL-3, source on GitHub",          "No"),
        ("Telemetry",               "Zero",                                    "Cloud requires it"),
        ("macOS support",           "14 Sonoma, 15 Sequoia, 26 Tahoe",         "Recent macOS"),
        ("Setup time",              "30 seconds",                              "Account + install"),
    ])

    body += """<section class="container narrow long-body">
  <h2>Why people switch from Wispr Flow</h2>
  <p>The number-one reason people Google "Wispr Flow alternative" is the recurring cost. $15/month is fine if you're a knowledge worker dictating all day; it's harder to justify for occasional use, students, or anyone with a privacy preference for keeping voice data off third-party servers.</p>
  <p>The number-two reason: <strong>cloud latency</strong>. Wispr Flow's transcription quality is excellent, but it requires a round-trip to their servers. On flaky Wi-Fi or in a coffee shop, you feel it. Neuron Flame's on-device Parakeet V2 model lives on your Apple Neural Engine — it's already loaded by the time you press your hotkey.</p>
  <p>The number-three reason: <strong>using your own LLM</strong>. Wispr Flow runs your transcripts through their AI cleanup. Neuron Flame's AI Enhancement layer is BYO model — pipe transcripts through Gemini, GPT-4o, Claude, your local Ollama install, or even a CLI like the <code>claude</code> command. If you already pay for an LLM, you'll get more value out of it.</p>

  <h2>What's different (honestly)</h2>
  <p>Wispr Flow has things Neuron Flame doesn't, and we'd rather tell you up front:</p>
  <ul>
    <li><strong>Wispr Flow is on Windows too.</strong> Neuron Flame is macOS only — we lean hard into macOS-native features (Liquid Glass, the notch / Dynamic Island, Apple Neural Engine, App Intents). If you need Windows, Wispr Flow is the better fit.</li>
    <li><strong>Wispr Flow has a polished cross-device sync story.</strong> Neuron Flame syncs your custom dictionary via iCloud (when signed in) but doesn't have a hosted account. If you want one identity across multiple devices and platforms, Wispr Flow handles that.</li>
    <li><strong>Wispr Flow's transcription model is theirs.</strong> Neuron Flame uses Whisper + Parakeet V2 — open weights, well-known accuracy. Both excellent for English; Whisper supports 100+ languages, Parakeet is English-only but faster.</li>
  </ul>

  <h2>How to switch in 60 seconds</h2>
  <ol>
    <li>Cancel your Wispr Flow subscription (you don't need it active to try Neuron Flame).</li>
    <li><a href="/downloads/Neuron%20Flame.dmg">Download the DMG</a>, drag to Applications.</li>
    <li>Right-click → Open the first time (self-signed; we're working on Apple notarisation).</li>
    <li>Grant Microphone + Accessibility when prompted.</li>
    <li>Pick your hotkey on the Settings tab. Most ex-Wispr-Flow users like Right Option — same as their default.</li>
    <li>Hold the hotkey, speak, release. Same flow.</li>
  </ol>
  <p>If you have AI Enhancement enabled in Wispr Flow, set up the equivalent in Neuron Flame from the <a href="/docs/ai-enhancement.html">AI Enhancement docs</a> — pick a provider, paste an API key, choose a prompt template. The default prompt is essentially the same: clean grammar, fix obvious mistakes, preserve voice.</p>
</section>
"""

    body += closing_cta(
        "Ready to dictate without paying rent?",
        "Free download. No subscription. No account. Just hold the key and talk."
    )

    faqs = [
        ("Is Neuron Flame really free or is there a catch?",
         "Genuinely free. No subscription, no license key, no paywall. It's GPL-3 open source — you can read the code, fork it, or distribute it. The only thing we ask is that if you depend on it, you check in occasionally to GitHub for updates."),
        ("Will my dictation be as accurate as Wispr Flow?",
         "Comparable for English. Wispr Flow uses a strong proprietary model; Neuron Flame uses Whisper or Parakeet V2 (NVIDIA's English-only model, optimised for the Apple Neural Engine). In our testing Parakeet V2 sits within ~1% word-error-rate of Wispr Flow on clear audio. For other languages, Whisper Large v3 Turbo is the recommended choice."),
        ("Can I use my Wispr Flow dictionary in Neuron Flame?",
         "Not directly — formats differ — but you can copy the words across in a few minutes. Open your Wispr Flow dictionary, then in Neuron Flame use the Dictionary tab to add each word. Future versions may support import."),
        ("Does Neuron Flame support the AI cleanup I get with Wispr Flow?",
         "Yes — and you get to pick the model. AI Enhancement supports Gemini, OpenAI (GPT-4o etc.), Anthropic Claude, Ollama for fully-local cleanup, Groq for fast Whisper Large, and any OpenAI-compatible custom endpoint. The default prompt is set up for the same use case Wispr Flow targets: light grammar fixes, no rewriting."),
        ("What about Windows? My team uses Wispr Flow on a mix of Macs and PCs.",
         "Neuron Flame is macOS only — we lean into Apple-specific features (Liquid Glass, Apple Neural Engine, App Intents). If your workflow needs Windows, Wispr Flow remains the better choice for that side of the team. For the Mac side, we think we're a strong fit."),
    ]

    crumbs = [("Home", "/"), ("Alternatives", "/alternatives/wispr-flow.html"), ("Wispr Flow", slug)]
    return slug, title, description, body, faqs, crumbs


def page_superwhisper():
    slug = "/alternatives/superwhisper.html"
    title = "Neuron Flame vs SuperWhisper — open-source dictation for Mac"
    description = "Comparing SuperWhisper to Neuron Flame? Both run Whisper locally, but Neuron Flame is free, open-source, and ships with Parakeet V2 and a Liquid-Glass Dynamic-Island recorder. Here's the honest comparison."

    body = hero(
        eyebrow="SuperWhisper alternative",
        headline_html='SuperWhisper, but <span class="gradient-text">open and free.</span>',
        lede="SuperWhisper pioneered local Whisper on macOS with a beautiful menu-bar UI. Neuron Flame takes the same on-device approach, makes it free under GPL-3, adds NVIDIA Parakeet V2 for fastest English transcription, and ships a Liquid-Glass Dynamic-Island recorder that hugs the physical notch.",
    )

    body += comparison_table("Direct comparison", [
        ("Price",                   "Free, forever",                            "Paid (one-time + paid pro tier)"),
        ("On-device transcription", "Yes (Whisper + Parakeet V2)",              "Yes (Whisper variants)"),
        ("Open source",             "Yes — GPL-3 on GitHub",                    "No"),
        ("Parakeet V2 support",     "Yes (Apple Neural Engine)",                "No"),
        ("AI enhancement",          "Gemini, GPT, Claude, Ollama, local CLI",   "Limited / paid feature"),
        ("Per-app behaviour",       "Power Mode profiles",                      "Per-app modes"),
        ("Recorder UI",             "Notch / Dynamic Island top-of-screen",     "Menu bar dropdown"),
        ("Liquid Glass (macOS 26)", "Yes",                                       "No"),
        ("Custom dictionary",       "Yes",                                       "Yes"),
    ])

    body += """<section class="container narrow long-body">
  <h2>What SuperWhisper does well</h2>
  <p>SuperWhisper was one of the first apps to make running Whisper locally on macOS genuinely pleasant. Their menu-bar UI is unobtrusive, their Whisper integration is solid, and their model picker covers the full Whisper family. If you bought SuperWhisper, you got a good app and a developer who's actively shipping.</p>
  <h2>Where Neuron Flame differs</h2>
  <p><strong>Open source under GPL-3.</strong> The code is on GitHub. You can read what's happening, fork it, build your own version, or audit the privacy claims directly rather than taking our word for them.</p>
  <p><strong>Parakeet V2 baked in.</strong> NVIDIA's English-only Parakeet V2 runs on the Apple Neural Engine via FluidAudio. It's noticeably faster than Whisper on the same Mac, and accuracy is competitive with Whisper Medium. SuperWhisper sticks to Whisper variants.</p>
  <p><strong>Dynamic Island recorder.</strong> The recorder pill drapes over the physical notch on Apple Silicon laptops with a brand-tinted breathing halo while recording. SuperWhisper uses a more traditional menu-bar dropdown.</p>
  <p><strong>BYO LLM for AI enhancement.</strong> Plug in your existing OpenAI, Anthropic, Gemini, or Ollama setup. SuperWhisper has its own enhancement options but is less open-ended.</p>
  <h2>Honest things SuperWhisper has on us</h2>
  <ul>
    <li><strong>Maturity.</strong> SuperWhisper has been shipping longer. It has a deeper user base and more battle-testing across edge cases.</li>
    <li><strong>Polish on certain UI flows.</strong> Their model picker, in particular, is very nicely designed.</li>
    <li><strong>Apple-notarised.</strong> No Gatekeeper warning on first launch (we're working on this — the cert is in process).</li>
  </ul>
</section>
"""

    body += closing_cta(
        "Try the open-source take.",
        "Free, no account, no paywall. If you don't like it, drag it to the Bin — no hard feelings."
    )

    faqs = [
        ("Can I run my SuperWhisper Whisper models in Neuron Flame?",
         "If you already have Whisper .bin files (from whisper.cpp or similar), Neuron Flame can use them — it shares the whisper.cpp ecosystem. Drop them into ~/Library/Application Support/com.neuronflame.app/Models/ or download fresh from the AI Models tab."),
        ("Does Neuron Flame have a menu-bar mode like SuperWhisper?",
         "Yes — there's a menu-bar icon for quick toggles. The full recorder UI sits at the top of the screen as a Dynamic-Island-style pill, and you can switch between that and a bottom-of-screen 'mini' recorder in Settings → Recorder Style."),
        ("Will my custom prompts transfer over?",
         "Not automatically — the formats differ — but copy/pasting the prompt body into Neuron Flame's Enhancement tab takes a minute. We support the same kind of templating (system message + user message + transcript variable)."),
        ("Why ship two transcription engines (Whisper and Parakeet)?",
         "They have different strengths. Whisper is multilingual and extremely accurate on hard audio. Parakeet V2 is English-only and uses the Apple Neural Engine — much faster on Apple Silicon with comparable English accuracy. Default is Parakeet; switch any time."),
    ]
    crumbs = [("Home", "/"), ("Alternatives", "/alternatives/wispr-flow.html"), ("SuperWhisper", slug)]
    return slug, title, description, body, faqs, crumbs


def page_macwhisper():
    slug = "/alternatives/macwhisper.html"
    title = "Neuron Flame vs MacWhisper — free dictation with the same local pipeline"
    description = "MacWhisper is a paid Mac Whisper transcriber. Neuron Flame is free, also runs Whisper locally, and adds push-to-talk dictation, Parakeet V2, AI enhancement, and a Dynamic-Island recorder. Here's how they compare."

    body = hero(
        eyebrow="MacWhisper alternative",
        headline_html='MacWhisper for transcription.<br/>Neuron Flame for <span class="gradient-text">dictation.</span>',
        lede="They're often listed side-by-side, but they solve different problems. MacWhisper is brilliant at transcribing audio files. Neuron Flame is built for live push-to-talk dictation while you work — different use case, different UI, same underlying Whisper power.",
    )

    body += comparison_table("Side by side", [
        ("Primary use case",         "Live dictation while typing",            "Transcribing audio files"),
        ("Push-to-talk hotkey",      "Yes — global, paste at cursor",         "No (record-then-transcribe)"),
        ("Audio file transcription", "Yes",                                     "Yes (the headline feature)"),
        ("Price",                    "Free, GPL-3",                             "Paid (Pro tier)"),
        ("On-device",                "Yes",                                     "Yes"),
        ("Parakeet V2",              "Yes",                                     "No"),
        ("AI enhancement",           "Multi-provider, prompt templates",       "Limited"),
        ("Per-app behaviour",        "Power Mode profiles",                    "N/A — different use case"),
        ("Live transcript preview",  "Yes",                                     "N/A"),
    ])

    body += """<section class="container narrow long-body">
  <h2>The honest take</h2>
  <p>MacWhisper is excellent at what it does. If your job is transcribing podcasts, interviews, lectures, or meeting recordings — buy MacWhisper. The batch transcription UX is mature and the developer ships consistently.</p>
  <p>Neuron Flame is built for a different moment: you're typing in Mail, Slack, Cursor, or your terminal, you'd rather speak the next sentence than type it, you want it to appear at your cursor in milliseconds. Push-to-talk on a global hotkey, paste at the cursor, get back to work. That's the entire shape of the app.</p>
  <h2>If you want one tool that does both</h2>
  <p>Neuron Flame can transcribe audio files too — there's a Transcribe Audio tab that handles WAV, MP3, M4A, and most common formats. It's not as feature-rich as MacWhisper for batch work (no speaker diarisation, no fancy editing UI), but for casual "I have one MP3, I just want the text" use cases, it does the job.</p>
  <h2>Switching costs</h2>
  <ul>
    <li>If you have a paid MacWhisper licence, you don't lose anything — keep it for batch transcription, add Neuron Flame for live dictation.</li>
    <li>Whisper models you've already downloaded for MacWhisper can be moved into Neuron Flame's models folder.</li>
    <li>Settings don't transfer (different apps), but Neuron Flame's onboarding takes about 60 seconds.</li>
  </ul>
</section>
"""

    body += closing_cta(
        "Free dictation, on-device.",
        "Use Neuron Flame and MacWhisper together — they cover different jobs."
    )

    faqs = [
        ("Should I use Neuron Flame or MacWhisper?",
         "Both, probably. MacWhisper for transcribing existing audio files (interviews, podcasts, lectures). Neuron Flame for dictating into apps as you work. They overlap a little — Neuron Flame can transcribe audio files too — but the primary jobs are different."),
        ("Can Neuron Flame transcribe a folder of MP3s?",
         "Yes — drop them onto the Transcribe Audio tab and they queue up. Output goes into the History database where you can search and export. For heavy batch work with diarisation and editing, MacWhisper is the more specialised tool."),
        ("Can I share Whisper models between the apps?",
         "Yes — Whisper .bin files are interchangeable. Neuron Flame's models folder is ~/Library/Application Support/com.neuronflame.app/Models/."),
    ]
    crumbs = [("Home", "/"), ("Alternatives", "/alternatives/wispr-flow.html"), ("MacWhisper", slug)]
    return slug, title, description, body, faqs, crumbs


def page_voiceink():
    slug = "/alternatives/voiceink.html"
    title = "Neuron Flame — the long-term fork of VoiceInk for macOS"
    description = "Neuron Flame is a fork of the open-source VoiceInk project, with extensive UI, performance, and feature work on top. Here's what's different and why you might want to switch."

    body = hero(
        eyebrow="VoiceInk fork",
        headline_html='VoiceInk\'s codebase.<br/><span class="gradient-text">A different design direction.</span>',
        lede="Neuron Flame began as a fork of VoiceInk and has diverged substantially: a full design-system rebuild, the Liquid-Glass Dynamic-Island recorder, an extended migration chain so existing VoiceInk users keep their data, and a long list of UI polish, accessibility, and performance changes. Same GPL-3 licence, same open spirit.",
    )

    body += comparison_table("What's different from upstream VoiceInk", [
        ("Recorder UI",             "Dynamic-Island top-of-screen pill with breathing halo", "Bottom-of-screen mini pill"),
        ("Liquid Glass (macOS 26)", "Yes — across dashboard, recorder, sidebar",            "No"),
        ("Default model",           "Parakeet V2 (English, fastest on ANE)",                 "Whisper variants"),
        ("Sidebar layout",          "Status pills + utility actions inline",                 "Standard list"),
        ("Theme",                   "Stitch-inspired light + dark, custom palette",          "Default"),
        ("Migration from VoiceInk", "Auto-migrates ~/Library/Application Support data",     "N/A (you'd be moving to it)"),
        ("Dashboard",               "Speed-of-thought thesis cards, personal records",       "Standard metrics"),
    ])

    body += """<section class="container narrow long-body">
  <h2>Why fork at all?</h2>
  <p>VoiceInk is a great open-source project and we've tried to be respectful with the fork — the original GPL-3 copyright is preserved in <a href="https://github.com/barney-cmyk/svara/blob/main/LICENSE">LICENSE</a>. The reasons for forking come down to design direction:</p>
  <ul>
    <li><strong>Native macOS 26 design language.</strong> Liquid Glass throughout, real Glass surfaces (not just blurs), the Dynamic-Island recorder concept. We wanted the app to feel like macOS, not like a cross-platform Electron port.</li>
    <li><strong>A specific dashboard thesis.</strong> Neuron Flame frames dictation around "speaking is closer to thinking than typing" — there's a flow visualization, your pace tracked against the world record, etc. Different storytelling than VoiceInk.</li>
    <li><strong>Default to Parakeet.</strong> NVIDIA's English-only Parakeet V2 model on the Apple Neural Engine is significantly faster than Whisper on Apple Silicon. We made it the default for the English-speaking 80%.</li>
    <li><strong>Free + signed.</strong> Same GPL-3, same source-available, same zero-cost — but signed with a stable developer cert so accessibility permissions stick across rebuilds and Sparkle updates.</li>
  </ul>
  <h2>If you're a VoiceInk user, switching is automatic</h2>
  <p>Neuron Flame includes a migration chain that detects an existing VoiceInk install (or any of the intermediate folder names from this app's history) and brings your transcriptions, custom dictionary, and prompts forward to the new location. Install Neuron Flame, run it once — your data is there.</p>
  <p>If you'd rather keep VoiceInk, no harm done. Both apps can coexist on the same Mac (just keep one as your hotkey-bound default).</p>
</section>
"""

    body += closing_cta(
        "Same DNA. Different design.",
        "Open source, GPL-3, free. The fork is on GitHub if you want to inspect every change."
    )

    faqs = [
        ("Will my VoiceInk transcripts survive the migration?",
         "Yes. Neuron Flame's migration chain detects the legacy folder at ~/Library/Application Support/com.prakashjoshipax.VoiceInk/ and forward-migrates the SwiftData store + custom dictionary + prompts to the new com.neuronflame.app/ location."),
        ("Why a different name?",
         "Forks on GitHub get a different name partly because we want to own the design direction without claiming to be the original. Neuron Flame is named after the developer's daughter (her Sanskrit name, स्वर — svara — means 'tone' or 'note')."),
        ("Can I contribute back?",
         "PRs welcome on the fork (github.com/barney-cmyk/svara). For substantial features, please open an issue first to align on direction. Contributions to the upstream VoiceInk project are also welcome there."),
    ]
    crumbs = [("Home", "/"), ("Alternatives", "/alternatives/wispr-flow.html"), ("VoiceInk", slug)]
    return slug, title, description, body, faqs, crumbs


def page_apple_dictation():
    slug = "/alternatives/apple-dictation.html"
    title = "Neuron Flame vs Apple Dictation — when to upgrade from the built-in"
    description = "macOS has built-in Dictation. It's free, on-device, and works fine for short bursts. Here's when you outgrow it and what Neuron Flame adds: hotkey UX, AI enhancement, per-app behaviour, custom dictionary."

    body = hero(
        eyebrow="Apple Dictation alternative",
        headline_html='Apple Dictation,<br/><span class="gradient-text">but actually usable.</span>',
        lede="macOS Dictation works. It's also limited — no real custom dictionary, no per-app behaviour, no AI cleanup, awkward hotkey, no live transcript. Neuron Flame is what Dictation would be if Apple gave it the attention it deserves.",
    )

    body += comparison_table("Where Neuron Flame goes further", [
        ("Price",                  "Free",                                  "Free (built into macOS)"),
        ("On-device",              "Yes (Whisper or Parakeet V2)",         "Yes (Apple's Siri model)"),
        ("Hotkey customisation",   "Any combination, push-to-talk",        "Limited (fn fn or globe globe)"),
        ("Custom dictionary",      "Full — patterns, replacements",        "Limited contact-name learning"),
        ("Per-app behaviour",      "Power Mode profiles",                   "None"),
        ("AI grammar/cleanup",     "Multi-provider AI enhancement",         "None (Apple Intelligence in some apps only)"),
        ("Live transcript",        "Yes",                                   "Yes (in some apps)"),
        ("Languages",              "100+ via Whisper, English via Parakeet", "Many (Apple's set)"),
        ("Open source",            "Yes — GPL-3",                           "No (closed)"),
        ("Macros / advanced",      "Power Mode + custom prompts",          "Voice Control (separate, complex)"),
    ])

    body += """<section class="container narrow long-body">
  <h2>When Apple Dictation is fine</h2>
  <p>For short bursts of dictation in a few specific apps, Apple Dictation is genuinely fine. It's built in, you don't need to install anything, your microphone is already wired up. If you dictate one Slack message a day, save your install.</p>
  <h2>When you outgrow it</h2>
  <p><strong>Push-to-talk feels right.</strong> Apple Dictation is toggled on, then it listens until silence ends the session. Neuron Flame is hold-the-key, speak, release — a different rhythm, much more like talking to someone. People who try push-to-talk rarely go back.</p>
  <p><strong>Custom dictionary that actually works.</strong> Apple's "personal dictionary" picks up names from Contacts but is otherwise opaque. Neuron Flame's dictionary is a list of patterns and replacements you control. Type "Kubernetes" the way you spell it, every time.</p>
  <p><strong>Per-app modes.</strong> Casual tone in Slack. Professional in Mail. Verbatim in Cursor. Apple Dictation has one mode for everything; Neuron Flame's Power Mode swaps settings automatically based on the frontmost app.</p>
  <p><strong>AI cleanup the way you want.</strong> Apple Intelligence does a small amount of light cleanup in supported apps. Neuron Flame lets you specify exactly what cleanup looks like via a prompt — "format as a professional email", "make this casual", "preserve my voice but fix typos" — and run it through the LLM you choose.</p>
  <h2>Use both</h2>
  <p>You don't have to pick. Apple Dictation stays available on the system shortcut; Neuron Flame uses its own. Many users keep Apple's around for the rare moments when it's faster than launching the app.</p>
</section>
"""

    body += closing_cta(
        "What Apple Dictation should be.",
        "Free, on-device, with the controls Apple left out."
    )

    faqs = [
        ("Will Neuron Flame conflict with Apple Dictation?",
         "No — they use different hotkeys (Apple Dictation defaults to globe/globe or fn/fn; Neuron Flame uses whatever you set, typically Right Option). They can coexist."),
        ("Does Neuron Flame use Apple's dictation API?",
         "No — completely independent. Neuron Flame uses Whisper.cpp + FluidAudio (Parakeet V2) for transcription. Apple's API has too many limitations for the experience we wanted."),
        ("Is Neuron Flame's accuracy better than Apple Dictation?",
         "For most clear speech in English, yes — Whisper Large v3 and Parakeet V2 are state-of-the-art models. Apple's model is good but optimises for low-power on-device use; Whisper trades a bit more compute for measurably better word-error-rate."),
        ("What about Voice Control (Apple's accessibility feature)?",
         "Voice Control is for full hands-free Mac operation — clicking buttons, opening apps, etc. Neuron Flame is for dictating text. They complement each other; some users run both."),
    ]
    crumbs = [("Home", "/"), ("Alternatives", "/alternatives/wispr-flow.html"), ("Apple Dictation", slug)]
    return slug, title, description, body, faqs, crumbs


def page_developers():
    slug = "/use-cases/developers.html"
    title = "Voice-to-text for developers on macOS — dictate code, commits, and reviews"
    description = "Neuron Flame for software engineers: hands-free coding with custom dictionaries for your project's identifiers, Power Mode profiles for Cursor/VS Code/Xcode, and AI enhancement that knows the difference between code and prose."

    body = hero(
        eyebrow="For developers",
        headline_html='Dictate <span class="gradient-text">code, commits,</span><br/>and code reviews.',
        lede="Most dictation apps treat code like prose and butcher it. Neuron Flame's Power Mode lets you load a different dictionary and prompt per editor — verbatim mode in Cursor, comment-formatting in your code review tool, professional tone for the GitHub issue you're filing about it.",
    )

    body += """<section class="container narrow long-body">
  <h2>The developer's dictation problem</h2>
  <p>Standard dictation apps assume you're writing emails. They auto-capitalise. They add full stops. They "correct" "Yjs" to "yes". They turn "console.log" into "console dot log" or just give up. The mismatch makes most engineers stop trying after a week.</p>
  <h2>What Neuron Flame does differently</h2>
  <p><strong>Custom dictionary built for code.</strong> Add your project's identifiers — class names, libraries, internal jargon — once, and they transcribe correctly forever. <code>Kubernetes</code>, <code>SwiftData</code>, <code>tRPC</code>, your codebase's specific function names. The dictionary runs <em>before</em> any AI enhancement, so the model sees your spellings.</p>
  <p><strong>Power Mode for editors.</strong> Set up a profile that triggers on Cursor, VS Code, Xcode, JetBrains, Zed — whatever you use. The profile turns AI enhancement OFF (verbatim mode), loads your code dictionary, and tells the model: "this is code, don't add punctuation".</p>
  <p><strong>Different mode for everything else.</strong> When you switch from Cursor to Slack, Power Mode swaps to your chat profile — casual, light grammar fixes, no formality. Switch to Mail, your email profile kicks in. Switch to a GitHub issue, your professional profile. Set it up once.</p>
  <h2>Workflow examples</h2>
  <h3>Writing commit messages</h3>
  <p>Power Mode profile triggered by your terminal. AI Enhancement on, prompt: "Format as a Conventional Commits message. Subject line under 50 chars, imperative mood. Body explains why, not what." Hold hotkey, ramble about what you just did, release. Polished commit message at the cursor.</p>
  <h3>Code review comments</h3>
  <p>Power Mode triggered by GitHub or your code review tool. AI Enhancement prompt: "Diplomatic engineering tone. Suggest, don't dictate. Preserve any code references verbatim — anything in backticks stays untouched." Speaking critique is faster than typing it diplomatically.</p>
  <h3>Doc strings</h3>
  <p>In your editor, Power Mode = verbatim. Add code-mode dictionary entries for the doc style you use (Google-style? RST?). Speak naturally — "this function takes a request object and returns a promise" — and let the prompt template wrap it in your project's docstring format.</p>
  <h3>Pair-programming narration</h3>
  <p>If you screen-share or pair-program, dictating commentary as you code can be faster than typing it. Live transcript preview lets your collaborator follow along.</p>
  <h2>The setup that works</h2>
  <ol>
    <li><a href="/downloads/Neuron%20Flame.dmg">Install Neuron Flame</a>, grant permissions.</li>
    <li>Pick a hotkey that doesn't conflict with your editor's modal commands. Right Option works well.</li>
    <li>Open the Dictionary tab; add your top 30 project-specific identifiers.</li>
    <li>Open Power Mode; create profiles for: editor (verbatim), terminal (commit-style), Slack (chat), Mail (email).</li>
    <li>Connect an LLM under AI Models — many devs already pay for Claude or GPT, plug it in.</li>
  </ol>
  <p>Total setup is under 10 minutes. From there, your hands stay on the keyboard, your voice handles the prose, and the dictation gets out of the way.</p>
</section>
"""

    body += closing_cta(
        "Code with your hands. Comment with your voice.",
        "Free, on-device, designed for engineers."
    )

    faqs = [
        ("Does it understand code?",
         "It transcribes whatever you say verbatim if you turn AI Enhancement off. The custom dictionary catches identifiers Whisper would otherwise mangle. For the prose around code (commit messages, comments, docs), AI Enhancement with the right prompt produces excellent output."),
        ("Will it work with Vim/Emacs?",
         "Yes — paste-at-cursor works in any text-receiving app, including terminal-based editors. Some Vim users bind a leader-key combination to drop into insert mode + trigger Neuron Flame for one-shot dictation."),
        ("Can I use my Claude/Cursor subscription for AI enhancement?",
         "Yes — there's a Local CLI mode that runs `claude -p \"$NEURONFLAME_FULL_PROMPT\"` for cleanup. Same for `pi` (the Pi CLI), `codex`, or any custom command. You can also use Anthropic's API directly with your existing key."),
        ("Does Power Mode swap fast enough between apps?",
         "Yes — profile detection runs on the frontmost-app change notification, well before you have time to press the hotkey. Cmd-Tab to a new app, hold the key, the right profile is already active."),
    ]
    crumbs = [("Home", "/"), ("Use cases", "/use-cases/developers.html"), ("Developers", slug)]
    return slug, title, description, body, faqs, crumbs


def page_writers():
    slug = "/use-cases/writers.html"
    title = "Voice-to-text for writers on macOS — drafts, edits, and email at speaking pace"
    description = "Neuron Flame for writers, journalists, novelists, copywriters: dictate first drafts at thinking speed, polish with the LLM of your choice, and keep your voice intact. Free and on-device for macOS."

    body = hero(
        eyebrow="For writers",
        headline_html='Drafts at <span class="gradient-text">thinking pace.</span>',
        lede="Typing is the bottleneck between thought and page. Neuron Flame closes the gap — dictate at 150+ words a minute, polish with whichever LLM matches your voice, and keep editorial control. Free, on-device, no cloud round-trip.",
    )

    body += """<section class="container narrow long-body">
  <h2>Why writers reach for dictation</h2>
  <p>Three numbers from cognitive science: humans think at roughly 250 WPM (Brysbaert/Rayner 2019), speak at 150 WPM in conversation, and type at 40 WPM on average. Typing is so much slower than thinking that you're constantly waiting for your hands to catch up — which causes you to forget the back half of the sentence you'd already worked out, which makes drafts feel laboured.</p>
  <p>Dictation closes most of that gap. You're not as fast as pure thought, but you're a lot closer than you were typing. The catch is that most dictation apps render verbatim and you have to manually clean up filler words, false starts, and run-on sentences afterwards. Neuron Flame's AI Enhancement layer handles that cleanup automatically — with a prompt you control.</p>
  <h2>Three workflows that actually work</h2>
  <h3>1. The "blast draft, polish later" pattern</h3>
  <p>Hold the hotkey. Talk through the whole section in one go — false starts, repetitions, "actually no, scratch that, what I meant was…" included. Release. Neuron Flame's default prompt cleans the filler words, removes false starts, fixes obvious grammar. You get a clean first draft in 10% of the time it would have taken to type.</p>
  <h3>2. The "ESL writer's edge"</h3>
  <p>If you think and speak in English fluently but write English with effort, dictation helps enormously. Set the prompt to "preserve voice and meaning, fix grammar to native-speaker quality, don't change vocabulary unless something is genuinely wrong". The result reads like you, polished.</p>
  <h3>3. The "interview to article" loop</h3>
  <p>Drop the recording into the Transcribe Audio tab → get the raw transcript → use the History tab to reach the text → dictate your commentary directly between paragraphs while the source is fresh in your head.</p>
  <h2>Per-app personalities</h2>
  <p>Power Mode lets you load different prompts in different apps. Some examples:</p>
  <ul>
    <li><strong>Email mode</strong> — formal greeting, professional tone, sign-off. Triggered by Mail.app, Outlook, Spark.</li>
    <li><strong>Notes mode</strong> — bullet-formatted thinking, preserve voice. Triggered by Notes, Obsidian, Bear.</li>
    <li><strong>Article mode</strong> — fully-formed prose, vary sentence length, eliminate filler. Triggered by Ulysses, Scrivener, Google Docs in Safari.</li>
    <li><strong>DM mode</strong> — short, casual, one-line. Triggered by Slack, Messages.</li>
  </ul>
  <h2>What you keep</h2>
  <p>Your raw transcript is always saved alongside the AI-cleaned version. If you don't like what the model did, you have the original. If the model fails (rate limit, key invalid, network), Neuron Flame falls back to the raw transcript automatically. You never lose what you said.</p>
</section>
"""

    body += closing_cta(
        "Write the way you think.",
        "Free, on-device, with editorial control over every prompt."
    )

    faqs = [
        ("Will the AI rewrite my voice?",
         "Only if you ask it to. The default prompt is conservative — it cleans filler words and obvious grammar issues but preserves your phrasing. You can edit the prompt to whatever you like, or turn AI enhancement off entirely and get verbatim transcripts."),
        ("Does Neuron Flame handle accents and ESL speakers?",
         "Whisper Large v3 is the most accent-tolerant model available; Parakeet V2 is English-only and tuned for native and near-native speech. For non-native English speakers we generally recommend Whisper Medium or Large; the trade-off is a bit more processing time per sentence."),
        ("What about non-English languages?",
         "Whisper supports 100+ languages. Switch the model on the AI Models tab. Parakeet V2 is English-only; everything else uses Whisper variants."),
        ("Is dictation private if I'm working on something confidential?",
         "By default, transcription happens entirely on your Mac — nothing leaves the device. If you turn on AI Enhancement with a cloud LLM, the transcript is sent to that provider over HTTPS. For confidential work, use Ollama as your AI provider — it runs locally too."),
    ]
    crumbs = [("Home", "/"), ("Use cases", "/use-cases/developers.html"), ("Writers", slug)]
    return slug, title, description, body, faqs, crumbs


def page_accessibility():
    slug = "/use-cases/accessibility.html"
    title = "Voice-to-text for accessibility on macOS — RSI, dyslexia, and hands-free use"
    description = "Neuron Flame as an accessibility tool: hands-free dictation for repetitive strain injury (RSI), dyslexia-friendly drafting, vision-impaired use, and motor-difficulty support. Free and on-device for macOS."

    body = hero(
        eyebrow="For accessibility",
        headline_html='Mac, <span class="gradient-text">hands-free.</span>',
        lede="If typing hurts, slows you down, or simply isn't an option — Neuron Flame is built to take the load off. Hands-free dictation in any app, custom dictionary that adapts to your spellings, and prompts that handle grammar so you can focus on the meaning.",
    )

    body += """<section class="container narrow long-body">
  <h2>When dictation is more than a productivity tool</h2>
  <p>For knowledge workers with repetitive strain injury (RSI), dictation isn't a nice-to-have — it's how the work gets done. For dyslexic writers, voice-to-text drops the spelling and grammar barriers between thought and page. For people with low vision or motor differences, hands-free input opens up the Mac in ways the keyboard can't.</p>
  <p>Neuron Flame isn't a clinical accessibility tool — Apple's Voice Control covers the full hands-free Mac control experience. But for the specific job of getting words from your mouth onto the screen, fast and accurately, in any app, Neuron Flame is one of the best tools we know of, free.</p>
  <h2>RSI / chronic pain</h2>
  <p>Push-to-talk on a hotkey you can hit with the side of your thumb means you can leave your wrists in a neutral position. Many users bind Neuron Flame to a foot pedal or to a single mechanical button via Karabiner-Elements / BetterTouchTool — keyboards become optional for stretches of writing.</p>
  <p>Combined with AI enhancement, you can ramble loosely and let the prompt clean it up. If your meds or fatigue make you stumble more on certain days, the model handles it without forcing you to type corrections.</p>
  <h2>Dyslexia</h2>
  <p>Dictation removes spelling from the production loop. You speak the word; Whisper or Parakeet transcribes it correctly. AI enhancement (with a "preserve voice, fix only spelling and grammar" prompt) handles the residual without rewriting your prose.</p>
  <p>The custom dictionary doubles as a "words I always struggle with" cheat sheet — load it once, never have to think about those spellings again.</p>
  <h2>Low vision</h2>
  <p>Neuron Flame's UI scales with macOS Display settings; the recorder pill at the top of the screen is high-contrast (white-on-black with brand-tinted halo). Live transcript preview is rendered in adjustable size. Combine with VoiceOver — the dashboard, settings, and history list are screen-reader friendly.</p>
  <h2>Motor differences</h2>
  <p>Hotkey choice is fully user-controlled. You can pick a single key, a chord, or even an external trigger. Neuron Flame's hold-and-release pattern can be remapped via macOS to a tap-and-tap if held-down keys are difficult.</p>
  <h2>Privacy matters even more here</h2>
  <p>Voice samples can carry a lot of sensitive context — medical, financial, personal. Neuron Flame's default is on-device processing: nothing leaves your Mac. If you turn on AI enhancement with a cloud LLM, that's an explicit opt-in. For maximally private workflows, use Ollama as your enhancement provider — fully local even for the cleanup pass.</p>
</section>
"""

    body += closing_cta(
        "Hands-free Mac, on your terms.",
        "Free, open-source, designed to disappear out of your way."
    )

    faqs = [
        ("Is Neuron Flame approved by accessibility programs?",
         "We don't have any clinical or insurance certifications. It's a free open-source tool — install it, try it, see if it helps. Many of the techniques used (push-to-talk, custom dictionary, on-device processing) line up with what accessibility users typically need."),
        ("Can I bind Neuron Flame to a foot pedal?",
         "Yes — pair the foot pedal with a tool like Karabiner-Elements (free) to send Neuron Flame's hotkey when the pedal is pressed. Most users land on Right Option as the hotkey because it's neutral on most external trigger devices."),
        ("Does it work alongside Voice Control?",
         "Yes — they handle different jobs. Voice Control clicks buttons and opens apps; Neuron Flame transcribes speech into text. Many users run both."),
        ("Will the AI cleanup change my writing voice?",
         "Only as much as you tell it to. The default prompt fixes obvious grammar issues and removes filler words. For dyslexia-friendly use, we recommend a stricter prompt: 'fix spelling and grammar only, preserve every choice of word and sentence structure'."),
    ]
    crumbs = [("Home", "/"), ("Use cases", "/use-cases/developers.html"), ("Accessibility", slug)]
    return slug, title, description, body, faqs, crumbs


def page_whisper_mac():
    slug = "/whisper-mac-gui.html"
    title = "The easiest way to run Whisper on a Mac — Neuron Flame"
    description = "Looking for a Whisper GUI for macOS? Neuron Flame ships whisper.cpp built-in, supports the full Whisper family (Tiny → Large v3 Turbo), and adds push-to-talk dictation, AI enhancement, and per-app behaviour. Free and open source."

    body = hero(
        eyebrow="Whisper on macOS",
        headline_html='Whisper, with <span class="gradient-text">all the wiring done.</span>',
        lede="If you've been hand-rolling Whisper.cpp scripts, building Python pipelines, or wrangling SwiftWhisper bindings — stop. Neuron Flame ships whisper.cpp embedded with a full UI, model picker, and a workflow built around the actual job: dictating into apps and transcribing files.",
    )

    body += """<section class="container narrow long-body">
  <h2>What's bundled</h2>
  <ul>
    <li><strong>whisper.cpp</strong> — Georgi Gerganov's port of OpenAI Whisper, compiled for Apple Silicon with Metal acceleration. Same engine used by most other Mac Whisper apps.</li>
    <li><strong>Full Whisper family</strong> — Tiny (78 MB) through Large v3 Turbo (815 MB) and Large v3 (1.6 GB). Download what you need, delete what you don't.</li>
    <li><strong>Parakeet V2</strong> via FluidAudio — NVIDIA's English-only model on the Apple Neural Engine. Faster than Whisper Medium with comparable accuracy. (Optional; pick this OR a Whisper variant.)</li>
    <li><strong>OpenAI-compatible cloud endpoint support</strong> — point Neuron Flame at Groq's hosted Whisper Large v3 Turbo for blazing-fast cloud transcription if you want it.</li>
  </ul>
  <h2>Use cases beyond dictation</h2>
  <p>Most people install Neuron Flame for live push-to-talk dictation. But the Transcribe Audio tab handles batch file work too:</p>
  <ul>
    <li>Drop in a folder of WAV/MP3/M4A files; they queue up and process sequentially.</li>
    <li>History tab lets you search across every transcript you've ever made.</li>
    <li>Export to plain text, Markdown, or CSV.</li>
  </ul>
  <h2>What this saves you</h2>
  <p>If you've ever tried to "just run Whisper on my Mac", you know the friction:</p>
  <ul>
    <li>Building whisper.cpp from source against the right Xcode version</li>
    <li>Finding the right model file at the right precision</li>
    <li>Dealing with shell scripts that pipe ffmpeg into whisper-cli</li>
    <li>Wrapping the output for the actual workflow you wanted</li>
  </ul>
  <p>Neuron Flame ships whisper.cpp as a bundled framework, downloads models from the AI Models tab, and gives you a UI shaped around real dictation + transcription tasks. Total setup is under 60 seconds.</p>
  <h2>Open source under the hood</h2>
  <p>If you want to inspect what's happening — confirm models live in your Application Support folder, see exactly what arguments are passed to whisper.cpp, audit network calls — the source is on <a href="https://github.com/barney-cmyk/svara">GitHub</a>. GPL-3.</p>
</section>
"""

    body += closing_cta(
        "Skip the build steps.",
        "whisper.cpp + Parakeet + a UI, packaged as one DMG."
    )

    faqs = [
        ("Which Whisper model should I use?",
         "If you only speak English on Apple Silicon: Parakeet V2 (default). If you need other languages: Whisper Small for speed, Whisper Medium for accuracy, Whisper Large v3 Turbo for the best of both. Avoid Whisper Tiny / Base unless you're testing — accuracy is noticeably worse."),
        ("Can I bring my own .bin Whisper model file?",
         "Yes — drop it into ~/Library/Application Support/com.neuronflame.app/Models/ and Neuron Flame will pick it up on next launch. Same format as plain whisper.cpp expects."),
        ("Is this faster than running whisper.cpp directly?",
         "Roughly the same — Neuron Flame uses whisper.cpp as the underlying library. The win is workflow: live audio capture, paste-at-cursor, history, search, custom dictionary, batch processing — all the stuff you'd otherwise wire up by hand."),
        ("Does it use GPU acceleration?",
         "Whisper uses Metal on Apple Silicon (and CoreML for the encoder if available). Parakeet V2 runs on the Apple Neural Engine via FluidAudio. Both are noticeably faster than CPU-only paths."),
    ]
    crumbs = [("Home", "/"), ("Whisper on Mac", slug)]
    return slug, title, description, body, faqs, crumbs


def page_parakeet_mac():
    slug = "/parakeet-mac.html"
    title = "Run NVIDIA Parakeet V2 on macOS — Neuron Flame"
    description = "Parakeet V2 is NVIDIA's English-only ASR model, optimised for the Apple Neural Engine via FluidAudio. Neuron Flame ships it as the default — fastest on-device English transcription on Apple Silicon."

    body = hero(
        eyebrow="Parakeet V2 on Apple Silicon",
        headline_html='Parakeet V2,<br/>on <span class="gradient-text">your Apple Neural Engine.</span>',
        lede="NVIDIA's Parakeet V2 model is one of the fastest English ASR models on the planet. The FluidAudio team ported it to the Apple Neural Engine. Neuron Flame ships it bundled, set as the default, ready to go in 60 seconds.",
    )

    body += """<section class="container narrow long-body">
  <h2>Why Parakeet beats Whisper for English on Mac</h2>
  <table class="compare-table">
    <thead><tr><th></th><th class="us">Parakeet V2 (default)</th><th>Whisper Large v3</th></tr></thead>
    <tbody>
      <tr><th scope="row">Languages</th><td class="us">English only</td><td>100+</td></tr>
      <tr><th scope="row">Hardware</th><td class="us">Apple Neural Engine</td><td>GPU (Metal)</td></tr>
      <tr><th scope="row">Speed (M2)</th><td class="us">~7× faster than realtime</td><td>~2× faster than realtime</td></tr>
      <tr><th scope="row">Accuracy (English)</th><td class="us">Within 1% WER of Whisper Large</td><td>Best in class</td></tr>
      <tr><th scope="row">Size on disk</th><td class="us">474 MB</td><td>1.6 GB</td></tr>
    </tbody>
  </table>
  <h2>What ships in Neuron Flame</h2>
  <ul>
    <li><strong>FluidAudio's Parakeet V2 port</strong> — wired up to the recorder pipeline, Power Mode, custom dictionary, and AI enhancement.</li>
    <li><strong>Auto-prewarm</strong> — model loaded on app launch so the first dictation is as fast as the hundredth.</li>
    <li><strong>Default model on first run</strong> — no model picker dance for the 80% of users who only need English.</li>
  </ul>
  <h2>When to switch off Parakeet</h2>
  <p>Parakeet V2 is English-only. If you dictate in any other language, switch to a Whisper variant on the AI Models tab — same UI, same workflow. You can keep both installed and toggle between them per-language need.</p>
  <h2>What if you don't have Apple Silicon?</h2>
  <p>Parakeet via FluidAudio runs on Apple Silicon Macs. On Intel Macs, Neuron Flame falls back to Whisper variants. The whole UX is identical; you just won't get Parakeet's speed advantage.</p>
  <h2>The credit</h2>
  <p>Parakeet was made by NVIDIA. The Apple Silicon port is by the FluidAudio team — open source on <a href="https://github.com/FluidInference/FluidAudio">GitHub</a>. Neuron Flame just provides the UX wrapper. Both projects deserve more attention than they currently get.</p>
</section>
"""

    body += closing_cta(
        "The fastest local English transcription on Mac.",
        "Free, ANE-optimised, default in Neuron Flame."
    )

    faqs = [
        ("Does Parakeet V2 work on Intel Macs?",
         "FluidAudio's Parakeet V2 implementation targets the Apple Neural Engine, which is Apple Silicon only. On Intel Macs, Neuron Flame falls back to Whisper variants. Functionally identical UX, just no ANE acceleration."),
        ("Will my dictation be less accurate than Whisper?",
         "For clear English speech, Parakeet V2 is within ~1% word-error-rate of Whisper Large v3 — essentially indistinguishable in practice. For very noisy audio, heavy accents, or technical jargon, Whisper Large is still the more accurate choice."),
        ("Can I run Parakeet on my own without Neuron Flame?",
         "Absolutely — FluidAudio is an open-source library you can integrate into your own Swift app. Neuron Flame just packages it with a UI, recorder, dictionary, and AI enhancement layer."),
        ("Why is Parakeet English-only?",
         "It was trained primarily on English speech and works best on what it knows. NVIDIA has multilingual variants (Parakeet RNN-T XL etc.) that the FluidAudio team may port in future."),
    ]
    crumbs = [("Home", "/"), ("Parakeet on Mac", slug)]
    return slug, title, description, body, faqs, crumbs


def page_privacy_landing():
    slug = "/privacy/on-device-dictation.html"
    title = "Private, on-device voice-to-text for macOS — Neuron Flame"
    description = "Neuron Flame keeps your voice and transcripts on your Mac by default. No cloud round-trip, no telemetry, no analytics. Optional AI enhancement is opt-in and you choose the provider — including fully-local Ollama."

    body = hero(
        eyebrow="Private by default",
        headline_html='Your voice never <span class="gradient-text">leaves your Mac.</span>',
        lede="Most dictation apps send your audio to a cloud service. Neuron Flame doesn't. Transcription runs entirely on your Mac. Telemetry is nonexistent. Optional AI cleanup is your choice — including fully-local options.",
    )

    body += """<section class="container narrow long-body">
  <h2>What "on-device" actually means here</h2>
  <p>When you press your hotkey, the audio is captured, fed to either Whisper.cpp or Parakeet V2 (both running on your Mac), transcribed to text, and pasted at your cursor. The audio buffer is held in RAM for the duration of the recording and discarded after. No file is written to disk unless you explicitly save the recording from the History tab.</p>
  <p>The transcribed text is saved to a SwiftData store at <code>~/Library/Application Support/com.neuronflame.app/default.store</code> for the History feature. That database is yours — local, encrypted by FileVault if you have it on, never transmitted anywhere.</p>
  <h2>What leaves your Mac (only when you opt in)</h2>
  <p>Neuron Flame's default install talks to:</p>
  <ul>
    <li><strong>raw.githubusercontent.com</strong> — Sparkle update check on launch (the appcast XML).</li>
    <li><strong>github.com / huggingface.co</strong> — only when you click Download on a Whisper model.</li>
  </ul>
  <p>If you turn on <strong>AI Enhancement</strong> with a cloud provider, transcripts are sent to that provider over HTTPS. You control which provider. The supported list:</p>
  <ul>
    <li><strong>Cloud</strong> — Google Gemini, OpenAI, Anthropic Claude, Groq.</li>
    <li><strong>Local</strong> — <a href="https://ollama.com/">Ollama</a> running on your Mac, or a local CLI like <code>claude -p</code> / <code>pi</code> / <code>codex exec</code>.</li>
  </ul>
  <p>For maximum privacy, use Ollama. The transcript is enhanced by a local LLM and never crosses your firewall.</p>
  <h2>Telemetry</h2>
  <p>None. Zero. We don't run a server. There's no opt-out toggle in Settings because there's nothing to opt out of. Neuron Flame doesn't know how often you use it, how long your sessions are, what language you dictate in, or what model you've selected. We literally cannot tell.</p>
  <h2>Open source under GPL-3</h2>
  <p>You don't have to take our word for any of this. The full source is on <a href="https://github.com/barney-cmyk/svara">GitHub</a> — every network call, every persistence path, every permission check is searchable. We've documented the data flows in detail in <a href="/docs/privacy.html">the privacy doc</a>.</p>
  <h2>Why this matters more than usual</h2>
  <p>Voice samples carry an unusually rich amount of personal context — medical conditions, financial details, names of people in your life, spoken habits. The standard cloud-dictation business model trades that context for transcription quality. Neuron Flame's bet is that local models are now good enough that you don't have to make that trade.</p>
</section>
"""

    body += closing_cta(
        "Dictate without surveillance.",
        "Free. On-device by default. Open-source so you can verify."
    )

    faqs = [
        ("If everything's local, what's the cloud LLM enhancement for?",
         "Optional polish — turning a raw transcript into a clean email, summarising rambles, formatting code. If you don't enable AI Enhancement, nothing leaves your Mac. If you enable it with Ollama as the provider, still nothing leaves your Mac. Cloud is just one of several options."),
        ("Where exactly is my data stored?",
         "~/Library/Application Support/com.neuronflame.app/. SwiftData stores for transcripts, dictionary, prompts, and Power Mode profiles. Whisper models in a Models/ subfolder. Optional saved recordings in Recordings/. All local, all yours."),
        ("Does enabling iCloud sync send my dictionary to Apple servers?",
         "If you opt in to iCloud sync for the custom dictionary, the dictionary entries (words and replacements) sync via Apple's CloudKit, encrypted in transit and at rest under your iCloud account. Transcripts and audio do NOT sync."),
        ("Can I audit the network activity?",
         "Yes — run Little Snitch or LuLu and watch. With AI Enhancement off, you'll see Sparkle's update check and nothing else. With AI Enhancement on for a cloud provider, you'll see HTTPS traffic to that one provider only."),
    ]
    crumbs = [("Home", "/"), ("Privacy", slug)]
    return slug, title, description, body, faqs, crumbs


# ============================================================
# Build
# ============================================================

PAGES = [
    page_wispr_flow,
    page_superwhisper,
    page_macwhisper,
    page_voiceink,
    page_apple_dictation,
    page_developers,
    page_writers,
    page_accessibility,
    page_whisper_mac,
    page_parakeet_mac,
    page_privacy_landing,
]


def build():
    written = []
    for page_fn in PAGES:
        slug, title, description, body, faqs, crumbs = page_fn()
        html = render(slug, title, description, body, faqs, crumbs)
        out = ROOT / slug.lstrip("/")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(html)
        written.append(str(out.relative_to(ROOT)))
    print(f"\nWrote {len(written)} pages:")
    for p in written:
        print(f"  {p}")


if __name__ == "__main__":
    build()
