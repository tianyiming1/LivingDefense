#!/usr/bin/env python3
import subprocess
godot_exe = r"D:\softwares\Godot_v4.5.1-stable_win64.exe"
project_path = r"D:\GameWorkSpace\TowerDefenseProto"
test_scene = "res://tests/S1Autoplay.tscn"
cmd = [godot_exe, "--headless", "--path", project_path, test_scene]
print("Running:", " ".join(cmd))
try:
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate(timeout=120)
    print("Exit code:", p.returncode)
    if stdout: print("STDOUT:", stdout.decode(errors="replace")[:2000])
    if stderr: print("STDERR:", stderr.decode(errors="replace")[:2000])
except Exception as e:
    print("Exception:", e)
