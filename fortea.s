.text
.global _main
.align 4

do_input:
    stp fp, lr, [sp, #-16]!
    bl _getchar 
    str x0, [x20], #8
    ldp fp, lr, [sp], #16
    ret

do_pop_print:
    ldr x1, [x20, #-8]!
    stp fp, lr, [sp, #-16]!
    str x1, [sp, #-16]!

    bl _printf 

    add sp, sp, #16
    ldp fp, lr, [sp], #16
    ret

_main:
    stp fp, lr, [sp, #-16]!
    sub sp, sp, #2048 
    sub sp, sp, #2048 ; current limit

    sub w0, w0, #1 ; check if we have more argv than filename
    cbnz w0, arg_ok
    adrp x0, arg_err@PAGE
    add x0, x0, arg_err@PAGEOFF
    bl _puts
    b exit
arg_ok:
    ldr x19, [x1, #8]
    mov x20, sp ; using x20 instead of sp for stack (512 values)
    add x21, x20, #2048 ; reserve max 1792 or 224 values for definitions (16 bytes each)
    mov x22, #0 ; definition count
    mov x23, #10 ; constant 10 for madd
    mov x24, #0 ; flags
    add x25, x21, #1792; reserve 256 or 32 values for local vars (8 bytes each)
    ; x26 reserved for tmp x19 storage

pick:
    ldrb w0, [x19], #1
    cbz w0, exit
    cmp w0, #0x28
    b.eq comm
    cmp w0, #0x3a
    b.eq def_skip_space
    cmp w0, #0x3b
    b.eq end_exec
    cmp w0, #0x09
    b.eq pick
    cmp w0, #0x0a
    b.eq pick
    cmp w0, #0x20
    b.eq pick
    cmp w0, #0x39
    b.gt wrd
    cmp w0, #0x30
    b.lt wrd
    b num
def_skip_space:
    ldrb w0, [x19], #1
    cmp w0, #0x09
    b.eq def_skip_space
    cmp w0, #0x0a
    b.eq def_skip_space
    cmp w0, #0x20
    b.eq def_skip_space
def:
    ; x1 = string ref, x2 = id_len, x3 = total_len
    mov x24, #1
    bl wrd
    mov x3, x2
def_loop:
    ldrb w0, [x19], #1
    add x3, x3, #1
    cbz w0, exit
    cmp w0, #0x3b
    b.eq def_end
    b def_loop
def_end:
    bfi x2, x3, #16, #48
    add x3, x21, x22, LSL#4
    stp x1, x2, [x3]
    add x22, x22, #1
    b pick
wrd:
    ; x1 = string ref, x2 = len
    mov x1, x19
    mov w2, #1
    sub x1, x1, #1
wrd_loop:
    ldrb w0, [x19], #1
    cbz w0, wrd_fin
    cmp w0, #0x09
    b.eq wrd_fin
    cmp w0, #0x0a
    b.eq wrd_fin
    cmp w0, #0x20
    b.eq wrd_fin
    cmp w0, #0x28
    b.eq wrd_fin
    add w2, w2, #1
    b wrd_loop
wrd_fin:
    tbz x24, #0, wrd_find
    mov x24, #0
    ret
wrd_find:
    ; x0 = defs num
    sub x19, x19, #1
    mov x0, #0
wrd_find_loop:
    cmp x0, x22
    b.ge wrd_find_fin_fail
    add x4, x21, x0, LSL#4
    ldp x5, x6, [x4]
    bfi x7, x6, #0, #16
    cmp w2, w7
    b.eq wrd_find_cmp
    add x0, x0, #1
    b wrd_find_loop
wrd_find_cmp:
    mov w8, #0
wrd_find_cmp_loop:
    ldrb w10, [x1, x8]
    ldrb w11, [x5, x8]
    add w8, w8, #1
    cmp x10, x11
    b.ne wrd_find_cmp_ret
    cmp w8, w2
    b.eq wrd_find_fin
    b wrd_find_cmp_loop
wrd_find_cmp_ret:
    add x0, x0, #1
    b wrd_find_loop
wrd_find_fin:
    mov x24, #2
    add x5, x5, x7
    mov x26, x19
    mov x19, x5
    b pick 
wrd_find_fin_fail:
    ldrb w0, [x1]
    cmp w2, #1
    b.eq wrd_find.1
    cmp w2, #2
    b.eq wrd_find.2
    cmp w2, #3
    b.eq wrd_find.3
    cmp w2, #4
    b.eq wrd_find.4
    b pick ; ERR neither undefined nor builtin word
wrd_find.1:
    cmp w0, #0x21
    b.eq put
    cmp w0, #0x23
    b.eq res
    cmp w0, #0x24
    b.eq del
    cmp w0, #0x25
    b.eq loc
    cmp w0, #0x2a
    b.eq mul
    cmp w0, #0x2b
    b.eq add
    cmp w0, #0x2c
    b.eq input
    cmp w0, #0x2d
    b.eq sub
    cmp w0, #0x2e
    b.eq print
    cmp w0, #0x2f
    b.eq div
    cmp w0, #0x40
    b.eq get
    b pick
wrd_find.2:
    cmp w0, #0x69
    b.eq if
    cmp w0, #0x2e
    b.eq printx
    b pick
wrd_find.3:
    cmp w0, #0x64
    b.eq dup
    b pick
wrd_find.4:
    cmp w0, #0x73
    b.eq swap
    b pick
comm:
    ldrb w0, [x19], #1
    cbz w0, exit
    cmp w0, #0x29
    b.eq pick
    b comm
num:
    sub x0, x0, #0x30
    mov x1, x0
num_loop:
    ldrb w0, [x19], #1
    cmp w0, #0x30
    b.lt num_fin
    cmp w0, #0x39
    b.gt num_fin
    sub x0, x0, #0x30
    madd x1, x1, x23, x0
    b num_loop
num_fin:
    sub x19, x19, #1
    str x1, [x20], #8
    b pick
if:
    ldrb w0, [x1, #1]
    cmp w0, #0x66
    b.ne pick
    ldp x0, x1, [x20, #-16]!
    ldr x2, [x20, #-8]!
    cmp x2, #0
    csel x0, x0, x1, gt
    str x0, [x20], #8
    b pick
dup:
    ldrb w0, [x1, #1]!
    cmp w0, #0x75
    b.ne pick
    ldrb w0, [x1, #1]
    cmp w0, #0x70
    b.ne pick
    ldr x0, [x20, #-8]
    str x0, [x20], #8
    b pick
swap:
    ldrb w0, [x1, #1]!
    cmp w0, #0x77
    b.ne pick
    ldrb w0, [x1, #1]!
    cmp w0, #0x61
    b.ne pick
    ldrb w0, [x1, #1]
    cmp w0, #0x70
    b.ne pick
    ldp x0, x1, [x20, #-16]
    stp x1, x0, [x20, #-16]
    b pick
loc:
    ldr x0, [x20, #-8]
    add x0, x25, x0, LSL#3
    str x0, [x20, #-8]
    b pick
put:
    ldp x0, x1, [x20, #-16]!
    str x0, [x1]
    b pick
add:
    ldp x0, x1, [x20, #-16]!
    add x0, x0, x1
    str x0, [x20], #8
    b pick
sub:
    ldp x0, x1, [x20, #-16]!
    sub x0, x0, x1
    str x0, [x20], #8
    b pick
mul:
    ldp x0, x1, [x20, #-16]!
    mul x0, x0, x1
    str x0, [x20], #8
    b pick
div:
    ldp x0, x1, [x20, #-16]!
    sdiv x0, x0, x1
    str x0, [x20], #8
    b pick
get:
    ldr x0, [x20, #-8]
    ldr x0, [x0]
    str x0, [x20, #-8]
    b pick
res:
    ldr x0, [x20, #-8]
    bl _malloc
    str x0, [x20, #-8]
    b pick
del:
    ldr x0, [x20, #-8]!
    bl _free
    b pick
input:
    bl do_input
    b pick
print:
    adrp x0, pnum@PAGE
    add x0, x0, pnum@PAGEOFF
    bl do_pop_print
    b pick
printx:
    ldrb w0, [x1, #1]
    cmp w0, #0x78
    b.ne pick
    adrp x0, pxnum@PAGE
    add x0, x0, pxnum@PAGEOFF
    bl do_pop_print
    b pick
end_exec:
    mov x19, x26
    b pick

exit:
    mov w0, #0
    add sp, sp, #2048
    add sp, sp, #2048
    ldp fp, lr, [sp], #16
    ret

.data
pnum: .asciz "%lld\n"
pxnum: .asciz "%p\n"
arg_err: .asciz "Expected at least one argument"
