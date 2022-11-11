import math
from PIL import Image


def wave_intensity_to_xyz_color(intensity, L, wave):
    X = 0
    Y = 0
    Z = 0
    for w, i in zip(range(400, 801), intensity):
        X += i * L[wave[w]][0]
        Y += i * L[wave[w]][1]
        Z += i * L[wave[w]][2]
    return (X, Y, Z)


def xyz_to_rgb(xyz):
    X, Y, Z = xyz
    S = sum(xyz)

    if S == 0:
        return (0, 0, 0)

    x0 = X / S
    y0 = Y / S
    z0 = Z / S

    r = 3.2410 * x0 - 1.5374 * y0 - 0.4986 * z0
    g = -0.9692 * x0 + 1.8760 * y0 + 0.0416 * z0
    b = 0.0556 * x0 - 0.2040 * y0 + 1.0570 * z0

    def fix(t):
        if t <= 0.00304:
            return 12.92 * t
        else:
            return 1.055 * pow(t, 1.0 / 2.4) - 0.055

    r0 = fix(min(1, max(0, r * S / 220)))
    g0 = fix(min(1, max(0, g * S / 220)))
    b0 = fix(min(1, max(0, b * S / 220)))

    return (r0, g0, b0)


def create_image():
    L = []
    wave = {}
    with open("./lin2012xyz10e_1_7sf.csv") as f:
        for line in f.readlines():
            w, x, y, z = line.strip().split(",")
            w = int(w)
            x = float(x)
            y = float(y)
            z = float(z)
            wave[w] = len(L)
            L.append((x, y, z))
    I = [1.0 for _ in L]
    Y = 0
    for i, (_, y, _) in zip(I, L):
        Y += i * y
    k = 100 / Y

    x = [w for w in range(400, 801)]
    initial_intensity = [I[wave[w]] * k for w in x]

    size = 1024
    im = Image.new("RGB", (size, size))

    max_dn = 0.1
    standard_thin = 30 * 1000  # nm
    for i in range(size):
        for j in range(size):
            dn = i * max_dn / size
            R = standard_thin * dn
            s_theta2 = j / size  # sin^2(2 * theta)

            intensity = [i0 * s_theta2 * (math.sin(math.pi * R / w) ** 2) for i0, w in zip(initial_intensity, x)]
            xyz = wave_intensity_to_xyz_color(intensity, L, wave)
            rgb = xyz_to_rgb(xyz)
            c = (int(255 * rgb[0]), int(255 * rgb[1]), int(255 * rgb[2]))
            im.putpixel((i, j), c)

    im.save("refraction_color_map.png")


if __name__ == "__main__":
    create_image()
