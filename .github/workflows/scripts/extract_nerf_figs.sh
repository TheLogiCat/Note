#!/usr/bin/env bash
set -euo pipefail

ARXIV_ID="${ARXIV_ID:-2003.08934}"
WORKDIR="${WORKDIR:-.nerf_src}"
OUTDIR="${OUTDIR:-outputs}"
PDF="${PDF:-nerf.pdf}"
NO_INTERACTIVE="${NO_INTERACTIVE:-0}"
FIG1_PAGE="${FIG1_PAGE:-1}"
FIG2_PAGE="${FIG2_PAGE:-2}"

mkdir -p "$WORKDIR" "$OUTDIR"

have() { command -v "$1" >/dev/null 2>&1; }

echo "[i] 依赖检查（curl, tar, pdftoppm/pdfimages, convert/gs）"
for bin in curl tar; do
  if ! have "$bin"; then
    echo "[!] 缺少 $bin，请先安装"; exit 1
  fi
done

# 下载 PDF（备用整页渲染）
if [ ! -f "$PDF" ]; then
  echo "[i] 下载 NeRF PDF -> $PDF"
  curl -L "https://arxiv.org/pdf/${ARXIV_ID}.pdf" -o "$PDF"
else
  echo "[i] 检测到本地 PDF: $PDF"
fi

# 下载 arXiv 源码（若已存在则跳过）
SRC_TGZ="$WORKDIR/${ARXIV_ID}.tar.gz"
if [ ! -d "$WORKDIR/src" ]; then
  echo "[i] 下载 arXiv 源码 -> $SRC_TGZ（若未开放源则回退整页渲染）"
  if curl -fL "https://arxiv.org/e-print/${ARXIV_ID}" -o "$SRC_TGZ"; then
    mkdir -p "$WORKDIR/src"
    (cd "$WORKDIR/src" && tar -xzf "../${ARXIV_ID}.tar.gz" 2>/dev/null || tar -xzf "../${ARXIV_ID}.tar.gz" --wildcards)
  else
    echo "[!] 未能获取源码（或被禁止），将使用 PDF 渲染作为回退。"
  fi
else
  echo "[i] 已存在源码目录：$WORKDIR/src"
fi

# 在源码中寻找可能的图文件
CANDIDATES_FIG1=()
CANDIDATES_FIG2=()
if [ -d "$WORKDIR/src" ]; then
  mapfile -t ALLFIGS < <(find "$WORKDIR/src" -maxdepth 4 -type f \( -iname "*.pdf" -o -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.eps" \) | sort)
  for f in "${ALLFIGS[@]:-}"; do
    base="$(basename "$f" | tr '[:upper:]' '[:lower:]')"
    case "$base" in
      *teaser*|*figure1*|*fig1*|*overview*) CANDIDATES_FIG1+=("$f");;
    esac
    case "$base" in
      *pipeline*|*render*|*ray*|*sampling*|*method*|*figure2*|*fig2*) CANDIDATES_FIG2+=("$f");;
    esac
  done
fi

choose_file() {
  local -n arr=$1
  if [ "${#arr[@]}" -ge 1 ]; then
    echo "${arr[0]}"; return 0
  fi
  echo ""
}

convert_300dpi() {
  local in="$1"; local out="$2"
  local ext="${in##*.}"; ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  if have convert; then
    if [ "$ext" = "pdf" ] || [ "$ext" = "eps" ]; then
      if convert -density 300 "$in" -units PixelsPerInch -resample 300 -colorspace sRGB -strip "$out" 2>/dev/null; then :; else
        echo "[i] convert 受策略限制，改用 ghostscript"
        gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r300 -sOutputFile="$out" "$in"
      fi
    else
      convert "$in" -units PixelsPerInch -resample 300 -colorspace sRGB -strip "$out"
    fi
  elif have gs; then
    gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=png16m -r300 -sOutputFile="$out" "$in"
  else
    echo "[!] 缺少 ImageMagick 或 Ghostscript，无法转换 $in"; return 1
  fi
  echo "[i] 导出：$out"
}

render_pdf_page() {
  local page="$1"; local out="$2"
  if have pdftoppm; then
    pdftoppm -f "$page" -l "$page" -png -r 300 "$PDF" "$OUTDIR/_page_${page}"
    mv "$OUTDIR/_page_${page}-1.png" "$out"
    echo "[i] 整页渲染：$out"
  else
    echo "[!] 缺少 pdftoppm（Poppler），无法整页渲染"; return 1
  fi
}

process_fig() {
  local candidates_array_name="$1"; local fallback_page="$2"; local outfile="$3"
  local -n arr="$candidates_array_name"
  if [ "${#arr[@]}" -ge 1 ]; then
    echo "[i] 使用源码候选 ${arr[0]}"; convert_300dpi "${arr[0]}" "$outfile" || true
  fi
  if [ ! -s "$outfile" ]; then
    echo "[i] 源码未命中或转换失败，使用 PDF 页码回退（page=${fallback_page}）"
    render_pdf_page "$fallback_page" "$outfile"
  fi
}

echo "================ 生成 FIG.1 ================"
FIG1_SRC="$(choose_file CANDIDATES_FIG1)" || true
process_fig CANDIDATES_FIG1 "$FIG1_PAGE" "${OUTDIR}/fig1_300dpi.png"

echo "================ 生成 FIG.2 ================"
FIG2_SRC="$(choose_file CANDIDATES_FIG2)" || true
process_fig CANDIDATES_FIG2 "$FIG2_PAGE" "${OUTDIR}/fig2_300dpi.png"

echo "[✓] 完成。输出目录：$OUTDIR"
ls -lh "$OUTDIR" || true
