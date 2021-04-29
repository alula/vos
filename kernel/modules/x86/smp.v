module x86

import stivale2
import memory

__global (
	cpus_online = u64(0)
)

pub fn smp_init(smp_tag &stivale2.SMPTag) {
	println('smp: BSP LAPIC ID:    ${smp_tag.bsp_lapic_id:x}')
	println('smp: Total CPU count: ${smp_tag.cpu_count}')

	cpu_locals = []&CPULocal{}

	smp_info_array := unsafe { &stivale2.SMPInfo(&smp_tag.smp_info) }

	for i := u64(0); i < smp_tag.cpu_count; i++ {
		mut cpu_local := &CPULocal(memory.malloc(sizeof(CPULocal)))
		cpu_locals << cpu_local

		mut smp_info := unsafe { &smp_info_array[i] }

		smp_info.extra_arg = u64(cpu_local)

		stack := u64(memory.pmm_alloc(1)) + higher_half

		cpu_local.tss.rsp0 = stack
		cpu_local.cpu_number = i

		if smp_info.lapic_id == smp_tag.bsp_lapic_id {
			cpu_init(smp_info)
			continue
		}

		atomic_store(smp_info.target_stack, stack)
		atomic_store(smp_info.goto_address, u64(&cpu_init))
	}

	for atomic_load(cpus_online) != smp_tag.cpu_count {}

	print('smp: All CPUs online!\n')
}
