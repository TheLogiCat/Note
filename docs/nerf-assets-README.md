# NeRF 图表提取与体渲染一页图（Actions 版）

## 使用步骤（GitHub Actions）
1. 打开 Actions 页面：选择 “Generate NeRF Assets”。
2. 点击 “Run workflow”，参数保持默认即可：
   - arxiv_id: 2003.08934
   - fig1_page: 1
   - fig2_page: 2
   - commit_outputs: true
3. 运行完成后，在 Artifacts 下载 `nerf-assets` 压缩包；或在仓库的 `outputs/` 与 `assets/` 目录查看 PNG。

## 本地运行（可选）
- Ubuntu:
  ```bash
  sudo apt-get update && sudo apt-get install -y poppler-utils imagemagick ghostscript texlive-latex-extra texlive-fonts-recommended
  bash scripts/extract_nerf_figs.sh
  bash scripts/build_onepager.sh
  ```

注意：若 ImageMagick 禁用 PDF 读取，脚本会自动回退到 Ghostscript 或使用 `pdftoppm` 整页渲染。
