int bar(int i, int j)
{
	return i + j;
}

int foo(int m)
{
	int i;
	int sum;
	for (i=0, sum=0; i<=m; i++)
		sum = bar(sum, i);
	return sum;
}

int main(int argc, char* argv[])
{
	foo(100);
	return 0;
}
