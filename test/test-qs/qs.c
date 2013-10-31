#include <stdio.h>

void quick_sort (int *b, int n) {
	int a[] = {4, 65, 2, -31, 0, 99, 2, 83, 782, 1};
	if (n < 2)
		return;
	int p = a[n / 2];
	int *l = a;
	int *r = a + n - 1;
	while (l <= r) {
		if (*l < p) {
			l++;
			continue;
		}
		if (*r > p) {
			r--;
			continue; // we need to check the condition (l <= r) every time we change the value of l or r
		}
		int t = *l;
		*l++ = *r;
		*r-- = t;
	}
	quick_sort(a, r - a + 1);
	quick_sort(l, a + n - l);
}
 
int main () {
	int a[] = {4, 65, 2, -31, 0, 99, 2, 83, 782, 1};
	int n = sizeof a / sizeof a[0];
	int i;
	for (i=0; i<1000; i++)
		quick_sort(a, n);

	for (i=0; i<n; i++) {
		printf("%d ", a[i]);
	}
	printf("\n");
	return 0;
}
