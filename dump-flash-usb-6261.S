.text

.global _start
_start:
disable_interrupts:
	mrs		r0, cpsr
	mov		r1, #0xc0
	orr		r0, r0, r1
	msr		cpsr_cxsf, r0

relocate_stack:
	ldr		r0, =0x70009ffc		// stack_start
	mov		sp, r0

dump_memory:
	ldr     r7, =0x00000000		// start address of Internal Memory
	add	r8, r7, #0x400000		// size of Internal Memory

encode_hex_loop:
	ldrb	r2, [r7], #1
	mov		r1, r2, lsr #4
	add		r1, r1, #48
	and		r2, r2, #15
	add		r2, r2, #48
	cmp		r1, #57
	addhi	r1, r1, #7
	cmp		r2, #57
	addhi	r2, r2, #7

	adr		r0, hex_msg
	strb	r1, [r0, #0]
	strb	r2, [r0, #1]
	bl		output_hex

	cmp		r7, r8
	bne		encode_hex_loop

	bl		output_banner

	bl		reboot

error:
	b		error

output_hex:
	adr		r0, hex_msg
	mov		r1, #2

	b		usb_out

output_banner:
	adr		r0, fake_banner
	mov		r1, #11

usb_out:
	push	{lr}

	// void usb_uart_write(char *data, int bytes, int timeout)
	ldr		r3, =0xfff00b7f
	blx		r3

	// void usb_uart_flush(void)
	ldr		r3, =0xfff01cb1
	blx		r3

	pop		{pc}

	// trigger WDT reboot
reboot:
	ldr		r0, =0xa003001c
	ldr		r1, =0x1209
	str		r1, [r0]
	bx		lr				// shouldn't get here

hex_msg:		.asciz	"xx"
fake_banner:	.asciz  "# >"
