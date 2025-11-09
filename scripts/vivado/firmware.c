#define TMR_START_ADDR 0x40000010
#define STATUS_IN_LOOP 1

const char *signal_names[] = {
    "trap",
    "mem_valid & mem_instr & mem_wstrb",
    "mem_addr",
    "mem_wdata",
    "mem_la_read & mem_la_write & mem_la_wstrb",
    "mem_la_addr",
    "mem_la_wdata",
    "pcpi_valid",
    "pcpi_insn",
    "pcpi_rs1",
    "pcpi_rs2",
    "eoi",
    "trace_valid",
    "trace_data"
};

void putc(char c)
{
	*(volatile char*)0x10000000 = c;
}

void puts(const char *s)
{
	while (*s) putc(*s++);
}

void *memcpy(void *dest, const void *src, int n)
{
	while (n) {
		n--;
		((char*)dest)[n] = ((char*)src)[n];
	}
	return dest;
}

void main()
{
	char message[] = "$Uryyb+Jbeyq!+Vs+lbh+pna+ernq+guvf+zrffntr+gura$gur+CvpbEI32+jvgu+GZE+PCH"
			"+frrzf+gb+or+jbexvat+whfg+svar.$$++++++++++++++++GRFG+CNFFRQ!$$";
	for (int i = 0; message[i]; i++)
		switch (message[i])
		{
		case 'a' ... 'm':
		case 'A' ... 'M':
			message[i] += 13;
			break;
		case 'n' ... 'z':
		case 'N' ... 'Z':
			message[i] -= 13;
			break;
		case '$':
			message[i] = '\n';
			break;
		case '+':
			message[i] = ' ';
			break;
		}
	puts(message);

	puts((char *)(TMR_START_ADDR + 4*14));
	puts("\n");
	puts("\n");

	puts("PicoRV32 Buses Status:");
	puts("\n");

for (unsigned int i = 0; i <= 13; i++) {
	    puts(signal_names[i]);
		puts(": ");
		putc('0' + (0x07 & *(char *)(TMR_START_ADDR + 4*i)));
		puts("\n");
	}

#if STATUS_IN_LOOP == 1
while (1) {
    puts("*************** PicoRV32 Buses Status ***************\n\r");

    putc('I');
	putc('I');
    for (unsigned int i = 1; i <= 13; i++) {
        //puts(signal_names[i]);
        //puts(": ");

        unsigned char value = *(volatile unsigned char *)(TMR_START_ADDR + 4*i);
        value &= 0x07; // keep only lower 3 bits

        putc('0' + value);
        //putc('\n\r');
    }
	putc('F');
    puts("\n\r");
    // delay to avoid UART flooding
    for (volatile unsigned long d = 0; d < 1000000; d++);
}
#endif
}
