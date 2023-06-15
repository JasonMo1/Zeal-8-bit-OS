; SPDX-FileCopyrightText: 2023 Zeal 8-bit Computer <contact@zeal8bit.com>
;
; SPDX-License-Identifier: Apache-2.0

        INCLUDE "errors_h.asm"
        INCLUDE "osconfig.asm"
        INCLUDE "mmu_h.asm"
        INCLUDE "utils_h.asm"
        INCLUDE "strutils_h.asm"
        INCLUDE "vfs_h.asm"
        INCLUDE "log_h.asm"
        INCLUDE "target_h.asm"

        EXTERN zos_vfs_open_internal
        EXTERN zos_vfs_read_internal
        EXTERN zos_vfs_dstat_internal
        EXTERN zos_sys_remap_bc_page_2
        EXTERN zos_sys_remap_de_page_2
        EXTERN _zos_default_init

        DEFC USER_STACK_ADDRESS = CONFIG_KERNEL_RAM_START - 1
        DEFC USER_PROG_MAX_SIZE = USER_STACK_ADDRESS - CONFIG_KERNEL_INIT_EXECUTABLE_ADDR

        SECTION KERNEL_TEXT

        ; Load the first binary in the system
        ; Parameters:
        ;   HL - Absolute path to the file
        ; Returns:
        ;   A - error code on failure, doesn't return on success
        PUBLIC zos_load_init_file
zos_load_init_file:
        jp zos_load_file


        ; Routine helper to open and check the size of a file.
        ; If this routines returns success, then a load/exec of the file is possible
        ; Parameters:
        ;   BC - File path
        ; Returns:
        ;   A - 0 on success, error code else
        ;   Z flag - Set on success
        ;   BC - Size of the file
        ;   D - Dev of the opened file
_zos_load_open_and_check_size:
        ; Set flags to read-only
        ld h, O_RDONLY
        call zos_vfs_open_internal
        ; File descriptor in A, error if the descriptor is less than 0
        or a
        jp m, zos_load_and_open_error
        ; No error, let's check the file size, it must not exceed USER_PROG_MAX_SIZE
        ld de, _file_stats
        ld h, a
        push hl
        call zos_vfs_dstat_internal
        ; Put the structure address in HL instead and store dev number in D.
        ld hl, _file_stats
        pop de
        ; Check if an error occurred while getting the info
        or a
        jr nz, _zos_load_failed_err
        ; Check the size field, if size field is not the first attribute, modify the code below
        ASSERT(file_size_t == 0)
        ; The size is in little-endian!
        ld c, (hl)
        inc hl
        ld b, (hl)
        inc hl
        ; The upper 16-bit must be 0, else the file is > 64KB
        ld a, (hl)
        inc hl
        or (hl)
        jr nz, _zos_load_failed
        ; BC contains the size of the file, make sure it isn't bigger than USER_PROG_MAX_SIZE
        ld hl, USER_PROG_MAX_SIZE
        ; Carry is not set for sure
        sbc hl, bc
        ; If carry is set, BC is bigger than USER_PROG_MAX_SIZE
        jr c, _zos_load_failed
        ; Success, set Z flag
        xor a
        ret
zos_load_and_open_error:
        neg
        ret
_zos_load_failed:
        ; File is too big
        ld a, ERR_NO_MORE_MEMORY
        ; Z flag must not be set in case of error
        or a
_zos_load_failed_err:
        push af
        ; Close the opened dev (in D register)
        ld h, d
        call zos_vfs_close
        pop af
        ret


        ; Load binary file which is pointed by HL
        ; Parameters:
        ;   HL - Absolute path to the file
        ; Returns:
        ;   A - error code on failure, doesn't return on success
        PUBLIC zos_load_file
zos_load_file:
        ; Put the file path in BC
        ld b, h
        ld c, l
zos_load_file_bc:
        call _zos_load_open_and_check_size
        ret nz
        ; Reuse stat structure to fill the program parameters
        ld hl, USER_STACK_ADDRESS
        ld (_file_stats), hl
        ld hl, 0
        ld (_file_stats + 2), hl

        ; Parameters:
        ;   D - Opened dev
        ;   BC - Size of the file
_zos_load_file_checked:
        ; BC contains the size of the file to copy, D contains the dev number.
        ; Only support program loading on 0x4000 at the moment
        ASSERT(CONFIG_KERNEL_INIT_EXECUTABLE_ADDR == 0x4000)
        ; Perform a read of a page size until we read less bytes than than MMU_VIRT_PAGES_SIZE
        push bc
        ld h, d
        ld de, CONFIG_KERNEL_INIT_EXECUTABLE_ADDR
        push hl
        call zos_vfs_read_internal
        pop hl
        ; In any case, pop the file size in DE
        pop de
        ; And close the file (regardless of `read` result)
        push af
        call zos_vfs_close
        ; Check if previous read returned an error
        pop af
        or a
        ret nz
        ; Set user stack which points to the program parameter
        ld hl, (_file_stats)
        ld sp, hl
        ; Put HL in DE (user program)
        ex de, hl
        ld bc, (_file_stats + 2)
        jp CONFIG_KERNEL_INIT_EXECUTABLE_ADDR


        ; Load and execute a program from a file name given as a parameter.
        ; The program will cover the current program.
        ; Parameters:
        ;       BC - File to load and execute
        ;       DE - String parameter, can be NULL
        ;       (TODO: H - Save the current program in RAM?)
        ; Returns:
        ;       A - Nothing on success, the new program is executed.
        ;           ERR_FAILURE on failure.
        ; Alters:
        ;       HL
        PUBLIC zos_loader_exec
zos_loader_exec:
        push bc
        push de
        call zos_loader_exec_internal
        pop de
        pop bc
        ret
zos_loader_exec_internal:
        ld a, d
        or e
        jp z, zos_load_file_bc
        push de
        ; Check if the file is reachable and the size is correct
        call _zos_load_open_and_check_size
        ; Get back DE parameter but in HL
        pop hl
        ret nz
        ; Save the size of the binary as we will need it later
        push bc
        ; Parameter was given, we have to copy it to the program stack
        ; D contains the opened dev, we should not alter it
        push de
        ; HL contains the parameter (string), get its length in BC
        call strlen
        ; Calculate the address of the NULL character
        add hl, bc
        ; Copy the parameter to the new program's stack. To avoid having a corrupted string
        ; when addresses overlap, copy from the end to the beginning.
        ld de, USER_STACK_ADDRESS
        ; Save the length of the parameter beforehand
        ld (_file_stats + 2), bc
        inc bc  ; Copy the NULL-byte too
        lddr
        ; Increment DE to make it point to the first character of the parameter
        inc de
        ld (_file_stats), de
        ; The parameters to send to the program are now saved, clean our stack and execute the program
        pop de  ; D contains the opened dev
        pop bc  ; Program size in BC
        jp _zos_load_file_checked


        ; Exit the current process and load back the init.bin file
        ; Parameters:
        ;       C - Returned code (unused yet)
        ; Returns:
        ;       None
        PUBLIC zos_loader_exit
zos_loader_exit:
        call zos_vfs_clean
    IF CONFIG_KERNEL_EXIT_HOOK
        call target_exit
    ENDIF
        ; Load the init file name
        ld hl, _zos_default_init
        jp zos_load_file

        SECTION KERNEL_BSS
        ; Buffer used to get the stats of the file to load.
_file_stats: DEFS STAT_STRUCT_SIZE