# IJUKOEMM — Juko ST EMS Driver Reconstruction

`IJUKOEMM` is a reconstructed and patched DOS device driver, which emulates EMS using the Juko ST motherboard exotic banking interface. Details (in Ukrainian): ''[Материнська плата Juko ST – ще одна XT-машина](https://indrekis.github.io/retrocomputing/ibm_pc_compat/2024/08/28/juko_xt_mb.html)''). The driver emulates an EMS 3.2 by using the a 64 KiB page frame at the top of conventional memory as a EMS page frame to access the additional 384 KiB of memory. 

The original driver was written by **George Lefterov**, as indicated by the original banner string. This project is based on a decrypted binary, IDA disassembly, and a manually cleaned NASM reconstruction.

To debug the driver, I patched 86Box to emulate the Juko ST bank switching; corresponding [pull request](https://github.com/86Box/86Box/pull/7322) was just merged to upstream.

The goal of this project is to understand, preserve, and make usable the original Juko ST memory-expansion logic on real hardware and in emulators such as 86Box.

## Usage

Add the following line to your CONFIG.SYS for the 640 Kb system:

```bat
DEVICE=IJUKOEMM.SYS 
```

You can also specify a displacement in Kb below the 640 Kb boundary, where nn is value in range 0..64:

```
DEVICE=IJUKOEMM.SYS /D:nn
```

Several examples:

The default is equivalent to /D:0:

```
DEVICE=IJUKOEMM.SYS /D:0 
```

System with the 639 Kb: 

```
DEVICE=IJUKOEMM.SYS /D:1
```

Currently the expanded memory size is always expected to be 384 Kb.

## Building

```bash
nasm IJUKOEMM.asm -o IJUKOEMM.SYS -l IJUKOEMM.LST
```

Optimize: 
```bash
./nasm IJUKOEMM.asm -o IJUKOEMM.SYS -l IJUKOEMM.LST  -Ox
```

E.g., some jmps are not short because of they became too far with debug output. Multi-pass optimization would make them short anyway if possible. 

To build with full debug output:

```bash
./nasm IJUKOEMM.asm -o IJUKOEMM.SYS -l IJUKOEMM.LST -DB8000_DEBUG_TRACE=1 -DA86BOX_ISABUGGER_TRACE=1
```

Each debug log can also be enabled separately by passing only one of these defines.

NASM for Windows is included in the repo for convenience. LST file in not required though useful.

## Current status

The reconstructed driver has been successfully tested with CheckIt 2, 3, and 4, several other DOS applications and with Microsoft Word and Excel under Windows 3.0, both in 86Box and on real hardware.


Several small features were added:

- Two types of debug support -- for the [86Box ISABugger debug facility](https://86box.readthedocs.io/en/latest/hardware/isabugger.html) and by writing directly to video memory. Supported are text mode (using the B800:0000), CGA and VGA mode 13h. Graphical debug output code, including the custom font were mostly AI-generated, though tested. This is auxiliary code, absent from the production build. Current end of the debug text ring buffer is marked by a rectangle, registers printing added.

- Added dynamic support for systems with slightly less than exactly 640 Kb conventional memory available. This is important, e.g. for the XT IDE, requiring 1 Kb RAM for its needs and leaving 639 Kb for the DOS.  
To change the memory size, use configuration option ``/D:nn`` -- see details above.

- Added selection of the detection of the already reserved page frame at the upper part of the conventional memory. Use option ``/M:n``, where:
   - ``/M:0`` -- use banked memory for a flag. Unreliable -- often requires power off to work. 
   - ``/M:1`` -- user plain conventional memory for the flag. Method used by all previous versions.
   - ``/M:2`` -- does not uses flags, relies on the [0:413h] contents.
   - ``/M:3`` -- strictly experimental, for the 86Box. Does not work on real hardware. 
   - **Note**: for some reason, all methods above does not work under the modified 86Box for DOS 5.00 and DOS 6.22 -- value in the [0:413h] is reverted to its defaults, though do work for the DOS 3.31...
   - **Note**: For DOS 6.22, if using the boot menu, it will be shown twice.

Several more or less small fixes were made:

- The dispatch for EMS functions AH=4Bh and AH=4Ch was corrected -- these two handlers appear to have been swapped in the original driver.
- Added correct handling of the unsupported AH=4Fh function.
- Added checks for several corner cases while searching the page tables, possibly redundant.
- Instruction ``cld`` added before the ``rep movsw`` -- I hope it is required because AFAIK no calling convention ensures this flag state.
- Int 67h handler switches to its own stack -- using current stack of the calling software is a major bug, because sometimes stack is in the switched memory region.

**Note**: MEM.EXE requires EMS 4.0, so does not sees our EMS. 

## Technical details 

The original binary driver contains some anti-debug tricks and the part which installs the interrupt handlers is encrypted. Although these tricks look naive today, it is hard to assess how effective they were in 1991. Their purpose is also unclear -- driver does not have any copyright protection.

```text
seg000:074D init_drv:     
seg000:074D      cli
seg000:074E      pushf
seg000:074F      mov     bp, sp
seg000:0751      and     word ptr [bp+0], 0FEFFh
seg000:0756      popf                    ; Clear trap flag -- antidebug
seg000:0757      mov     bp, sp
seg000:0759      mov     di, ss
seg000:075B      mov     dx, 0FF00h
seg000:075E      mov     ss, dx
seg000:0760      mov     sp, 3ECh        ; Stack at 0xFF000+0x3EC = 0xFF3EC, close to 1Мб
seg000:0763      pushf
seg000:0764      mov     byte ptr [ds:769h], 90h ; 
                         ; Set next command to nop. But for the 88/86 it is already 
                         ; in the prefetch queue and will be executed. 
seg000:0769      cld
seg000:076A      mov     sp, 100Ch       ; 0xFF000+0x100C = 0x10000C = 0xC, 
                         ; so will overwrite 0x0B-0x0C by flags, garbling int 3, 
                         ; debugging interrupt, vector
seg000:076D      pushf
seg000:076E      mov     ss, di          ; Restore stack
seg000:0770      assume ss:nothing
seg000:0770      mov     sp, bp
seg000:0772      mov     cx, cs
seg000:0774      mov     ds, cx          
seg000:0776      assume ds:seg000
seg000:0776      mov     di, 78Fh        ; Decode driver
seg000:0779      mov     cx, 222h
seg000:077C
seg000:077C loc_77C:                                
seg000:077C       mov     bx, cx
seg000:077E       ror     word ptr [bx+di], 1 ; Cyclic bit rotation to the right
seg000:0780       dec     cx
seg000:0781       loop    loc_77C         ; This and prev. command: CX := CX - 2
seg000:0783       push    sp              ; Test for 86/88/NEC V20 vs more modern
seg000:0784       mov     bp, sp
seg000:0786       cmp     [bp+0], sp
seg000:0789       pop     ax
seg000:078A       jz      short loc_78F   ; is 86/88
seg000:078C       jmp     loc_862         ; 186+
seg000:078F ; ---------------------------------------------------------------------------
seg000:078F
seg000:078F loc_78F:  ; Here starts encoded blob      
```

The decryptor script ``decrypt.py`` was generated with ChatGPT and then checked manually. It is a single-use and included only as a reference for the reconstruction process.

Decrypted driver without anti-debug code is in repo by the name ``JUKOEMMU.SYS``.

To be honest, some intimate parts of the aliases syncing logic was not understood by me to the last byte -- out of the laziness, to be honest.

