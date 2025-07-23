#!/usr/bin/env python3
# calc_css_clamp_px.py

def clamp_expr(v1_px, v2_px, w1, w2, decimals=4):
    if w1 == w2:
        raise ValueError("w1 and w2 must differ.")
    if w2 < w1:
        w1, w2 = w2, w1
        v1_px, v2_px = v2_px, v1_px  # keep mapping correct

    dv = v2_px - v1_px                       # px change in value
    slope = dv * 100 / (w2 - w1)             # px per vw
    offset = v1_px - slope * (w1 / 100)      # px

    fmt = f"{{:.{decimals}f}}"
    return f"clamp({fmt.format(v1_px)}px, calc({fmt.format(offset)}px + {fmt.format(slope)}vw), {fmt.format(v2_px)}px)"

def ask_float(prompt, default=None):
    s = input(prompt + (f" [{default}]" if default is not None else "") + ": ").strip()
    return float(s) if s else float(default) if default is not None else float(input("Required: "))

def ask_int(prompt, default=None):
    s = input(prompt + (f" [{default}]" if default is not None else "") + ": ").strip()
    return int(s) if s else int(default) if default is not None else int(input("Required: "))

def main():
    print("Responsive clamp() generator (px only)")
    v1 = ask_float("Value at min width in px", 16)
    v2 = ask_float("Value at max width in px", 32)
    w1 = ask_int("Min viewport width in px", 375)
    w2 = ask_int("Max viewport width in px", 600)
    decimals = ask_int("Decimals", 4)

    print("\n" + clamp_expr(v1, v2, w1, w2, decimals))

if __name__ == "__main__":
    main()
