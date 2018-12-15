#pragma once
#include <stdint.h>

typedef float (*T1DFunctionPtr)( float );

// Some tests functions:
inline float SquaredFunction( float a ) { return a * a; };
inline float ConstFunction( float ) { return 10; }

// Reference implementation:
float NumericalIntegration_CPP( const T1DFunctionPtr ptr, float a, float b, uint32_t steps );

// Asm implementation:
extern "C" float NumericalIntegration_ASM_( const T1DFunctionPtr ptr, float a, float b, uint32_t steps );
