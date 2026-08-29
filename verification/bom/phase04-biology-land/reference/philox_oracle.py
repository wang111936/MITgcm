#!/usr/bin/env python3
"""Independent exact oracle for the frozen MITGCM-BOM P4.3 Philox key."""

from __future__ import annotations

MASK = (1 << 32) - 1
M0 = 3528531795
M1 = 3449720151
W0 = 2654435769
W1 = 3144134277
TWO32 = 1 << 32
TWO_PI = float("6.28318530717958647692528676655900577")


def mul_high_low_32(a: int, b: int) -> tuple[int, int]:
    if not 0 <= a <= MASK or not 0 <= b <= MASK:
        raise ValueError("unsigned word outside 32-bit range")
    a0, a1 = a & 0xFFFF, a >> 16
    b0, b1 = b & 0xFFFF, b >> 16
    p0, p1, p2, p3 = a0 * b0, a0 * b1, a1 * b0, a1 * b1
    carry = (p0 >> 16) + (p1 & 0xFFFF) + (p2 & 0xFFFF)
    low = (p0 & 0xFFFF) + ((carry & 0xFFFF) << 16)
    high = (p3 + (p1 >> 16) + (p2 >> 16) + (carry >> 16)) & MASK
    return high, low


def philox4x32(counter: tuple[int, int, int, int],
                key: tuple[int, int]) -> tuple[int, int, int, int]:
    c0, c1, c2, c3 = counter
    k0, k1 = key
    if any(not 0 <= value <= MASK for value in (*counter, *key)):
        raise ValueError("unsigned word outside 32-bit range")
    for round_index in range(10):
        hi0, lo0 = mul_high_low_32(M0, c0)
        hi1, lo1 = mul_high_low_32(M1, c2)
        c0, c1, c2, c3 = hi1 ^ c1 ^ k0, lo1, hi0 ^ c3 ^ k1, lo0
        if round_index != 9:
            k0, k1 = (k0 + W0) & MASK, (k1 + W1) & MASK
    return c0, c1, c2, c3


def birth_random(seed: int, parent_id: int, birth_count: int,
                 event_index: int, attempt: int) -> tuple[int, str]:
    if parent_id <= 0 or event_index < 0 or birth_count < 0 or attempt < 0:
        raise ValueError("invalid birth key")
    first = philox4x32(
        (parent_id & MASK, parent_id >> 32, birth_count, seed & MASK),
        (0, 0),
    )
    second = philox4x32(
        (event_index & MASK, event_index >> 32, attempt, 0),
        (first[0], first[2]),
    )
    unit_value = (second[0] + 0.5) / TWO32
    angle = TWO_PI * unit_value
    return second[0], angle.hex()


CORE_CASES = (
    ("core-zero", (0, 0, 0, 0), (0, 0)),
    ("core-max", (MASK, MASK, MASK, MASK), (MASK, MASK)),
)

BIRTH_CASES = (
    ("birth-base", 0, 1, 0, 0, 0),
    ("birth-id-low-max", 0, MASK, 0, 0, 0),
    ("birth-id-high-one", 0, TWO32, 0, 0, 0),
    ("birth-id-cross", 0, TWO32 + 1, 0, 0, 0),
    ("birth-id-signed-max", 0, (1 << 63) - 1, 0, 0, 0),
    ("birth-seed-max", -1, 1, 0, 0, 0),
    ("birth-count-large", 0, 1, (1 << 31) - 1, 0, 0),
    ("birth-event-low-max", 0, 1, 0, MASK, 0),
    ("birth-event-wrap", 0, 1, 0, TWO32, 0),
    ("birth-event-signed-max", 0, 1, 0, (1 << 63) - 1, 0),
    ("birth-retry-one", 0, 1, 0, 0, 1),
    ("birth-retry-large", 0, 1, 0, 0, (1 << 31) - 1),
    ("birth-key-mixed", 324508639, TWO32 + 17, 19, TWO32 + 23, 7),
)

EXPECTED_CORE = {
    "core-zero": (1713891541, 3781805453, 3159862348, 2600524760),
    "core-max": (1083123565, 1103641358, 2718681030, 1834242557),
}

EXPECTED_BIRTH = {
    "birth-base": (4190644000, "0x1.885b3d8ae3f5ep+2"),
    "birth-id-low-max": (2787156614, "0x1.04f3d2cc423a2p+2"),
    "birth-id-high-one": (308051156, "0x1.cd782391859c6p-2"),
    "birth-id-cross": (3694036235, "0x1.59dc5275c5492p+2"),
    "birth-id-signed-max": (1095445230, "0x1.9a407f0118f96p+0"),
    "birth-seed-max": (1423354184, "0x1.0a872fc97b430p+1"),
    "birth-count-large": (885408917, "0x1.4b97844d4822ep+0"),
    "birth-event-low-max": (3022491160, "0x1.1afc6d7caef63p+2"),
    "birth-event-wrap": (189653080, "0x1.1c1b0ba36f8fep-2"),
    "birth-event-signed-max": (2345006819, "0x1.b71c5b44c258bp+1"),
    "birth-retry-one": (3087676103, "0x1.2116cf49b5ce4p+2"),
    "birth-retry-large": (3251901499, "0x1.307709b2836f4p+2"),
    "birth-key-mixed": (3296537124, "0x1.34a4e2764ebf9p+2"),
}


def main() -> None:
    print("case\tword0\tword1\tword2\tword3\tangle_hex")
    for name, counter, key in CORE_CASES:
        output = philox4x32(counter, key)
        if output != EXPECTED_CORE[name]:
            raise AssertionError((name, output, EXPECTED_CORE[name]))
        print(name, *output, "-", sep="\t")
    for name, seed, parent, count, event, attempt in BIRTH_CASES:
        word, angle_hex = birth_random(seed, parent, count, event, attempt)
        if (word, angle_hex) != EXPECTED_BIRTH[name]:
            raise AssertionError((name, word, angle_hex, EXPECTED_BIRTH[name]))
        print(name, word, "-", "-", "-", angle_hex, sep="\t")


if __name__ == "__main__":
    main()
