#!/usr/bin/env python3
import subprocess
import sys

godot_exe = r"D:\softwares\Godot_unzipped\Godot_v4.5.1-stable_win64.exe"
project_path = r"D:\GameWorkSpace\TowerDefenseProto"
test_scene = "res://tests/S1Autoplay.tscn"

cmd = [godot_exe, "--headless", "--path", project_path, test_scene, "--quit"]
print("Running:", " ".join(cmd))
try:
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate(timeout=600)
    exit_code = p.returncode
except subprocess.TimeoutExpired:
    p.kill()
    stdout, stderr = p.communicate()
    exit_code = 124  # timeout

print("Exit code:", exit_code)
if stdout:
    print("STDOUT:", stdout.decode(errors="replace")[:3000])
if stderr:
    print("STDERR:", stderr.decode(errors="replace")[:3000])
