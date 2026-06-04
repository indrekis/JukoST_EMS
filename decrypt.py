#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


# ---- offsets from the disassembly ----

ANTI_DEBUG_START = 0x074D
ANTI_DEBUG_END_EXCL = 0x0772
# 074D..0771:
#   cli
#   pushf / clear TF / popf
#   temporary SS:SP = FF00:03EC
#   pushf
#   self-modify cld -> nop
#   cld / nop ambiguity
#   temporary SP = 100C
#   pushf
#   restore SS:SP
#
# We intentionally stop before:
#   0772 mov cx, cs
#   0774 mov ds, cx
# because decoded code may rely on DS=CS.

DECRYPT_LOOP_START = 0x0776
DECRYPT_LOOP_END_EXCL = 0x0783
# 0776..0782:
#   mov di, 078Fh
#   mov cx, 0222h
# loc_77C:
#   mov bx, cx
#   ror word ptr [bx+di], 1
#   dec cx
#   loop loc_77C

CPU_SELECT_START = 0x0783
CPU_SELECT_END_EXCL = 0x078F
# This block is preserved.

DI_VALUE = 0x078F
CX_INITIAL = 0x0222


def ror16_1(x: int) -> int:
    """Rotate 16-bit value right by 1."""
    x &= 0xFFFF
    return ((x >> 1) | ((x & 1) << 15)) & 0xFFFF


def read_u16le(buf: bytearray, off: int) -> int:
    return buf[off] | (buf[off + 1] << 8)


def write_u16le(buf: bytearray, off: int, value: int) -> None:
    value &= 0xFFFF
    buf[off] = value & 0xFF
    buf[off + 1] = (value >> 8) & 0xFF


def require_range(buf: bytearray, start: int, end_excl: int, label: str) -> None:
    if start < 0 or end_excl > len(buf) or start >= end_excl:
        raise ValueError(
            f"{label}: range {start:04X}h..{end_excl - 1:04X}h "
            f"is outside file size {len(buf):04X}h"
        )


def decrypt_block_like_driver(buf: bytearray) -> None:
    """
    Reproduce the original loop exactly:

        di = 078Fh
        cx = 0222h
    loc:
        bx = cx
        ror word ptr [bx+di], 1
        dec cx
        loop loc

    Important: LOOP also decrements CX, so CX changes by 2 per iteration.
    Processed CX values are:
        0222h, 0220h, 021Eh, ..., 0002h

    Therefore processed addresses are:
        078Fh + 0222h = 09B1h
        ...
        078Fh + 0002h = 0791h

    The words are unaligned, because 078Fh + even = odd.
    """
    cx = CX_INITIAL

    while True:
        bx = cx
        off = DI_VALUE + bx

        require_range(buf, off, off + 2, "encrypted word")

        old = read_u16le(buf, off)
        new = ror16_1(old)
        write_u16le(buf, off, new)

        # explicit DEC CX
        cx = (cx - 1) & 0xFFFF

        # LOOP loc_77C: decrement CX again, jump if CX != 0
        cx = (cx - 1) & 0xFFFF
        if cx == 0:
            break


def fill_nop(buf: bytearray, start: int, end_excl: int) -> None:
    require_range(buf, start, end_excl, "NOP patch")
    buf[start:end_excl] = b"\x90" * (end_excl - start)


def patch_file(input_path: Path, output_path: Path) -> None:
    buf = bytearray(input_path.read_bytes())

    # Sanity checks for all fixed patch ranges.
    require_range(buf, ANTI_DEBUG_START, ANTI_DEBUG_END_EXCL, "anti-debug block")
    require_range(buf, DECRYPT_LOOP_START, DECRYPT_LOOP_END_EXCL, "decrypt loop")
    require_range(buf, CPU_SELECT_START, CPU_SELECT_END_EXCL, "CPU selection block")

    # 1. Permanently decrypt the encrypted area in the file.
    decrypt_block_like_driver(buf)

    # 2. Remove anti-debug tricks.
    fill_nop(buf, ANTI_DEBUG_START, ANTI_DEBUG_END_EXCL)

    # 3. Remove only the decryption loop.
    #    Leave 0772: mov cx, cs / 0774: mov ds, cx intact.
    fill_nop(buf, DECRYPT_LOOP_START, DECRYPT_LOOP_END_EXCL)

    output_path.write_bytes(buf)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Decrypt the obfuscated DOS driver block and NOP out "
            "anti-debug/decryption code while preserving the 8086/80186+ branch."
        )
    )
    parser.add_argument("input", type=Path, help="input binary file")
    parser.add_argument("output", type=Path, help="patched output binary file")
    args = parser.parse_args()

    patch_file(args.input, args.output)

    print(f"patched: {args.input} -> {args.output}")
    print("decrypted loop-equivalent block:")
    print(f"  DI={DI_VALUE:04X}h, CX={CX_INITIAL:04X}h")
    print(f"  processed words at offsets {DI_VALUE + 2:04X}h..{DI_VALUE + CX_INITIAL:04X}h, step 2")
    print("NOP patches:")
    print(f"  anti-debug: {ANTI_DEBUG_START:04X}h..{ANTI_DEBUG_END_EXCL - 1:04X}h")
    print(f"  decrypt loop: {DECRYPT_LOOP_START:04X}h..{DECRYPT_LOOP_END_EXCL - 1:04X}h")
    print(f"preserved CPU selection: {CPU_SELECT_START:04X}h..{CPU_SELECT_END_EXCL - 1:04X}h")


if __name__ == "__main__":
    main()
	