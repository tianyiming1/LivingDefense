"""下载模型权重（断点续传）。默认写入 D:\\AI_models\\（统一模型目录）。"""
import argparse
from huggingface_hub import snapshot_download

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', default='SimianLuo/LCM_Dreamshaper_v7')
    ap.add_argument('--local', default=r'D:\AI_models\lcm_dreamshaper_v7')
    args = ap.parse_args()
    print('downloading', args.repo, '->', args.local)
    p = snapshot_download(repo_id=args.repo, local_dir=args.local)
    print('OK:', p)

if __name__ == '__main__':
    main()
