#!/usr/bin/env python3
"""
THROWAWAY proof-of-concept: generate ONE cosmic avatar via Imagen (Vertex REST).

Not production. No Storage, no Firestore. Just: prompt -> Imagen -> local PNGs
so we can eyeball the mythic-playful house style before building the pipeline.

Usage:
    python3 gen_test_avatar.py "Purva Bhadrapada" male
    python3 gen_test_avatar.py "Rohini" female

Auth: uses your active gcloud account's access token (gcloud auth print-access-token).
"""
import base64
import json
import os
import subprocess
import sys
import urllib.request

PROJECT = "ty-dev-516d7"
LOCATION = "us-central1"          # Imagen's most reliable region
MODEL = "imagen-3.0-generate-002"
SAMPLE_COUNT = 4
OUT_DIR = os.path.join(os.path.dirname(__file__), "avatar_out")

# --- The locked mythic-playful "house style". This is what we're testing. ---
HOUSE_STYLE = (
    "Mythic-playful collectible character portrait, digital illustration in a warm "
    "semi-stylized painterly style with clean shapes and soft cosmic rim-light. "
    "Centered head-and-shoulders bust of a single friendly celestial being with big "
    "soulful expressive eyes and an appealing, approachable face. Deep night-sky "
    "starfield gradient background with a subtle nebula glow. Cohesive trading-card / "
    "companion-avatar aesthetic, polished and highly detailed. No text, no watermark, "
    "no logo. Single character, one head, symmetrical friendly face."
)

# --- Per-nakshatra archetype flavour (add more as we like). ---
NAKSHATRA = {
    "Purva Bhadrapada": (
        "embodies Purva Bhadrapada: quiet fiery idealism and a mystic's intensity, a "
        "subtle lion-mane silhouette in the hair, twin softly-glowing flames floating "
        "at the shoulders symbolising a dual nature, ruled by Jupiter so accented in "
        "warm gold and silver-grey, a faint halo of transformation embers. Serene, "
        "visionary, slightly otherworldly."
    ),
    "Rohini": (
        "embodies Rohini: the Moon's beloved, gentle radiant beauty and creative warmth, "
        "adorned with blossoming lotus and ox-cart motifs, pearl-and-rose palette with "
        "soft silver moonlight, an aura of nurturing abundance. Graceful, magnetic, calm."
    ),
    "Ashwini": (
        "embodies Ashwini: swift healer energy of the twin horse-riders, a subtle winged-"
        "horse motif, restless bright eyes, dawn-gold and turquoise palette, sparks of "
        "fresh-start light. Youthful, quick, adventurous."
    ),
}

GENDER_DESC = {
    "male": "depicted as a young man",
    "female": "depicted as a young woman",
    "other": "depicted as an androgynous celestial youth",
}


def build_prompt(nak: str, gender: str) -> str:
    flavour = NAKSHATRA.get(nak, f"embodies the {nak} nakshatra, cosmic and archetypal")
    who = GENDER_DESC.get(gender.lower(), GENDER_DESC["other"])
    return f"A celestial companion {who}, who {flavour} {HOUSE_STYLE}"


def get_token() -> str:
    return subprocess.check_output(
        ["gcloud", "auth", "print-access-token"], text=True
    ).strip()


def main():
    nak = sys.argv[1] if len(sys.argv) > 1 else "Purva Bhadrapada"
    gender = sys.argv[2] if len(sys.argv) > 2 else "male"
    prompt = build_prompt(nak, gender)

    print(f"Nakshatra : {nak}")
    print(f"Gender    : {gender}")
    print(f"Prompt    : {prompt}\n")

    token = get_token()
    url = (
        f"https://{LOCATION}-aiplatform.googleapis.com/v1/projects/{PROJECT}"
        f"/locations/{LOCATION}/publishers/google/models/{MODEL}:predict"
    )
    body = {
        "instances": [{"prompt": prompt}],
        "parameters": {
            "sampleCount": SAMPLE_COUNT,
            "aspectRatio": "1:1",
            "personGeneration": "allow_adult",
            "safetySetting": "block_only_high",
        },
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json; charset=utf-8",
        },
        method="POST",
    )

    print("Calling Imagen…")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code}: {e.read().decode('utf-8')}")
        sys.exit(1)

    preds = data.get("predictions", [])
    if not preds:
        print("No predictions returned. Raw response:")
        print(json.dumps(data, indent=2)[:2000])
        sys.exit(1)

    os.makedirs(OUT_DIR, exist_ok=True)
    slug = nak.lower().replace(" ", "_")
    paths = []
    for i, p in enumerate(preds):
        b64 = p.get("bytesBase64Encoded")
        if not b64:
            continue
        out = os.path.join(OUT_DIR, f"{slug}_{gender}_{i+1}.png")
        with open(out, "wb") as f:
            f.write(base64.b64decode(b64))
        paths.append(out)
        print(f"   {out}")

    if paths:
        # open the folder on macOS so we can eyeball all of them
        try:
            subprocess.run(["open", OUT_DIR], check=False)
        except Exception:
            pass
    else:
        print("Predictions returned but no image bytes found.")


if __name__ == "__main__":
    main()
