.text

.global _start
_start:
disable_interrupts:
	mrs	r0, cpsr
	mov	r1, #0xc0
	orr	r0, r0, r1
	msr	cpsr_cxsf, r0

relocate_stack:
        ldr     r0, =0x70009ffc // stack_start
	mov     sp, r0

dump_memory:
	bl	output_newline

	ldr     r7, =0xfff00000 // start address
	add	r8, r7, #0x8800  // count
	mov	r5, #0

encode_hex_loop:
# hex encoding borrowed from gcc output:
	ldrb	r2, [r7], #1
	mov	r1, r2, lsr #4
	add	r1, r1, #48
	and	r2, r2, #15
	add	r2, r2, #48
	cmp	r1, #57
	addhi	r1, r1, #39
	cmp	r2, #57
	addhi	r2, r2, #39

        adr     r0, hex_msg
        strb    r1, [r0, #1]
        strb    r2, [r0, #2]
        bl      output_hex

	add	r5, r5, #1
	tst	r5, #15
	bleq	output_newline

	cmp	r7, r8
	bne	encode_hex_loop

	bl	output_banner

        bl      reboot
error:
        b       error

output_hex:
	adr	r0, hex_msg
	mov	r1, #6

	b	usb_out

output_banner:
	adr	r0, fake_banner
	mov	r1, #11

	b	usb_out

output_newline:
	adr	r0, newline_msg
	mov	r1, #1

usb_out:
        push    {lr}

# void usb_uart_write(char *data, int bytes, int timeout)
	ldr	r3, =0xfff00b7f
	blx	r3

# void usb_uart_flush(void)
	ldr	r3, =0xfff01cb1
	blx	r3

	pop	{lr}
	bx	lr

        // trigger WDT reboot
reboot:
        ldr     r0, =0xa003001c
        ldr     r1, =0x1209
        str     r1, [r0]
        bx      lr              // shouldn't get here

hex_msg: 	.asciz	"\"xx\", "
newline_msg: 	.asciz "\n"
fake_banner:	.asciz	"# >"

