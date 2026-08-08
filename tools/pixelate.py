#!/usr/bin/env python3
"""
베스퍼 회랑 - 일러스트 -> 인게임 픽셀 스프라이트 자동 변환기.

배경: PixelLab 직생성은 '선명+7등신' 동시 충족 불가(v3=선명하나 항상 ~4등신,
standard=등신제어 되나 뭉갬), Higgsfield AutoSprite는 서버버그로 실패. 그래서
'클린 일러 생성 -> 코드로 자동 픽셀화'가 확정 파이프라인. 손작업 0.

전제 입력: 캐릭터가 프레임을 꽉 채운 사이드뷰 전신 일러(플랫 셀셰이딩,
플레인 그레이 배경). Higgsfield nano_banana_pro로 생성 권장
(기존 캐릭터 일러를 medias role:image로 주입해 캐릭터 잠금 +
"7 heads tall, small head, long legs, side view facing right, full body,
flat cel shading, plain flat grey background" 프롬프트).

파이프라인:
  1) 배경 floodfill 제거(테두리 8점 시드, thresh) -> 알파 + 내용물로 크롭
  2) 크리스픈: UnsharpMask + 대비 + 채도
  3) LANCZOS로 목표 높이(~140px)까지 다운스케일
  4) 팔레트 한정: MEDIANCUT, dither 없음(~28색)
  5) 알파 이진화 + MaxFilter로 1px 다크 외곽선

산출 스프라이트를 res://assets/sprites/<name>/idle_0.png 등으로 넣고
battle3d.gd DECK 항목에 "tightsprite": true, "sps": 0.011 정도로 배선.
실제 인게임 크기(1~2x)에선 얼굴 뭉갬 거의 안 보임 -> 얼굴 손정리 불필요.

사용:
  python3 pixelate.py in.png out.png [--height 140] [--colors 28] \
      [--bg-thresh 34] [--no-bg] [--outline 26,20,24] [--up out_up.png]

--no-bg : 이미 배경이 투명한 PNG면 floodfill 건너뜀.
--up    : NEAREST 5x 확대 미리보기도 저장(육안 확인용).
"""
import argparse
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance


def remove_bg(im_rgb: Image.Image, thresh: int) -> Image.Image:
    """테두리 시드에서 배경색을 floodfill로 sentinel 칠하고 알파화 후 크롭."""
    W, H = im_rgb.size
    work = im_rgb.copy()
    sentinel = (255, 0, 255)
    seeds = [(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1),
             (W // 2, 0), (0, H // 2), (W - 1, H // 2), (W // 2, H - 1)]
    for p in seeds:
        try:
            ImageDraw.floodfill(work, p, sentinel, thresh=thresh)
        except Exception:
            pass
    wa = np.array(work)
    bg = np.all(wa == np.array(sentinel), axis=2)
    rgba = np.dstack([np.array(im_rgb), (~bg).astype(np.uint8) * 255])
    full = Image.fromarray(rgba)
    bbox = full.split()[3].getbbox()
    return full.crop(bbox) if bbox else full


def pixelate(rgba: Image.Image, height: int, colors: int,
             outline=(26, 20, 24)) -> Image.Image:
    """크리스픈 -> 다운스케일 -> 팔레트 한정 -> 1px 외곽선."""
    src_rgb = rgba.convert("RGB")
    src_rgb = src_rgb.filter(ImageFilter.UnsharpMask(radius=3, percent=160, threshold=2))
    src_rgb = ImageEnhance.Contrast(src_rgb).enhance(1.18)
    src_rgb = ImageEnhance.Color(src_rgb).enhance(1.18)
    src = Image.merge("RGBA", (*src_rgb.split(), rgba.split()[3]))

    scale = height / src.height
    small = src.resize((max(1, int(src.width * scale)), height), Image.LANCZOS)

    alpha = small.split()[3].point(lambda v: 255 if v >= 115 else 0)
    sm_rgb = small.convert("RGB").filter(
        ImageFilter.UnsharpMask(radius=1, percent=80, threshold=1))
    q = sm_rgb.quantize(colors=colors, method=Image.MEDIANCUT,
                        dither=Image.NONE).convert("RGB")
    spr = Image.merge("RGBA", (*q.split(), alpha))

    A = np.array(alpha)
    dil = np.array(alpha.filter(ImageFilter.MaxFilter(3)))
    ring = (dil > 0) & (A == 0)
    arr = np.array(spr)
    arr[ring] = [outline[0], outline[1], outline[2], 255]
    return Image.fromarray(arr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--height", type=int, default=140)
    ap.add_argument("--colors", type=int, default=28)
    ap.add_argument("--bg-thresh", type=int, default=34)
    ap.add_argument("--no-bg", action="store_true", help="배경이 이미 투명하면 지정")
    ap.add_argument("--outline", default="26,20,24", help="R,G,B 외곽선 색")
    ap.add_argument("--up", default=None, help="NEAREST 5x 확대 미리보기 저장 경로")
    a = ap.parse_args()

    im = Image.open(a.inp)
    if a.no_bg:
        full = im.convert("RGBA")
        bbox = full.split()[3].getbbox()
        if bbox:
            full = full.crop(bbox)
    else:
        full = remove_bg(im.convert("RGB"), a.bg_thresh)

    outline = tuple(int(x) for x in a.outline.split(","))
    px = pixelate(full, a.height, a.colors, outline)
    px.save(a.out)
    print(f"saved {a.out} ({px.width}x{px.height}, {a.colors}col)")
    if a.up:
        px.resize((px.width * 5, px.height * 5), Image.NEAREST).save(a.up)
        print(f"saved {a.up} (5x preview)")


if __name__ == "__main__":
    main()
