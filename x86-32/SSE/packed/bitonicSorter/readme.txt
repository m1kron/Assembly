Implementation of bitonic sort using SSE instructions. Time complexity is O( n*log^2(n) ).

This implementation is multiple times faster then std::sort for small-enough input.
For big input std::sort will be faster since it has better time complexity( O( n*log(n) ) ).

Tests done on Intel i5 shows that bitonic sort becomes slower than std::sort for inputs bigger then 2^25.