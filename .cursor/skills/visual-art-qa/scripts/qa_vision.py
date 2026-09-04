#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""visual-art-qa: 三层视觉美术审核（deepseek-vision 引擎）。
用法: python qa_vision.py --image <path> --race <race> [--monster <name>] [--brief <path>] [--extra <text>] [--model deepseek-v4-flash-vision-exp] [--out <report.txt>]
"""
import argparse, base64, json, os, re, sys, urllib.request

def load_key():
    cred = os.path.expanduser('~/.dsh/.credentials.yaml')
    if os.path.isfile(cred):
        txt = open(cred, encoding='utf-8').read()
        m = re.search(r'(?m)^DEEPSEEK_API_KEY:\s*["\']?([^"\'\r\n]+)', txt)
        if m: return m.group(1).strip()
    raise SystemExit('DEEPSEEK_API_KEY not found in ~/.dsh/.credentials.yaml')

def read_brief(path):
    if not path: return ''
    try:
        t = open(path, encoding='utf-8').read()
        return t[:3000]
    except Exception as e:
        return f'(brief read failed: {e})'

def build_prompt(race, monster, brief_text, extra):
    race_en = {'dragon':'dragon-kin','human':'human','silicon':'crystal golem silicon','fungus':'mushroom/fungal','enemy':'enemy orc/beast'}.get(race, race)
    return f"""You are a game art QA reviewer. Review this character/monster image. Answer in Chinese, concise; each layer pass/fail + brief note.

LAYER 1 - generic structure: limbs complete and count matches body type; no extra/missing/fused limbs; no extra eyes/heads; fingers normal; no awkward crop; no text/watermark; material coherent (organic/crystal/plant/mechanical not mixed).

LAYER 2 - body-type logic: classify body type (humanoid / four-legged beast / plant / crystal construct / flying / soft-body / hybrid), then check structure fits that type (wings symmetrical, tail complete, joints sane).

LAYER 3 - design verification. Subject race: {race_en} ({race}). Monster/character: {monster or '(not specified - check generic race features)'}.
Expected features:
{brief_text if brief_text else '(no brief given - use the race reference table for this race)'}
{('Extra note from requester: ' + extra) if extra else ''}
Check EACH expected feature: present or missing. List concrete misses.

EXTRA - race distinction: could this be mistaken for another race (dragon vs human vs silicon crystal vs fungal vs orc)? Must clearly read as {race_en}.

Final verdict: pass as game asset or needs rework; list concrete issues (e.g. fix eye slit, show claws, make gem glow)."""

def call_vision(key, model, img_path, prompt):
    b64 = base64.b64encode(open(img_path, 'rb').read()).decode()
    body = json.dumps({"model": model, "messages": [{"role": "user", "content": [
        {"type": "text", "text": prompt},
        {"type": "image_url", "image_url": {"url": "data:image/png;base64," + b64}}
    ]}]}).encode('utf-8')
    req = urllib.request.Request('https://api.deepseek.com/v1/chat/completions', data=body,
        headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=180) as r:
        j = json.loads(r.read().decode('utf-8'))
    return j['choices'][0]['message']['content']

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--image', required=True)
    ap.add_argument('--race', default='', help='dragon/human/silicon/fungus/enemy 或新种族名')
    ap.add_argument('--monster', default='')
    ap.add_argument('--brief', default='')
    ap.add_argument('--extra', default='')
    ap.add_argument('--model', default='deepseek-v4-flash-vision-exp')
    ap.add_argument('--out', default='')
    a = ap.parse_args()
    prompt = build_prompt(a.race, a.monster, read_brief(a.brief), a.extra)
    report = call_vision(load_key(), a.model, a.image, prompt)
    if a.out:
        open(a.out, 'w', encoding='utf-8').write(report)
        print('report saved ->', a.out)
    else:
        sys.stdout.write(report + '\n')

if __name__ == '__main__':
    main()
