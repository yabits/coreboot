/*
 * This file is part of the libpayload project.
 *
 * Copyright (C) 2008 Advanced Micro Devices, Inc.
 * Copyright (C) 2017 Patrick Rudolph <siro@das-labor.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

	.code32
	.global _entry
	.extern start_main
	.text
	.align 4

/*
 * Our entry point - assume that the CPU is in 32 bit protected mode and
 * all segments are in a flat model. That's our operating mode, so we won't
 * change anything.
 */
_entry:
	jmp _init

	.align 4

#define MB_MAGIC 0x1BADB002
#define MB_FLAGS 0x00010003

mb_header:
	.long MB_MAGIC
	.long MB_FLAGS
	.long -(MB_MAGIC + MB_FLAGS)
	.long mb_header
	.long _start
	.long _edata
	.long _end
	.long _init

#define CB_MAGIC_VALUE	0x12345678
#define CB_MAGIC	0x04
#define CB_ARGV		0x08
#define CB_ARGC		0x10

/*
 * This function saves off the previous stack and switches us to our
 * own execution environment.
 */
_init:
	/* No interrupts, please. */
	cli

	movl $_stack, %esp

	call check_cpuid
	call check_long_mode

	call set_up_page_tables
	call enable_paging

	lgdtl (gdt64_pointer)

	ljmpl $8, $long_mode_start

	movl $0x2f4b2f4f, 0xb8000
	hlt


check_cpuid:
	pushf
	pop %eax

	movl %eax, %ecx

	xor $1<<21, %eax

	push %eax
	popf

	pushf
	pop %eax

	push %eax
	popf

	cmp %ecx, %eax
	je _leave
	ret

check_long_mode:
	/* Detect 64-bit CPU */
	mov $0x80000000, %eax
	cpuid
	cmp $0x80000001, %eax
	jb _leave

	mov $0x80000001, %eax
	cpuid
	test $0x20000000, %edx
	je _leave
	ret

set_up_page_tables:
	mov $pdt, %edi
	mov $0b10000011, %eax

	mov $0, %ecx
map_pdt:
	mov %eax, (%edi)
	add $0x200000, %eax
	add $0x8, %edi

	inc %ecx
	cmp $0x200, %ecx
	jne map_pdt

	ret

enable_paging:
	mov $pml4, %eax
	mov %eax, %cr3

	mov %cr4, %eax
	or $0x20, %eax
	mov %eax, %cr4

	mov $0xc0000080, %ecx
	rdmsr
	or $0x100, %eax
	wrmsr

	mov %cr0, %eax
	or $0x80000000, %eax
	mov %eax, %cr0

	ret

_leave:
	/* Restore old stack. */
	popl %esp

	/* Return to the original context. */
	ret

	.code64
long_mode_start:
	mov $0, %ax
	mov %ax, %ss
	mov %ax, %ds
	mov %ax, %es
	mov %ax, %fs
	mov %ax, %gs

	//.extern start_main
	//call start_main
	mov $start_main, %rax
	jmp *%rax

	movq $0x2f592f412f4b2f4f, %rax
	movq %rax, 0xb8000
	hlt

	.data
	.align 0x1000
pml4:
	.quad pdpt + 0x0003
	.align 0x1000
pdpt:
	.quad pdt + 0x0003
	.quad pdt + 0x1003
	.quad pdt + 0x2003
	.quad pdt + 0x3003
	.align 0x1000
pdt:
	.space 0x4000, 0

gdt64:
    .quad 0
gdt64_code:
    .quad (1<<43) | (1<<44) | (1<<47) | (1<<53)
gdt64_pointer:
    .word gdt64_pointer - gdt64 - 1
    .quad gdt64
gdt64_end:

