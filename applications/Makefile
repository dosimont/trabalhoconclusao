CEXES = app1 app2 app3 app4

all: cexam

cexam: $(CEXES)

.c:
	mpicc $(CFLAG) $< -o $@

clean:
	rm -f $(CEXES)
