.text
#.set BUFFER_SIZE,4096
.set BUFFER_SIZE,10

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

echo:
@ prompt
        adr     r0, prompt
        bl      uart_puts

@ read
        adr     r0, buffer
        ldr     r1, =BUFFER_SIZE
        mov     r2, #0          // no timeout
        bl      readline 

@ print
        adr     r0, buffer
        bl      uart_puts

@ loop
@        b      echo

@ reboot instead
        ldr     r0, =0xa003001c
        ldr     r1, =0x1209
        str     r1, [r0]
        bx      lr      // shouldn't get here

        .ltorg   /* literal pool within 4k of relocate_stack above?! */
        .align	4
prompt: 
        .asciz	"\r\necho> "

        .align 4
buffer:
        .space BUFFER_SIZE



        .align 12
readline:
#       void * uart_readline(void *buffer, int max_bytes, int timeout)
# same as uart_read but will return only up until the first newline character to 
# simulate unistd read as in jonesforth.
# puts a zero at the end of the buffer to make it a "string"
# returns the end of the string read (void *buffer) in r0
        push    {lr}
        add     r4, r0, r1
        ldr     r5, =BUFEND
        str     r4, [r5] /* BUFEND = buffer + max_bytes */
        
@ read 1 char
readline_loop:
        mov     r1, #1      /* read 1 byte at a time */
        ldr     r3, =0xfff03639
        blx     r3

@ compare byte read to newline char, if so, then add 0 at index+1 and return
@ else increment index and if less than max_bytes loop to read another byte
	ldrb	r3, [r0]	/* load the byte to compare */
	cmp	r3, #10 /* newline? */
	beq	readline_exit
 
	add	r0, r0, #1
        ldr     r4, =BUFEND
        ldr     r5, [r4]
	cmp	r0, r5
	blt	readline_loop
	
readline_exit:
        mov     r4, #0
	strb	r4, [r0]	/* terminate string */
        pop     {pc}

        .ltorg   /* literal pool for above code */

        .int    BUFEND      /* index of where we are reading */
        

uart_read:
#	void usb_uart_read(void *buffer, int bytes, int timeout)
	ldr	r3, =0xfff03639
	blx	r3

	pop	{pc}

        .ltorg

uart_puts:
	push	{lr}
	mov	r3, r0
	mov	r1, #0

uart_puts_count_chars_loop:
	ldrb	r2, [r3], #1
	cmp	r2, #0
	beq	uart_puts_print
	add	r1, r1, #1
	b	uart_puts_count_chars_loop
uart_puts_print:
	mvn	r2, #0

# Call:
# void usb_uart_write(char *data, int bytes, int timeout)
	ldr	r3, =0xfff03653
	blx	r3

# Call:
# void usb_uart_flush(void)
	ldr	r3, =0xfff04845
	blx	r3

uart_puts_exit:
	pop	{pc}

        .ltorg

