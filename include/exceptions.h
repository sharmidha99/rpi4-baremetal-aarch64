#ifndef EXCEPTIONS_H
#define EXCEPTIONS_H

#include <stdint.h>

/*
 * Called from the assembly vector stubs in vectors.S.
 * type: index into the 16-entry vector table (0-15) identifying which
 *       vector fired (see vectors.S for the ordering).
 * esr:  ESR_EL1  - Exception Syndrome Register (why the exception happened)
 * elr:  ELR_EL1  - Exception Link Register (where to resume on ERET)
 * far:  FAR_EL1  - Fault Address Register (faulting address, if applicable)
 */
void exception_handler(uint64_t type, uint64_t esr, uint64_t elr, uint64_t far);

#endif
