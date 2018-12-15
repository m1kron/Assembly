#pragma once
#include <stdint.h>

// Reference implementation of bitonic sort.
bool BitonicSort_CPP( int32_t* array, uint32_t size );

// Implementation of bitonic sort using SSE assembly.
// array ptr has to be aligned to 16 byte boundary.
// size has to be bigger or equal to 8.
// Also size has to be a power of 2, other input sizes are not supported at this
// point( although they could be supported by additional O(n) operations )
//
// Returns true if sort was succesfull, false otherwise.
bool BitonicSort_SSE( int32_t* array, uint32_t size );