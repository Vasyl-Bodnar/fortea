.text
.global _main
.align 4

prep_str:
    mov x8, x0
prep_str_loop:
    ldrb w9, [x8], #1
    cmp w9, w28
    b.ne prep_str_loop
    mov w9, #0
    strb w9, [x8, #-1]
    ret

fix_str:
    mov x8, x0
fix_str_loop:
    ldrb w9, [x8], #1
    cbz w9, fix_str_fin
    b fix_str_loop
fix_str_fin:
    mov w9, w28
    strb w9, [x8, #-1]
    ret

do_input_byte:
    stp fp, lr, [sp, #-16]!
    bl _getchar 
    str x0, [x20], #8
    ldp fp, lr, [sp], #16
    ret

do_input_quad:
    stp fp, lr, [sp, #-16]!
    mov x0, #0
    mov x1, x20
    mov x2, #8
    bl _read 
    add x20, x20, #8
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
    mov x0, #0
    b err
arg_ok:
    ldr x19, [x1, #8]
    mov x20, sp ; using x20 instead of sp for stack (512 values)
    add x21, x20, #2048 ; reserve max 1792 or 224 values for definitions (16 bytes each)
    mov x22, #0 ; definition count
    mov x23, #10 ; constant 10 for madd
    mov x24, #0 ; flags
    add x25, x21, #1792; reserve 256 or 32 values for local vars (8 bytes each)
    ; x26 reserved for tmp x19 storage
    ; x27 reserved for values surviving function calls
    mov w28, #0x22 ; " or 0x27 = ', for lldb

pick:
    ldrb w0, [x19], #1
    cbz w0, end
    cmp w0, w28
    b.eq str
    cmp w0, #0x28 ; (
    b.eq comm
    cmp w0, #0x3a ; :
    b.eq def_skip_space
    cmp w0, #0x3b ; ;
    b.eq end_exec
    cmp w0, #0x09 ; tab
    b.eq pick
    cmp w0, #0x0a ; nl
    b.eq pick
    cmp w0, #0x20 ; space
    b.eq pick
    cmp w0, #0x39 ; 9
    b.gt wrd
    cmp w0, #0x30 ; 0
    b.lt wrd
    b num
str:
    mov x1, x19
str_loop:
    ldrb w0, [x19], #1
    cbz w0, str_err
    cmp w0, w28 
    b.ne str_loop
    str x1, [x20], #8
    b pick
str_err:
    mov w0, #1
    b err
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
    cbz w0, def_err
    cmp w0, #0x3b
    b.eq def_end
    b def_loop
def_end:
    bfi x2, x3, #16, #48
    add x3, x21, x22, LSL#4
    stp x1, x2, [x3]
    add x22, x22, #1
    b pick
def_err:
    mov w0, #2
    b err
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
    cmp w2, #1
    b.eq wrd_find.1
    cmp w2, #2
    b.eq wrd_find.2
    cmp w2, #3
    b.eq wrd_find.3
    cmp w2, #4
    b.eq wrd_find.4
    b wrd_find_err
wrd_find.1:
    ldrb w0, [x1]
    cmp w0, #0x21 ; !
    b.eq put
    cmp w0, #0x23 ; #
    b.eq res
    cmp w0, #0x24 ; $
    b.eq del
    cmp w0, #0x25 ; %
    b.eq loc
    cmp w0, #0x2a ; *
    b.eq mul
    cmp w0, #0x2b ; +
    b.eq add
    cmp w0, #0x2c ; ,
    b.eq input
    cmp w0, #0x2d ; -
    b.eq sub
    cmp w0, #0x2e ; .
    b.eq print
    cmp w0, #0x2f ; /
    b.eq div
    cmp w0, #0x40 ; @
    b.eq get
    b wrd_find_err
wrd_find.2:
    ldrh w0, [x1]
    mov w2, #0x2162
    cmp w0, w2 ; b!
    b.eq put_b
    mov w2, #0x4062
    cmp w0, w2 ; b@
    b.eq get_b
    mov w2, #0x662c
    cmp w0, w2 ; ,f
    b.eq readf
    mov w2, #0x662e
    cmp w0, w2 ; .f
    b.eq writef
    mov w2, #0x6669
    cmp w0, w2 ; if
    b.eq if
    mov w2, #0x2e73
    cmp w0, w2 ; s.
    b.eq print_s
    mov w2, #0x2e78
    cmp w0, w2 ; x.
    b.eq print_x
    mov w2, #0x6623
    cmp w0, w2 ; #f
    b.eq open
    mov w2, #0x6624
    cmp w0, w2 ; $f
    b.eq close
    b wrd_find_err
wrd_find.3:
    ldrh w0, [x1]
    mov w2, #0x2c64
    cmp w0, w2 ; s,
    b.eq readf_s
    mov w2, #0x2e64
    cmp w0, w2 ; s.
    b.eq writef_s
    mov w2, #0x7564
    cmp w0, w2 ; du
    b.eq dup
    b wrd_find_err
wrd_find.4:
    ldrsw x0, [x1]
    mov w2, #0x7773
    movk w2, #0x7061, LSL#16
    cmp x0, x2 ; swap
    b.eq swap
    b wrd_find_err
wrd_find_err:
    mov w0, #3
    b err
comm:
    ldrb w0, [x19], #1
    cbz w0, comm_err
    cmp w0, #0x29 ; )
    b.eq pick
    b comm
comm_err:
    mov w0, #4
    b err
num:
    sub x0, x0, #0x30 ; 0
    mov x1, x0
num_loop:
    ldrb w0, [x19], #1
    cmp w0, #0x39 ; 9
    b.gt num_fin
    cmp w0, #0x30 ; 0
    b.lt num_fin
    sub x0, x0, #0x30 ; 0
    madd x1, x1, x23, x0
    b num_loop
num_fin:
    sub x19, x19, #1
    str x1, [x20], #8
    b pick
if:
    ldp x0, x1, [x20, #-16]!
    ldr x2, [x20, #-8]!
    cmp x2, #0
    csel x0, x0, x1, gt
    str x0, [x20], #8
    b pick
dup:
    ldrb w0, [x1, #2]
    cmp w0, #0x70 ; p
    b.ne pick
    ldr x0, [x20, #-8]
    str x0, [x20], #8
    b pick
swap:
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
put_b:
    ldp x0, x1, [x20, #-16]!
    strb w0, [x1]
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
get_b:
    ldr x0, [x20, #-8]
    ldrb w0, [x0]
    str x0, [x20, #-8]
    b pick
input:
    bl do_input_quad
    b pick
input_b:
    bl do_input_byte
    b pick
print:
    adrp x0, pnum@PAGE
    add x0, x0, pnum@PAGEOFF
    bl do_pop_print
    b pick
print_s:
    ldr x0, [x20, #-8]
    mov x27, x0
    bl prep_str
    adrp x0, pstr@PAGE
    add x0, x0, pstr@PAGEOFF
    bl do_pop_print
    mov x0, x27
    bl fix_str
    b pick
print_x:
    adrp x0, pxnum@PAGE
    add x0, x0, pxnum@PAGEOFF
    bl do_pop_print
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
open:
    ldp x1, x0, [x20, #-16]!
    ldr x2, [x20, #-8]
    mov x27, x0
    bl prep_str
    bl _open
    str x0, [x20, #-8]
    mov x0, x27
    bl fix_str
    b pick
close:
    ldr x0, [x20, #-8]!
    bl _close
    b pick
writef:
    ldp x1, x0, [x20, #-16]!
    ldr x2, [x20, #-8]!
    bl _write 
    ; returns bytes written
    b pick
writef_s:
    ldrb w0, [x1, #2]
    cmp w0, #0x66 ; f
    b.ne pick
    ldp x1, x3, [x20, #-16]!
    mov x0, x1
    bl prep_str
    mov x0, x3
    sub x2, x8, x1
    bl _write 
    ; returns bytes written
    mov x0, x1
    bl fix_str
    b pick
readf:
    ldp x1, x0, [x20, #-16]!
    ldr x2, [x20, #-8]!
    bl _read 
    ; returns bytes read
    b pick
readf_s:
    ldrb w0, [x1, #2]
    cmp w0, #0x66 ; f
    b.ne pick
    ldp x1, x0, [x20, #-16]!
    mov x3, x0
    mov x0, x1
    bl prep_str
    mov x0, x3
    sub x2, x8, x1
    bl _read 
    ; returns bytes read
    mov x0, x1
    bl fix_str
    b pick
end_exec:
    mov x19, x26
    b pick

end:
    mov w0, #0
    b exit
err:
    adrp x1, err_str@PAGE
    add x1, x1, err_str@PAGEOFF
    ldr x0, [x1, x0, LSL#3]
    bl _puts
    mov w0, #1
exit:
    add sp, sp, #2048
    add sp, sp, #2048
    ldp fp, lr, [sp], #16
    ret

.section STR,"S"
.align 4
pnum: .asciz "%lld\n"
pxnum: .asciz "%p\n"
pstr: .asciz "%s\n"
err_str.0: .asciz "Expected at least one argument"
err_str.1: .asciz "String was not ended"
err_str.2: .asciz "Definition was not ended"
err_str.3: .asciz "No such word was not found"
err_str.4: .asciz "Comment was not ended"

.section REF,""
.align 4
err_str: 
    .quad err_str.0
    .quad err_str.1
    .quad err_str.2
    .quad err_str.3
    .quad err_str.4
