module isr

import idt
import event
import apic
import cpu.local as cpulocal
import syscall

__global (
	int_events [256]event.Event
)

fn generic_isr(num u32, _ voidptr) {
	apic.lapic_eoi()
	int_events[num].trigger()
}

const exception_names = [
    c'Division by 0',
    c'Debug',
    c'NMI',
    c'Breakpoint',
    c'Overflow',
    c'Bound range exceeded',
    c'Invalid opcode',
    c'Device not available',
    c'Double fault',
    c'???',
    c'Invalid TSS',
    c'Segment not present',
    c'Stack-segment fault',
    c'General protection fault',
    c'Page fault',
    c'???',
    c'x87 exception',
    c'Alignment check',
    c'Machine check',
    c'SIMD exception',
    c'Virtualisation',
    c'???',
    c'???',
    c'???',
    c'???',
    c'???',
    c'???',
    c'???',
    c'???',
    c'???',
    c'Security'
]

fn ud_handler(num u32, _gpr_state &cpulocal.GPRState) {
	mut gpr_state := unsafe { _gpr_state }
	insn := &u16(gpr_state.rip)
	if unsafe { insn[0] } == 0x340f {
		// This is sysenter
		gpr_state.rip += 2
		syscall.ud_entry(gpr_state)
	} else {
		exception_handler(num, gpr_state)
	}
}

fn exception_handler(num u32, gpr_state &cpulocal.GPRState) {
	C.printf(c'\nException occurred (%s) on CPU %d\n',
			 exception_names[num], cpulocal.current().cpu_number)
	C.printf(c'Error code: 0x%016llx\n', gpr_state.err)
	C.printf(c'Register dump:\n')
	C.printf(c'RIP: 0x%016llx\n', gpr_state.rip)
	C.printf(c'CS:  0x%016llx\n', gpr_state.cs)
	C.printf(c'RSP: 0x%016llx\n', gpr_state.rsp)
	C.printf(c'SS:  0x%016llx\n', gpr_state.ss)
	C.printf(c'RAX: 0x%016llx  RBX: 0x%016llx  RCX: 0x%016llx  RDX: 0x%016llx\n',
			 gpr_state.rax, gpr_state.rbx, gpr_state.rcx, gpr_state.rdx)
	C.printf(c'RSI: 0x%016llx  RDI: 0x%016llx  RBP: 0x%016llx\n',
			 gpr_state.rsi, gpr_state.rdi, gpr_state.rbp)
	C.printf(c'R8:  0x%016llx  R9:  0x%016llx  R10: 0x%016llx  R11: 0x%016llx\n',
			 gpr_state.r8, gpr_state.r9, gpr_state.r10, gpr_state.r11)
	C.printf(c'R12: 0x%016llx  R13: 0x%016llx  R14: 0x%016llx  R15: 0x%016llx\n',
			 gpr_state.r12, gpr_state.r13, gpr_state.r14, gpr_state.r15)
	for {
		asm volatile amd64 {
			cli
			hlt
		}
	}
}

pub fn initialise() {
	for i := u16(0); i < 32; i++ {
		idt.register_handler(i, interrupt_thunks[i])
		match i {
			6 {
				idt.set_ist(i, 3)
				interrupt_table[i] = voidptr(ud_handler)
			}
			else {
				idt.set_ist(i, 2)
				interrupt_table[i] = voidptr(exception_handler)
			}
		}
	}

	for i := u16(32); i < 256; i++ {
		idt.register_handler(i, interrupt_thunks[i])
		interrupt_table[i] = voidptr(generic_isr)
	}
}
