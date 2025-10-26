#!/usr/bin/env bash
set -euo pipefail

TEX="assets/volume_rendering_onepager.tex"
PDF="assets/volume_rendering_onepager.pdf"
PNG="assets/volume_rendering_onepager_300dpi.png"

if [ ! -f "$TEX" ]; then
  echo "[!] 找不到 $TEX"; exit 1
fi

if ! command -v pdflatex >/dev/null 2>&1; then
  echo "[!] 需要 pdflatex，请先安装 TeX 发行版（含 tikz/pgf 包）"; exit 1
fi

echo "[i] 编译 LaTeX -> PDF"
pdflatex -interaction=nonstopmode -halt-on-error -output-directory assets "$TEX" >/dev/null || { echo "[!] LaTeX 编译失败"; exit 1; }

echo "[i] 转换 PDF -> 300 DPI PNG（蓝白一页图）"
if command -v convert >/dev/null 2>&1; then
  if convert -density 300 "$PDF" -units PixelsPerInch -resample 300 -colorspace sRGB -strip "$PNG" 2>/dev/null; then :; else
    echo "[i] convert 受策略限制，改用 ghostscript"
    gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r300 -sOutputFile="$PNG" "$PDF"
  fi
  echo "[✓] 输出：$PNG"
elif command -v gs >/dev/null 2>&1; then
  gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r300 -sOutputFile="$PNG" "$PDF"
  echo "[✓] 输出：$PNG"
else
  echo "[!] 需要 ImageMagick 或 Ghostscript 将 PDF 转 PNG"; exit 1
fi
