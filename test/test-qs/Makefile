CC=mips-linux-gnu-gcc
CFLAGS=--static

# %.o: %.c 
# 	$(CC) -c -o $@ $<

bin.mips: qs.c
	$(CC) -o $@ $< $(CFLAGS)


.PHONY: bin.mips

clean:
	rm bin.mips

